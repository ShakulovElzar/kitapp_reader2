import { BadRequestException, Injectable } from '@nestjs/common';
import AdmZip from 'adm-zip';
import { XMLParser } from 'fast-xml-parser';
import { createHmac, randomUUID, timingSafeEqual } from 'node:crypto';
import { mkdir, readFile, rename, rm, writeFile } from 'node:fs/promises';
import { dirname, extname, join, normalize, posix, resolve, sep } from 'node:path';
import {
  DeclaredEpubPage,
  EpubReadingResource,
  normalizeEpubPages,
} from './epub-page-normalizer.js';

// Long enough for a reading session; the app asks for a fresh link each time a book opens.
const BOOK_LINK_TTL_SECONDS = 6 * 60 * 60;

function fileSigningSecret() {
  return process.env.FILES_SECRET ?? process.env.JWT_SECRET ?? 'local-kitapp-secret';
}

// Tells the web reader to use its paginated EPUB navigator instead of the scroll-only WebPub one.
const EPUB_PROFILE = 'https://readium.org/webpub-manifest/profiles/epub';

// The paginated navigator matches positions to reading-order links, so hrefs must not carry #fragments.
// The web reader ignores a positions document without a top-level `total`.
function positionsDocument(pageList: Array<{ href: string; locations?: Record<string, unknown> }>) {
  return {
    total: pageList.length,
    metadata: { numberOfItems: pageList.length },
    links: [{ rel: 'self', href: 'positions.json', type: 'application/vnd.readium.position-list+json' }],
    positions: pageList.map((page) => ({ ...page, href: String(page.href).split('#')[0] })),
  };
}

type StoredBook = {
  key: string;
  manifestKey: string;
};

@Injectable()
export class StorageService {
  private readonly root = resolve(process.env.STORAGE_PATH ?? join(process.cwd(), 'storage'));
  private readonly publicBase = (process.env.PUBLIC_URL ?? 'http://127.0.0.1:3000').replace(/\/$/, '');
  private readonly xml = new XMLParser({ ignoreAttributes: false, attributeNamePrefix: '', removeNSPrefix: true });

  async upload(folder: 'covers' | 'epubs', file: Express.Multer.File): Promise<string> {
    return folder === 'covers' ? this.storeCover(file) : (await this.storeEpub(file)).key;
  }

  async storeCover(file: Express.Multer.File) {
    const extension = extname(file.originalname).toLowerCase();
    if (!['.jpg', '.jpeg', '.png', '.webp'].includes(extension) || !file.mimetype.startsWith('image/')) {
      throw new BadRequestException('Мукаба JPG, PNG же WebP форматында болушу керек');
    }
    if (file.size > 10 * 1024 * 1024) throw new BadRequestException('Мукаба 10 МБдан чоң болбошу керек');
    const key = `covers/${randomUUID()}${extension}`;
    await mkdir(dirname(join(this.root, key)), { recursive: true });
    await writeFile(join(this.root, key), file.buffer);
    return key;
  }

