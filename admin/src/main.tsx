import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { App } from './App';
import { toast } from './toast';
import './styles.css';

// A request a page fires without its own error handling still reaches the
// admin as a message instead of failing silently.
window.addEventListener('unhandledrejection', (event) => {
  const reason = event.reason;
  toast(reason instanceof Error ? reason.message : 'Сурам аткарылган жок', 'error');
});

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <App />
  </StrictMode>,
);
