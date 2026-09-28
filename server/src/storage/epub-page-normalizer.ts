const generatedPageSize = 1800;

export type EpubReadingResource = {
  href: string;
  sourcePath: string;
  type: string;
  content: string;
};

export type DeclaredEpubPage = {
  href: string;
  label?: string;
};

export type EpubPageLocator = {
  href: string;
  type: string;
  title: string;
  locations: {
    fragments?: string[];
    progression: number;
    totalProgression: number;
    position: number;
  };
};

export type NormalizedEpubPages = {
  pageList: EpubPageLocator[];
  updates: Map<string, string>;
  source: 'declared' | 'embedded' | 'generated';
};

type PageCandidate = {
  href: string;
  type: string;
  label?: string;
  fragment?: string;
  progression: number;
};

export function normalizeEpubPages(
  resources: EpubReadingResource[],
  declaredPages: DeclaredEpubPage[],
): NormalizedEpubPages {
  const declared = normalizeDeclaredPages(resources, declaredPages);
  if (declared.length) {
    return { pageList: finalizePages(declared), updates: new Map(), source: 'declared' };
  }

  const embedded = resources.flatMap((resource) => embeddedPageMarkers(resource));
  if (embedded.length) {
    return { pageList: finalizePages(embedded), updates: new Map(), source: 'embedded' };
  }

  const generated = generatePageMarkers(resources);
  return {
    pageList: finalizePages(generated.pages),
    updates: generated.updates,
    source: 'generated',
  };
}

function normalizeDeclaredPages(
  resources: EpubReadingResource[],
  pages: DeclaredEpubPage[],
): PageCandidate[] {
  const candidates: PageCandidate[] = [];
  for (const page of pages) {
    const [path, fragment] = splitHref(page.href);
    const resource = resources.find((item) => sameResource(item.href, path));
    if (!resource) continue;
    const progression = fragmentProgression(resource.content, fragment);
    candidates.push({
      href: fragment ? `${resource.href}#${fragment}` : resource.href,
      type: resource.type,
      label: page.label,
      fragment,
      progression,
    });
  }
  return candidates;
}

