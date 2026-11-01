const API_URL = import.meta.env.VITE_API_URL ?? 'http://localhost:3000/api';

export const auth = {
  token: () => localStorage.getItem('kitapp_admin_token'),
  save: (token: string) => localStorage.setItem('kitapp_admin_token', token),
  clear: () => localStorage.removeItem('kitapp_admin_token'),
};

export async function api<T>(path: string, init?: RequestInit): Promise<T> {
  const headers = new Headers(init?.headers);
  const token = auth.token();
  if (token) headers.set('Authorization', `Bearer ${token}`);
  if (init?.body && !(init.body instanceof FormData)) {
    headers.set('Content-Type', 'application/json');
  }

  const response = await fetch(`${API_URL}${path}`, { ...init, headers });
  if (response.status === 401 && path !== '/auth/admin/login') {
    auth.clear();
    window.location.reload();
  }
  if (!response.ok) {
    const data = (await response.json().catch(() => null)) as { message?: string | string[] } | null;
    const message = Array.isArray(data?.message) ? data.message.join(', ') : data?.message;
    throw new Error(message ?? 'Сурам аткарылган жок');
  }
  return response.json() as Promise<T>;
}
