// Progressive enhancement only. With JS off every row stays visible, which is the correct failure.
(() => {
  const chips = document.querySelectorAll('[data-filter]');
  const rows = document.querySelectorAll('#writing-list [data-kind]');
  if (!chips.length || !rows.length) return;

  chips.forEach(chip => chip.addEventListener('click', () => {
    const want = chip.dataset.filter;
    chips.forEach(c => c.setAttribute('aria-pressed', String(c === chip)));
    rows.forEach(r => {
      r.hidden = want !== 'all' && r.dataset.kind !== want;
    });
  }));
})();