  async storeEpub(file: Express.Multer.File): Promise<StoredBook> {
    if (extname(file.originalname).toLowerCase() !== '.epub') {
      throw new BadRequestException('EPUB файлын тандаңыз');
    }
    if (file.size > 50 * 1024 * 1024) throw new BadRequestException('EPUB 50 МБдан чоң болбошу керек');

    const id = randomUUID();
    const temp = join(this.root, '.tmp', id);
    const target = join(this.root, 'books', id);
    try {
      const zip = new AdmZip(file.buffer);
      const entries = zip.getEntries();
      const byName = new Map(entries.map((entry) => [entry.entryName, entry]));
      const mimetype = byName.get('mimetype')?.getData().toString('utf8').trim();
      const container = byName.get('META-INF/container.xml');
      if (mimetype !== 'application/epub+zip' || !container) throw new Error('invalid container');
      for (const entry of entries) {
        if (entry.entryName.startsWith('/') || entry.entryName.split('/').includes('..')) throw new Error('unsafe path');
      }

      const containerXml = this.xml.parse(container.getData().toString('utf8'));
      const rootfiles = this.asArray(containerXml?.container?.rootfiles?.rootfile);
      const selectedRootfile = rootfiles.find((item) => {
        const path = item?.['full-path'];
        return typeof path === 'string' && byName.has(path);
      });
      const opfPath = selectedRootfile?.['full-path'];
      const opfEntry = typeof opfPath === 'string' ? byName.get(opfPath) : undefined;
      if (!opfEntry) throw new Error('missing package');
      const packageXml = this.xml.parse(opfEntry.getData().toString('utf8'))?.package;
      const manifestItems = this.asArray(packageXml?.manifest?.item);
      const spineItems = this.asArray(packageXml?.spine?.itemref);
      const items = new Map(manifestItems.map((item) => [item.id, item]));
      const opfDir = posix.dirname(opfPath);
      const readingResources: EpubReadingResource[] = spineItems
        .map((item) => items.get(item.idref))
        .filter(Boolean)
        .map((item) => {
          const sourcePath = posix.normalize(posix.join(opfDir, item.href));
          const entry = byName.get(sourcePath);
          if (!entry) throw new Error('missing spine resource');
          return {
            href: `content/${sourcePath}`,
            sourcePath,
            type: item['media-type'] ?? 'application/xhtml+xml',
            content: entry.getData().toString('utf8'),
          };
        });
      if (!readingResources.length) throw new Error('empty spine');

      const readingOrder = readingResources.map(({ href, type }) => ({ href, type }));

      const toc = this.readToc(packageXml, manifestItems, byName, opfDir)
        .map((item) => ({ ...item, href: this.publicationHref(opfDir, item.href) }));
      const declaredPages = this.readPageList(packageXml, manifestItems, byName, opfDir)
        .map((item) => ({ ...item, href: this.publicationHref(opfDir, item.href) }));
      const normalizedPages = normalizeEpubPages(readingResources, declaredPages);
      const metadata = packageXml?.metadata ?? {};
      const title = this.text(metadata.title) || file.originalname.replace(/\.epub$/i, '');
      const language = this.text(metadata.language) || 'und';
      const author = this.asArray(metadata.creator).map((value) => ({ name: this.text(value) })).filter((x) => x.name);

      await mkdir(temp, { recursive: true });
      zip.extractAllTo(join(temp, 'content'), true);
      for (const [sourcePath, content] of normalizedPages.updates) {
        await writeFile(join(temp, 'content', sourcePath), content);
      }
      const positions = positionsDocument(normalizedPages.pageList);
      const manifest = {
        '@context': 'https://readium.org/webpub-manifest/context.jsonld',
        metadata: {
          '@type': 'http://schema.org/Book',
          conformsTo: EPUB_PROFILE,
          identifier: `urn:kitapp:${id}`,
          title,
          language,
          author,
          numberOfPages: normalizedPages.pageList.length,
          pageListSource: normalizedPages.source,
        },
        links: [
          { rel: 'self', href: 'manifest.json', type: 'application/webpub+json' },
          { rel: 'positions', href: 'positions.json', type: 'application/vnd.readium.position-list+json' },
        ],
        readingOrder,
        resources: readingOrder,
        toc: toc.length ? toc : readingOrder.map((item, index) => ({ title: `${index + 1}-бөлүм`, href: item.href })),
        pageList: normalizedPages.pageList,
      };
      await writeFile(join(temp, 'manifest.json'), JSON.stringify(manifest));
      await writeFile(join(temp, 'positions.json'), JSON.stringify(positions));
      await mkdir(dirname(target), { recursive: true });
      await rename(temp, target);
      return { key: `books/${id}.epub`, manifestKey: `books/${id}/manifest.json` };
    } catch {
      await rm(temp, { recursive: true, force: true });
      throw new BadRequestException('EPUB файлы жараксыз же анын мазмуну окулбайт');
    }
  }

  async remove(key?: string | null) {
    if (!key) return;
    const path = join(this.root, key);
    await rm(path, { recursive: true, force: true });
    if (key.endsWith('.epub')) await rm(join(this.root, key.slice(0, -5)), { recursive: true, force: true });
  }

