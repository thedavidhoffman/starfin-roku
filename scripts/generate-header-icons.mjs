import sharp from 'sharp';
import { mkdir } from 'node:fs/promises';

const paths = {
  home: '<path d="M11 29 32 12 53 29"/><path d="M17 25V52H47V25"/><path d="M27 52V37H37V52"/>',
  search: '<circle cx="27" cy="27" r="15"/><path d="M38 38 53 53"/>',
  system: '<path d="M27 9H37L39 16 45 19 52 16 57 25 52 30V34L57 39 52 48 45 45 39 48 37 55H27L25 48 19 45 12 48 7 39 12 34V30L7 25 12 16 19 19 25 16Z"/><circle cx="32" cy="32" r="9"/>',
  account: '<circle cx="32" cy="22" r="10"/><path d="M12 53C13 42 21 37 32 37S51 42 52 53Z"/>',
  settings: '<path d="M9 17H55M9 32H55M9 47H55"/><circle cx="23" cy="17" r="5" fill="#fff"/><circle cx="41" cy="32" r="5" fill="#fff"/><circle cx="27" cy="47" r="5" fill="#fff"/>',
  'system-info': '<circle cx="32" cy="32" r="23"/><path d="M32 29V44"/><circle cx="32" cy="21" r="2.5" fill="#fff" stroke="none"/>',
  'app-log': '<path d="M17 8H39L49 18V56H17Z"/><path d="M39 8V18H49M24 28H41M24 36H41M24 44H37"/>',
  'switch-account': '<path d="M14 24H49M49 24L42 17M49 24L42 31M50 40H15M15 40L22 33M15 40L22 47"/>',
  logout: '<path d="M35 11H16V53H35M26 32H53M53 32L45 24M53 32L45 40"/>',
};

await mkdir('images/icons/header', { recursive: true });

for (const [name, path] of Object.entries(paths)) {
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64" fill="none" stroke="#fff" stroke-width="4.5" stroke-linecap="round" stroke-linejoin="round">${path}</svg>`;
  const raster = await sharp(Buffer.from(svg)).resize(256, 256).png().toBuffer();
  const trimmed = await sharp(raster).trim().png().toBuffer();
  await sharp(trimmed).resize({ height: 88 }).png().toFile(`images/icons/header/${name}.png`);
}
