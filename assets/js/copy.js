(() => {
  document.querySelectorAll('[data-copy]').forEach(btn => {
    btn.addEventListener('click', async () => {
      const text = btn.dataset.copy;
      const label = btn.querySelector('[data-copy-label]');
      const restore = label ? label.textContent : '';
      try {
        if (navigator.clipboard && window.isSecureContext) {
          await navigator.clipboard.writeText(text);
        } else {
          const ta = document.createElement('textarea');
          ta.value = text;
          ta.style.position = 'fixed';
          ta.style.opacity = '0';
          document.body.appendChild(ta);
          ta.select();
          document.execCommand('copy');
          document.body.removeChild(ta);
        }
        if (label) label.textContent = 'copied ✓';
      } catch (_) {
        if (label) label.textContent = 'select & copy';
      }
      if (label) setTimeout(() => { label.textContent = restore; }, 1400);
    });
  });
})();
