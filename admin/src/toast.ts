// One short message at the bottom of the screen: a saved change or an error.
let timer: number | undefined;

export function toast(message: string, tone: 'ok' | 'error' = 'ok') {
  let element = document.getElementById('toast');
  if (!element) {
    element = document.createElement('div');
    element.id = 'toast';
    element.setAttribute('role', 'status');
    document.body.appendChild(element);
  }
  element.textContent = message;
  element.className = `toast visible ${tone}`;
  window.clearTimeout(timer);
  timer = window.setTimeout(() => element?.classList.remove('visible'), tone === 'error' ? 6000 : 3000);
}
