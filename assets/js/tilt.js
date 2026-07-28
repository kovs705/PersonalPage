// Cursor-reactive tilt, capped at 3deg. Pointer-precise devices only, motion-preference aware.
(() => {
  if (!window.matchMedia('(hover: hover) and (pointer: fine)').matches) return;
  if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;

  const MAX = 3;
  document.querySelectorAll('[data-tilt]').forEach(el => {
    el.style.transition = 'transform 180ms cubic-bezier(.2,.8,.3,1)';
    el.addEventListener('pointermove', (e) => {
      const r = el.getBoundingClientRect();
      const dx = (e.clientX - r.left) / r.width - 0.5;
      const dy = (e.clientY - r.top) / r.height - 0.5;
      el.style.transform =
        `perspective(600px) rotateY(${(dx * MAX * 2).toFixed(2)}deg) rotateX(${(-dy * MAX * 2).toFixed(2)}deg)`;
    });
    el.addEventListener('pointerleave', () => { el.style.transform = ''; });
  });
})();
