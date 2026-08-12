import { BadRequestException, Injectable } from '@nestjs/common';
import AdmZip from 'adm-zip';
import { XMLParser } from 'fast-xml-parser';
import { randomUUID } from 'node:crypto';
import { mkdir, readFile, rename, rm, writeFile } from 'node:fs/promises';
import { dirname, extname, join, posix, resolve } from 'node:path';

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
      const readingOrder = spineItems
        .map((item) => items.get(item.idref))
        .filter(Boolean)
        .map((item) => ({
          href: `content/${posix.normalize(posix.join(opfDir, item.href))}`,
          type: item['media-type'] ?? 'application/xhtml+xml',
        }));
      if (!readingOrder.length) throw new Error('empty spine');

      const toc = this.readToc(packageXml, manifestItems, byName, opfDir)
        .map((item) => ({ ...item, href: `content/${posix.normalize(posix.join(opfDir, item.href))}` }));
      const metadata = packageXml?.metadata ?? {};
      const title = this.text(metadata.title) || file.originalname.replace(/\.epub$/i, '');
      const language = this.text(metadata.language) || 'und';
      const author = this.asArray(metadata.creator).map((value) => ({ name: this.text(value) })).filter((x) => x.name);

      await mkdir(temp, { recursive: true });
      zip.extractAllTo(join(temp, 'content'), true);
      const manifest = {
        '@context': 'https://readium.org/webpub-manifest/context.jsonld',
        metadata: { '@type': 'http://schema.org/Book', title, language, author },
        links: [{ rel: 'self', href: 'manifest.json', type: 'application/webpub+json' }],
        readingOrder,
        resources: readingOrder,
        toc: toc.length ? toc : readingOrder.map((item, index) => ({ title: `${index + 1}-бөлүм`, href: item.href })),
      };
      await writeFile(join(temp, 'manifest.json'), JSON.stringify(manifest));
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

  async signedUrl(key: string) {
    if (key.endsWith('.epub')) return this.url(`${key.slice(0, -5)}/manifest.json`);
    return this.url(key);
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
