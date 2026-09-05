export function qualifySuiteTitles(rootSuite, resolution) {
  if (!resolution) return;

  const qualify = suite => {
    if (suite.title && !suite.title.endsWith(` (${resolution})`)) {
      suite.title += ` (${resolution})`;
    }
    for (const child of suite.suites ?? []) qualify(child);
  };
  for (const suite of rootSuite?.suites ?? []) qualify(suite);
}
