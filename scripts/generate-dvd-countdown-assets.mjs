import sharp from 'sharp';
import { mkdir, readFile } from 'node:fs/promises';

const layout = JSON.parse(await readFile(new URL('../components/pages/DvdPlayer/Helpers/continuation-countdown-layout.json', import.meta.url), 'utf8'));
const fixedWidth = layout.padding * 2 + layout.labelWidth + layout.suffixWidth;

// Fixed-size badge: scale the two-pixel design stroke with the display profile.
for (const [profile, scale] of [['fhd', 1], ['hd', 2 / 3]]) {
  for (const [secondsWidth, suffix] of [[layout.secondsWidth, ""], [layout.wideSecondsWidth, "-wide"]]) {
    const width = Math.round((fixedWidth + secondsWidth) * scale);
    const height = layout.height * scale;
    const stroke = layout.borderWidth * scale;
    const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}">
      <rect x="${stroke / 2}" y="${stroke / 2}" width="${width - stroke}" height="${height - stroke}" rx="${layout.cornerRadius * scale}" fill="black" fill-opacity="${layout.fillOpacity}" stroke="white" stroke-width="${stroke}"/>
    </svg>`;
    await mkdir(`images/dvd/${profile}`, { recursive: true });
    await sharp(Buffer.from(svg)).png().toFile(`images/dvd/${profile}/continuation-countdown${suffix}.png`);
  }
}