  /**
   * Covers get a plain public URL. Books get a link that expires: the signature sits in
   * the path (not the query) so the reader's relative chapter URLs carry it too.
   */
  async signedUrl(key: string) {
    if (key.endsWith('.epub')) {
      const directoryKey = key.slice(0, -5);
      await this.normalizeStoredPublication(directoryKey);
      const bookId = directoryKey.split('/').pop()!;
      const expires = Math.floor(Date.now() / 1000) + BOOK_LINK_TTL_SECONDS;
      const token = `${expires}.${this.sign(bookId, expires)}`;
      return `${this.publicBase}/files/s/${token}/books/${encodeURIComponent(bookId)}/manifest.json`;
    }
    return this.url(key);
  }

  /** Returns the file a signed book link points to, or null if the link is invalid or expired. */
  resolveSignedPath(token: string, bookId: string, relativePath: string) {
    const [expiresText, signature] = token.split('.', 2);
    const expires = Number(expiresText);
    if (!signature || !Number.isInteger(expires) || expires < Date.now() / 1000) return null;
    if (!/^[0-9a-f-]{36}$/.test(bookId)) return null;
    const expected = Buffer.from(this.sign(bookId, expires));
    const given = Buffer.from(signature);
    if (expected.length !== given.length || !timingSafeEqual(expected, given)) return null;
    const directory = join(this.root, 'books', bookId);
    const target = normalize(join(directory, decodeURIComponent(relativePath)));
    return target.startsWith(directory + sep) ? target : null;
  }

  get coversPath() {
    return join(this.root, 'covers');
  }

  private sign(bookId: string, expires: number) {
    return createHmac('sha256', fileSigningSecret()).update(`${bookId}:${expires}`).digest('base64url');
  }

  pathFor(key: string) {
    return join(this.root, key);
  }

  async exists(key?: string | null) {
    if (!key) return false;
    try { await readFile(this.pathFor(key)); return true; } catch { return false; }
  }

  private url(key: string) {
    return `${this.publicBase}/files/${key.split('/').map(encodeURIComponent).join('/')}`;
  }

  private async normalizeStoredPublication(directoryKey: string) {
    const directory = join(this.root, directoryKey);
    const manifestPath = join(directory, 'manifest.json');
    const manifest = JSON.parse(await readFile(manifestPath, 'utf8')) as Record<string, any>;
    if (Array.isArray(manifest.pageList) && manifest.pageList.length > 0) {
      const identifier = `urn:kitapp:${directoryKey.split('/').pop()}`;
      if (manifest.metadata?.conformsTo !== EPUB_PROFILE || manifest.metadata?.identifier !== identifier) {
        // The web reader caches publications by identifier, so each book needs its own.
        manifest.metadata = { ...(manifest.metadata ?? {}), conformsTo: EPUB_PROFILE, identifier };
        await writeFile(manifestPath, JSON.stringify(manifest));
      }
      const positionsPath = join(directory, 'positions.json');
      const stored = JSON.parse(await readFile(positionsPath, 'utf8').catch(() => '{}'));
      if (stored.total !== manifest.pageList.length
        || stored.positions?.some((item: any) => String(item?.href).includes('#'))) {
        await writeFile(positionsPath, JSON.stringify(positionsDocument(manifest.pageList)));
      }
      return;
    }

    const readingOrder = this.asArray(manifest.readingOrder);
    const resources: EpubReadingResource[] = [];
    for (const item of readingOrder) {
      const href = String(item?.href ?? '').split('#')[0];
      if (!href.startsWith('content/') || href.split('/').includes('..')) continue;
      resources.push({
        href,
        sourcePath: href.slice('content/'.length),
        type: item?.type ?? 'application/xhtml+xml',
        content: await readFile(join(directory, href), 'utf8'),
      });
    }
    if (!resources.length) return;
    const normalized = normalizeEpubPages(resources, []);
    for (const [sourcePath, content] of normalized.updates) {
      await writeFile(join(directory, 'content', sourcePath), content);
    }
    const positions = positionsDocument(normalized.pageList);
    manifest.metadata = {
      ...(manifest.metadata ?? {}),
      conformsTo: EPUB_PROFILE,
      identifier: `urn:kitapp:${directoryKey.split('/').pop()}`,
      numberOfPages: normalized.pageList.length,
      pageListSource: normalized.source,
    };
    manifest.links = this.asArray(manifest.links).filter((link) => {
      const rels = this.asArray(link?.rel);
      return !rels.includes('positions');
    });
    manifest.links.push({
      rel: 'positions',
      href: 'positions.json',
      type: 'application/vnd.readium.position-list+json',
    });
    manifest.pageList = normalized.pageList;
    await writeFile(join(directory, 'positions.json'), JSON.stringify(positions));
    await writeFile(manifestPath, JSON.stringify(manifest));
  }

