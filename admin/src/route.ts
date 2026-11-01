export type Page = 'home' | 'books' | 'directories' | 'readers' | 'orders' | 'reports' | 'audit';

/** Pages live in the URL hash (#/books/<id>), so a reload keeps the page. */
export function go(page: Page, id?: string) {
  window.location.hash = id ? `/${page}/${id}` : `/${page}`;
}
