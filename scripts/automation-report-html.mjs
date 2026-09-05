import fs from 'node:fs/promises';

const enhancementMarker = 'starfin-report-enhancements-v3';

function buildReportEnhancements() {
  return `<style id="${enhancementMarker}">
.starfin-expand-toggle {
  align-self: center;
  background: #fff;
  border: 1px solid #fff;
  border-radius: 4px;
  color: #000;
  cursor: pointer;
  flex: 0 0 auto;
  font: inherit;
  margin: 0 12px 0 0;
  padding: 6px 12px;
  position: relative;
  top: -3px;
}
.starfin-expand-toggle:hover,
.starfin-expand-toggle:focus-visible {
  background: #e0e0e0;
  border-color: #e0e0e0;
}
</style>
<script>
window.addEventListener('load', () => setTimeout(() => {
  const pattern = new RegExp('^screenshots/[a-z0-9-]+[.]png$');
  const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
  const matches = [];
  while (walker.nextNode()) {
    if (pattern.test(walker.currentNode.textContent.trim())) matches.push(walker.currentNode);
  }
  for (const textNode of matches) {
    const href = textNode.textContent.trim();
    const link = document.createElement('a');
    link.href = href;
    link.target = '_blank';
    link.rel = 'noopener';
    link.textContent = href;
    textNode.replaceWith(link);
  }

  const installVisibilityToggle = () => {
    if (document.querySelector('.starfin-expand-toggle')) return true;

    const quickSummaryList = document.querySelector('[class*="quick-summary--list"]');
    if (!quickSummaryList) return false;
    const quickSummary = quickSummaryList.closest('[class*="quick-summary--cnt"]')
      ?? quickSummaryList.parentElement;
    if (!quickSummary) return false;

    const button = document.createElement('button');
    button.type = 'button';
    button.className = 'starfin-expand-toggle';

    const reportDetails = () => Array.from(
      document.querySelectorAll('#report details[class*="test--details"]')
    );
    const updateButton = () => {
      const details = reportDetails();
      const allExpanded = details.length > 0 && details.every(detail => detail.open);
      button.textContent = allExpanded ? 'Collapse All' : 'Expand All';
      button.setAttribute('aria-expanded', String(allExpanded));
    };

    button.addEventListener('click', () => {
      const details = reportDetails();
      const shouldExpand = !details.length || !details.every(detail => detail.open);
      for (const detail of details) detail.open = shouldExpand;
      updateButton();
    });
    document.querySelector('#report')?.addEventListener('toggle', updateButton, true);

    updateButton();
    quickSummary.insertBefore(button, quickSummaryList);
    return true;
  };

  if (!installVisibilityToggle()) {
    const observer = new MutationObserver(() => {
      if (installVisibilityToggle()) observer.disconnect();
    });
    observer.observe(document.querySelector('#report') ?? document.body, {
      childList: true,
      subtree: true
    });
  }
}, 0));
</script>`;
}

export async function enhanceAutomationReport(reportPath) {
  const html = await fs.readFile(reportPath, 'utf8');
  if (html.includes(`id="${enhancementMarker}"`)) return false;

  const [styles, script] = buildReportEnhancements().split('<script>');
  const enhancedHtml = html
    .replace('</head>', () => `${styles}</head>`)
    .replace('</body>', () => `<script>${script}</body>`);
  await fs.writeFile(reportPath, enhancedHtml);
  return true;
}