function embeddedPageMarkers(resource: EpubReadingResource): PageCandidate[] {
  if (!isHtml(resource.type)) return [];
  const result: PageCandidate[] = [];
  const pattern = /<[^>]+(?:epub:type\s*=\s*["'][^"']*\bpagebreak\b[^"']*["']|role\s*=\s*["'][^"']*\bdoc-pagebreak\b[^"']*["']|type\s*=\s*["']pagebreak["'])[^>]*>/giu;
  for (const match of resource.content.matchAll(pattern)) {
    const tag = match[0];
    const fragment = attribute(tag, 'id');
    if (!fragment) continue;
    result.push({
      href: `${resource.href}#${fragment}`,
      type: resource.type,
      fragment,
      label: attribute(tag, 'aria-label') || attribute(tag, 'title'),
      progression: visibleProgression(resource.content, match.index ?? 0),
    });
  }
  return result;
}

function generatePageMarkers(resources: EpubReadingResource[]) {
  const updates = new Map<string, string>();
  const pages: PageCandidate[] = [];
  let accumulatedCharacters = 0;
  let nextBoundary = 0;
  let pageNumber = 1;

  for (const resource of resources) {
    if (!isHtml(resource.type)) continue;
    const body = /<body\b[^>]*>/iu.exec(resource.content);
    if (!body || body.index == null) continue;
    const bodyStart = body.index + body[0].length;
    const bodyEnd = resource.content.search(/<\/body\s*>/iu);
    const end = bodyEnd >= bodyStart ? bodyEnd : resource.content.length;
    const bodyContent = resource.content.slice(bodyStart, end);
    const resourceCharacters = visibleTextLength(bodyContent);
    if (resourceCharacters === 0) continue;

    const insertions: Array<{ offset: number; marker: string }> = [];
    const blocks = [...bodyContent.matchAll(/<(?:p|div|h[1-6]|li|blockquote|section|article)\b[^>]*>/giu)];
    const offsets = [0, ...blocks.map((match) => match.index ?? 0)];
    let lastOffset = -1;

    for (const localOffset of offsets) {
      if (localOffset === lastOffset) continue;
      lastOffset = localOffset;
      const charactersBefore = visibleTextLength(bodyContent.slice(0, localOffset));
      const absolutePosition = accumulatedCharacters + charactersBefore;
      if (pages.length && absolutePosition < nextBoundary) continue;

      const fragment = `kitapp-page-${pageNumber}`;
      const marker = `<span id="${fragment}" epub:type="pagebreak" role="doc-pagebreak" aria-label="${pageNumber}" class="kitapp-pagebreak"></span>`;
      insertions.push({ offset: bodyStart + localOffset, marker });
      pages.push({
        href: `${resource.href}#${fragment}`,
        type: resource.type,
        fragment,
        label: String(pageNumber),
        progression: resourceCharacters === 0 ? 0 : charactersBefore / resourceCharacters,
      });
      pageNumber++;
      if (nextBoundary === 0) nextBoundary = generatedPageSize;
      while (nextBoundary <= absolutePosition) nextBoundary += generatedPageSize;
    }

    if (insertions.length) {
      let normalized = ensureEpubNamespace(resource.content);
      const namespaceGrowth = normalized.length - resource.content.length;
      for (const insertion of insertions.toReversed()) {
        const offset = insertion.offset + namespaceGrowth;
        normalized = `${normalized.slice(0, offset)}${insertion.marker}${normalized.slice(offset)}`;
      }
      updates.set(resource.sourcePath, normalized);
    }
    accumulatedCharacters += resourceCharacters;
  }

  return { pages, updates };
}

function finalizePages(pages: PageCandidate[]): EpubPageLocator[] {
  const total = pages.length;
  return pages.map((page, index) => ({
    href: page.href,
    type: page.type,
    title: page.label ? `${page.label}-бет` : `${index + 1}-бет`,
    locations: {
      ...(page.fragment ? { fragments: [page.fragment] } : {}),
      progression: clamp(page.progression),
      totalProgression: total <= 1 ? 0 : index / (total - 1),
      position: index + 1,
    },
  }));
}

function ensureEpubNamespace(content: string) {
  if (/xmlns:epub\s*=/iu.test(content)) return content;
  return content.replace(
    /<html\b/iu,
    '<html xmlns:epub="http://www.idpf.org/2007/ops"',
  );
}

function visibleProgression(content: string, offset: number) {
  const body = /<body\b[^>]*>/iu.exec(content);
  const bodyStart = body?.index == null ? 0 : body.index + body[0].length;
  const bodyEnd = content.search(/<\/body\s*>/iu);
  const end = bodyEnd >= bodyStart ? bodyEnd : content.length;
  const total = visibleTextLength(content.slice(bodyStart, end));
  if (!total) return 0;
  return visibleTextLength(content.slice(bodyStart, Math.max(bodyStart, offset))) / total;
}

function fragmentProgression(content: string, fragment?: string) {
  if (!fragment) return 0;
  const escaped = escapeRegExp(fragment);
  const match = new RegExp(`\\bid\\s*=\\s*["']${escaped}["']`, 'iu').exec(content);
  return visibleProgression(content, match?.index ?? 0);
}

function visibleTextLength(value: string) {
  return decodeEntities(
    value
      .replace(/<script\b[\s\S]*?<\/script\s*>/giu, '')
      .replace(/<style\b[\s\S]*?<\/style\s*>/giu, '')
      .replace(/<[^>]+>/gu, ' ')
      .replace(/\s+/gu, ' '),
  ).trim().length;
}

function decodeEntities(value: string) {
  return value
    .replace(/&#(\d+);/gu, (_, code: string) => String.fromCodePoint(Number(code)))
    .replace(/&#x([\da-f]+);/giu, (_, code: string) => String.fromCodePoint(Number.parseInt(code, 16)))
    .replace(/&(nbsp|amp|lt|gt|quot|apos);/giu, (_, name: string) => ({
      nbsp: ' ', amp: '&', lt: '<', gt: '>', quot: '"', apos: "'",
    })[name.toLowerCase()] ?? ' ');
}

function attribute(tag: string, name: string) {
  const escaped = escapeRegExp(name);
  return new RegExp(`\\b${escaped}\\s*=\\s*["']([^"']*)["']`, 'iu').exec(tag)?.[1]?.trim();
}

function splitHref(href: string) {
  const hash = href.indexOf('#');
  return hash < 0 ? [href, undefined] as const : [href.slice(0, hash), href.slice(hash + 1)] as const;
}

function sameResource(left: string, right: string) {
  const normalize = (value: string) => value.replace(/^\.\//u, '').replace(/^\//u, '');
  return normalize(left) === normalize(right) || normalize(left).endsWith(`/${normalize(right)}`);
}

function isHtml(type: string) {
  return type.includes('html') || type.includes('xhtml');
}

function clamp(value: number) {
  return Math.max(0, Math.min(1, Number.isFinite(value) ? value : 0));
}

function escapeRegExp(value: string) {
  return value.replace(/[.*+?^${}()|[\]\\]/gu, '\\$&');
}