  private readToc(packageXml: any, manifestItems: any[], entries: Map<string, AdmZip.IZipEntry>, opfDir: string) {
    const nav = manifestItems.find((item) => String(item.properties ?? '').split(/\s+/).includes('nav'));
    if (nav) {
      const entry = entries.get(posix.normalize(posix.join(opfDir, nav.href)));
      if (entry) {
        const tree = this.xml.parse(entry.getData().toString('utf8'));
        const anchors: Array<{ title: string; href: string }> = [];
        this.collectAnchors(tree, anchors);
        if (anchors.length) return anchors;
      }
    }
    const ncx = manifestItems.find((item) => item['media-type'] === 'application/x-dtbncx+xml');
    if (ncx) {
      const entry = entries.get(posix.normalize(posix.join(opfDir, ncx.href)));
      const points = entry ? this.asArray(this.xml.parse(entry.getData().toString('utf8'))?.ncx?.navMap?.navPoint) : [];
      return points.map((point) => ({ title: this.text(point?.navLabel?.text) || 'Бөлүм', href: point?.content?.src })).filter((x) => x.href);
    }
    return [];
  }

  private readPageList(
    packageXml: any,
    manifestItems: any[],
    entries: Map<string, AdmZip.IZipEntry>,
    opfDir: string,
  ): DeclaredEpubPage[] {
    const nav = manifestItems.find((item) => String(item.properties ?? '').split(/\s+/).includes('nav'));
    if (nav) {
      const entry = entries.get(posix.normalize(posix.join(opfDir, nav.href)));
      if (entry) {
        const result: DeclaredEpubPage[] = [];
        this.collectPageListAnchors(this.xml.parse(entry.getData().toString('utf8')), result, false);
        if (result.length) return result;
      }
    }

    const ncx = manifestItems.find((item) => item['media-type'] === 'application/x-dtbncx+xml');
    if (!ncx) return [];
    const entry = entries.get(posix.normalize(posix.join(opfDir, ncx.href)));
    const targets = entry
      ? this.asArray(this.xml.parse(entry.getData().toString('utf8'))?.ncx?.pageList?.pageTarget)
      : [];
    return targets
      .map((target) => ({
        href: target?.content?.src,
        label: this.text(target?.navLabel?.text) || this.text(target?.value),
      }))
      .filter((page) => typeof page.href === 'string' && page.href.length > 0);
  }

  private collectPageListAnchors(value: any, result: DeclaredEpubPage[], insidePageList: boolean) {
    if (!value || typeof value !== 'object') return;
    const isPageList = insidePageList || String(value.type ?? '').split(/\s+/).includes('page-list');
    if (isPageList && value.a) {
      for (const anchor of this.asArray(value.a)) {
        if (anchor?.href) result.push({ href: anchor.href, label: this.text(anchor) });
      }
    }
    for (const child of Object.values(value)) {
      this.collectPageListAnchors(child, result, isPageList);
    }
  }

  private publicationHref(opfDir: string, href: string) {
    const [path, fragment] = String(href).split('#', 2);
    const resolved = `content/${posix.normalize(posix.join(opfDir, path))}`;
    return fragment ? `${resolved}#${fragment}` : resolved;
  }

  private collectAnchors(value: any, result: Array<{ title: string; href: string }>) {
    if (!value || typeof value !== 'object') return;
    if (value.a) for (const anchor of this.asArray(value.a)) if (anchor?.href) result.push({ title: this.text(anchor) || 'Бөлүм', href: anchor.href });
    for (const child of Object.values(value)) this.collectAnchors(child, result);
  }

  private asArray(value: any): any[] { return value == null ? [] : Array.isArray(value) ? value : [value]; }
  private text(value: any): string {
    if (value == null) return '';
    if (typeof value === 'string' || typeof value === 'number') return String(value).trim();
    if (typeof value === 'object') return this.text(value['#text'] ?? value.text ?? '');
    return '';
  }
}
