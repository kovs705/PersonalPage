// Clackable, ported to the web. Synthesized — no audio file ships.
// Default OFF. Only fires on real interaction, so autoplay policy is never an issue.
(() => {
  const KEY = 'clack';
  const toggle = document.querySelector('[data-clack]');
  let on = localStorage.getItem(KEY) === '1';
  let ctx = null;

  const setState = () => {
    if (toggle) toggle.setAttribute('aria-pressed', String(on));
    document.documentElement.classList.toggle('clack-on', on);
  };

  // Short filtered noise burst with a fast decay — reads as a clack, not a beep.
  const click = (down) => {
    if (!on) return;
    try {
      ctx = ctx || new (window.AudioContext || window.webkitAudioContext)();
      const dur = down ? 0.014 : 0.010;
      const frames = Math.floor(ctx.sampleRate * dur);
      const buf = ctx.createBuffer(1, frames, ctx.sampleRate);
      const data = buf.getChannelData(0);
      for (let i = 0; i < frames; i++) {
        // Linear decay envelope over white noise.
        data[i] = (Math.random() * 2 - 1) * (1 - i / frames);
      }
      const src = ctx.createBufferSource();
      src.buffer = buf;
      const bp = ctx.createBiquadFilter();
      bp.type = 'bandpass';
      bp.frequency.value = down ? 2100 : 2800;
      bp.Q.value = 0.9;
      const gain = ctx.createGain();
      gain.gain.value = down ? 0.32 : 0.20;
      src.connect(bp).connect(gain).connect(ctx.destination);
      src.start();
    } catch (_) { /* audio unavailable — silently do nothing */ }
  };

  setState();

  if (toggle) {
    toggle.addEventListener('click', (e) => {
      e.preventDefault();
      on = !on;
      localStorage.setItem(KEY, on ? '1' : '0');
      setState();
      if (on) click(true);   // confirm by demonstrating
    });
  }

  const selector = '.btn, .copy, .copy-inline, a.row, .site-nav a, .chip';
  document.addEventListener('pointerdown', (e) => {
    if (e.target.closest(selector) && !e.target.closest('[data-clack]')) click(true);
  });
  document.addEventListener('pointerup', (e) => {
    if (e.target.closest(selector) && !e.target.closest('[data-clack]')) click(false);
  });
})();
