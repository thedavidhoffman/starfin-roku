import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import zlib from "node:zlib";
import { focusAlphaBounds, focusGeometry, focusSourceChecks, scaleInclusiveBounds } from "./focus-geometry.mjs";

const root = process.cwd();

// Bounds are inclusive and describe the intended visible mask or focus artwork.
const assets = {
  "images/header/fhd/account-badge-glass.png": [102, 102, [0, 0, 101, 101]],
  "images/header/fhd/account-badge-ring.png": [102, 102, [0, 0, 101, 101]],
  "images/icons/fhd/busy-spinner.png": [192, 192, [29, 29, 162, 162]],
  "images/masks/fhd/account-badge-user-mask.png": [96, 96, [0, 0, 95, 95]],
  "images/masks/fhd/account-menu-user-mask.png": [144, 144, [0, 0, 143, 143]],
  "images/masks/fhd/cast-mask.png": [195, 195, [0, 0, 194, 194]],
  "images/masks/fhd/person-mask.png": [399, 600, [0, 0, 398, 599]],
  "images/masks/fhd/filmography-movie-mask.png": [342, 513, [0, 0, 341, 512]],
  "images/masks/fhd/detailed-poster-mask.png": [288, 432, [0, 0, 286, 430]],
  "images/masks/fhd/detailed-card-mask.png": [882, 496, [0, 0, 880, 494]],
  "images/masks/fhd/album-mask-300.png": [300, 300, [0, 0, 299, 299]],
  "images/masks/fhd/album-mask-342.png": [342, 342, [0, 0, 341, 341]],
  "images/masks/fhd/audio-player-album-mask.png": [651, 651, [0, 0, 650, 650]],
  "images/masks/fhd/media-shell-backdrop-mask.png": [1152, 648, [1, 0, 1151, 646]],
  "images/masks/fhd/trickplay-center-mask.png": [384, 216, [0, 0, 383, 215]],
  "images/masks/fhd/trickplay-side-mask.png": [225, 126, [0, 0, 224, 125]],
  "images/masks/fhd/episode-thumbnail-mask.png": [531, 300, [0, 0, 530, 299]],
  "images/masks/fhd/season-poster-mask.png": [207, 312, [0, 0, 206, 311]],
  "images/cast/cast-placeholder-195x195.png": [195, 195, [0, 0, 194, 194]],
  "images/cast/filmography-list-focused-741x99.png": [741, 99, [0, 0, 740, 98]],
  "images/cast/filmography-movie-mask-342x513.png": [342, 513, [0, 0, 341, 512]],
  "images/cast/person-placeholder-399x600.png": [399, 600, [0, 0, 398, 599]],
  "images/cast/person-mask-399x600.png": [399, 600, [0, 0, 398, 599]],
  "images/media-card/poster-placeholder-252x378.png": [252, 378, [0, 0, 251, 377]],
  "images/media-card/thumbnail-placeholder-441x249.png": [441, 249, [0, 0, 440, 248]],
  "images/media-card/detailed-poster-mask-288x432.png": [288, 432, [0, 0, 286, 430]],
  "images/media-card/detailed-card-mask-882x496.png": [882, 496, [0, 0, 880, 494]],
  "images/music/album-mask-300x300.png": [300, 300, [0, 0, 299, 299]],
  "images/music/album-placeholder-300x300.png": [300, 300, [0, 0, 299, 299]],
  "images/music/album-mask-342x342.png": [342, 342, [0, 0, 341, 341]],
  "images/music/album-placeholder-342x342.png": [342, 342, [0, 0, 341, 341]],
  "images/music/audio-player-album-mask-651x651.png": [651, 651, [0, 0, 650, 650]],
  "images/overlays/media-shell-backdrop-mask.png": [1152, 648, [1, 0, 1151, 646]],
  "images/trickplay/preview-center-mask.png": [384, 216, [0, 0, 383, 215]],
  "images/trickplay/preview-side-mask.png": [225, 126, [0, 0, 224, 125]],
  "images/tv-season/episode-thumbnail-mask-531x300.png": [531, 300, [0, 0, 530, 299]],
  "images/tv-show/season-poster-mask-207x312.png": [207, 312, [0, 0, 206, 311]],
  "images/tv-show/season-placeholder-207x312.png": [207, 312, [0, 0, 206, 311]],
};

const hdMaskAssets = {
  "images/masks/hd/account-badge-user-mask.png": [64, 64, [0, 0, 63, 63], 96, 96],
  "images/masks/hd/account-menu-user-mask.png": [96, 96, [0, 0, 95, 95], 144, 144],
  "images/masks/hd/cast-mask.png": [130, 130, [0, 0, 129, 129], 195, 195],
  "images/masks/hd/person-mask.png": [266, 400, [0, 0, 265, 399], 399, 600],
  "images/masks/hd/filmography-movie-mask.png": [228, 342, [0, 0, 227, 341], 342, 513],
  "images/masks/hd/detailed-poster-mask.png": [192, 288, [0, 0, 191, 287], 288, 432],
  "images/masks/hd/detailed-card-mask.png": [588, 331, [0, 0, 587, 330], 882, 496],
  "images/masks/hd/album-mask-300.png": [200, 200, [0, 0, 199, 199], 300, 300],
  "images/masks/hd/album-mask-342.png": [228, 228, [0, 0, 227, 227], 342, 342],
  "images/masks/hd/audio-player-album-mask.png": [434, 434, [0, 0, 433, 433], 651, 651],
  "images/masks/hd/media-shell-backdrop-mask.png": [768, 432, [1, 0, 767, 430], 1152, 648],
  "images/masks/hd/trickplay-center-mask.png": [256, 144, [0, 0, 255, 143], 384, 216],
  "images/masks/hd/trickplay-side-mask.png": [150, 84, [0, 0, 149, 83], 225, 126],
  "images/masks/hd/episode-thumbnail-mask.png": [354, 200, [0, 0, 353, 199], 531, 300],
  "images/masks/hd/season-poster-mask.png": [138, 208, [0, 0, 137, 207], 207, 312],
};

const hdImageAssets = {
  "images/header/hd/account-badge-glass.png": [68, 68, [0, 0, 67, 67], 102, 102],
  "images/header/hd/account-badge-ring.png": [68, 68, [0, 0, 67, 67], 102, 102],
  "images/icons/hd/busy-spinner.png": [128, 128, [19, 19, 108, 108], 192, 192],
};

const generatedMaskSources = {
  "account-badge-user-mask.png": "images/header/account-badge-user-mask-96x96.png",
  "account-menu-user-mask.png": "images/header/account-menu-user-mask-144x144.png",
  "cast-mask.png": "images/cast/cast-mask-195x195.png",
  "person-mask.png": "images/cast/person-mask-399x600.png",
  "filmography-movie-mask.png": "images/cast/filmography-movie-mask-342x513.png",
  "detailed-poster-mask.png": "images/media-card/detailed-poster-mask-288x432.png",
  "detailed-card-mask.png": "images/media-card/detailed-card-mask-882x496.png",
  "album-mask-300.png": "images/music/album-mask-300x300.png",
  "album-mask-342.png": "images/music/album-mask-342x342.png",
  "audio-player-album-mask.png": "images/music/audio-player-album-mask-651x651.png",
  "media-shell-backdrop-mask.png": "images/overlays/media-shell-backdrop-mask.png",
  "trickplay-center-mask.png": "images/trickplay/preview-center-mask.png",
  "trickplay-side-mask.png": "images/trickplay/preview-side-mask.png",
  "episode-thumbnail-mask.png": "images/tv-season/episode-thumbnail-mask-531x300.png",
  "season-poster-mask.png": "images/tv-show/season-poster-mask-207x312.png",
};

const libraryMaskAssets = {
  "poster-3-col-mask.png": { fhd: [537, 806], hd: [358, 537] },
  "poster-4-col-mask.png": { fhd: [393, 590], hd: [262, 393] },
  "poster-5-col-mask.png": { fhd: [309, 464], hd: [206, 309] },
  "poster-6-col-mask.png": { fhd: [252, 378], hd: [168, 252] },
  "thumbnail-2-col-mask.png": { fhd: [906, 510], hd: [604, 340] },
  "thumbnail-3-col-mask.png": { fhd: [596, 335], hd: [397, 223] },
  "thumbnail-4-col-mask.png": { fhd: [441, 249], hd: [294, 166] },
};

const libraryFocusAssets = {
  "poster-3-col-focus.png": [582, 893, [15, 0, 564, 810]],
  "poster-4-col-focus.png": [438, 677, [15, 0, 420, 594]],
  "poster-5-col-focus.png": [354, 551, [15, 0, 336, 468]],
  "poster-6-col-focus.png": [297, 465, [15, 0, 279, 382]],
  "thumbnail-2-col-focus.png": [930, 609, [15, 0, 929, 514]],
  "thumbnail-3-col-focus.png": [620, 434, [15, 0, 619, 339]],
  "thumbnail-4-col-focus.png": [465, 348, [15, 0, 464, 253]],
};

const geometryChecks = {
  "components/pages/Video/Cast/CastItem/CastItem.bs": ["MaskAssets.GetProfile(\"cast-mask.png\", [195, 195], [130, 130])"],
  "components/pages/Video/Cast/Person/Person.bs": ["MaskAssets.Apply(m.top.findNode(\"personImageMask\"), \"person-mask.png\", [399, 600], [266, 400])"],
  "components/pages/Video/Cast/Filmography/Filmography.bs": ["MaskAssets.Apply(m.top.findNode(\"previewPosterMask\"), \"filmography-movie-mask.png\", [342, 513], [228, 342])"],
  "components/pages/Video/Cards/VideoPosterCard/VideoPosterCard.bs": ["posterMaskName: \"poster-6-col-mask.png\"", "posterSize: [252, 378]", "hdPosterSize: [168, 252]"],
  "components/pages/Video/Cards/VideoThumbnailCard/VideoThumbnailCard.bs": ["posterMaskName: \"thumbnail-4-col-mask.png\"", "posterSize: [441, 249]", "hdPosterSize: [294, 166]"],
  "components/controls/Spinner/Spinner.bs": ["m.spinner.uri = ResolutionAssets.GetIconImageUri(\"busy-spinner.png\")"],
  "source/ResolutionAssets.bs": ["function __GetImageUri(category as string, filename as string)", "ResolutionProfile.GetName()"],
  "components/pages/Video/TVShow/TVSeasonCard/TVSeasonCard.bs": ["MaskAssets.Apply(m.top.findNode(\"seasonPosterMask\"), \"season-poster-mask.png\", [207, 312], [138, 208])"],
  "components/pages/Video/TVSeason/TVEpisodePoster/TVEpisodePoster.bs": ["MaskAssets.Apply(m.posterMask, \"episode-thumbnail-mask.png\", [width, height], [hdWidth, hdHeight])"],
  "components/pages/Video/VideoPlayer/TrickplayPreviewStrip/TrickplayPreviewStrip.bs": ["MaskAssets.Apply(slot.imageMask, maskFilename, [tileWidth, tileHeight], [hdTileWidth, hdTileHeight])"],
  "components/pages/Music/MusicAlbumCard/MusicAlbumCard.bs": ["MaskAssets.Apply(m.albumMask, \"album-mask-300.png\", [300, 300], [200, 200])", "MaskAssets.Apply(m.albumMask, \"album-mask-342.png\", [342, 342], [228, 228])"],
  "components/pages/Music/MusicArtistCard/MusicArtistCard.bs": ["MaskAssets.Apply(m.top.findNode(\"artistMask\"), \"album-mask-342.png\", [342, 342], [228, 228])"],
  "components/pages/Music/ArtistAlbumRowItem/ArtistAlbumRowItem.bs": ["MaskAssets.Apply(m.top.findNode(\"albumMask\"), \"album-mask-300.png\", [300, 300], [200, 200])"],
  "components/pages/Music/AudioPlayer/AudioPlayer.bs": ["MaskAssets.Apply(m.top.findNode(\"albumArtworkMask\"), \"audio-player-album-mask.png\", [651, 651], [434, 434])"],
  "components/pages/Video/TVSeason/TVSeason.xml": ["rowItemSize=\"[[576,591]]\"", "itemSize=\"[576,591]\""],
  "components/pages/Video/TVShow/TVShow.xml": ["itemSize=\"[207,381]\""],
  "components/pages/Music/MusicLibrary/MusicLibrary.xml": ["itemSize=\"[360,432]\""],
  "components/pages/MediaShell/MediaShell.bs": ["MaskAssets.Apply(m.mediaBackgroundPartialGroup, \"media-shell-backdrop-mask.png\", [1152, 648], [768, 432])"],
  "source/main.bs": ["globalNode.AddFields({ resolutionProfile: ResolutionProfile.Create() })"],
  "source/MaskAssets.bs": ["if ResolutionProfile.IsHd() then", "ResolutionAssets.GetMaskImageUri(filename)"],
  "source/ResolutionProfile.bs": ["deviceInfo.GetUIResolution()", "uiResolution.height <= 720", "profile = m.global.resolutionProfile", "return ResolutionProfile.GetName() = \"hd\""],
};

function decodePng(filePath) {
  const png = fs.readFileSync(filePath);
  const signature = "89504e470d0a1a0a";
  if (png.subarray(0, 8).toString("hex") !== signature) throw new Error("not a PNG");

  let offset = 8;
  let header;
  const data = [];
  while (offset < png.length) {
    const length = png.readUInt32BE(offset);
    const type = png.toString("ascii", offset + 4, offset + 8);
    const chunk = png.subarray(offset + 8, offset + 8 + length);
    if (type === "IHDR") {
      header = {
        width: chunk.readUInt32BE(0),
        height: chunk.readUInt32BE(4),
        bitDepth: chunk[8],
        colorType: chunk[9],
        interlace: chunk[12],
      };
    } else if (type === "IDAT") {
      data.push(chunk);
    } else if (type === "IEND") {
      break;
    }
    offset += length + 12;
  }

  if (!header || header.bitDepth !== 8 || header.interlace !== 0) {
    throw new Error("only non-interlaced 8-bit PNG assets are supported");
  }

  const channels = { 0: 1, 2: 3, 4: 2, 6: 4 }[header.colorType];
  if (!channels) throw new Error(`unsupported PNG color type ${header.colorType}`);
  const stride = header.width * channels;
  const raw = zlib.inflateSync(Buffer.concat(data));
  const pixels = Buffer.alloc(stride * header.height);

  for (let y = 0; y < header.height; y += 1) {
    const source = y * (stride + 1);
    const target = y * stride;
    const filter = raw[source];
    for (let x = 0; x < stride; x += 1) {
      const value = raw[source + x + 1];
      const left = x >= channels ? pixels[target + x - channels] : 0;
      const up = y > 0 ? pixels[target + x - stride] : 0;
      const upperLeft = y > 0 && x >= channels ? pixels[target + x - stride - channels] : 0;
      let decoded = value;
      if (filter === 1) decoded += left;
      else if (filter === 2) decoded += up;
      else if (filter === 3) decoded += Math.floor((left + up) / 2);
      else if (filter === 4) decoded += paeth(left, up, upperLeft);
      else if (filter !== 0) throw new Error(`unsupported PNG filter ${filter}`);
      pixels[target + x] = decoded & 0xff;
    }
  }

  const alphaIndex = header.colorType === 6 ? 3 : header.colorType === 4 ? 1 : -1;
  let bounds = [header.width, header.height, -1, -1];
  for (let y = 0; y < header.height; y += 1) {
    for (let x = 0; x < header.width; x += 1) {
      const alpha = alphaIndex < 0 ? 255 : pixels[y * stride + x * channels + alphaIndex];
      if (alpha === 0) continue;
      bounds = [Math.min(bounds[0], x), Math.min(bounds[1], y), Math.max(bounds[2], x), Math.max(bounds[3], y)];
    }
  }
  const getAlpha = (x, y) => alphaIndex < 0 ? 255 : pixels[y * stride + x * channels + alphaIndex];
  return {
    ...header,
    bounds,
    alphaSignature: [
      getAlpha(0, 0),
      getAlpha(header.width - 1, 0),
      getAlpha(0, header.height - 1),
      getAlpha(header.width - 1, header.height - 1),
      getAlpha(Math.floor((header.width - 1) / 2), Math.floor((header.height - 1) / 2)),
    ],
  };
}

function paeth(left, up, upperLeft) {
  const estimate = left + up - upperLeft;
  const leftDistance = Math.abs(estimate - left);
  const upDistance = Math.abs(estimate - up);
  const upperLeftDistance = Math.abs(estimate - upperLeft);
  if (leftDistance <= upDistance && leftDistance <= upperLeftDistance) return left;
  return upDistance <= upperLeftDistance ? up : upperLeft;
}

const failures = [];
const focusAssetNames = new Set();

for (const definition of focusGeometry) {
  const { asset, canvas, image, outline, anchorCompensation, name, owner, surface } = definition;
  if (focusAssetNames.has(asset)) failures.push(`${asset}: duplicate focus geometry definition`);
  focusAssetNames.add(asset);

  if (surface !== "RowList" && surface !== "MarkupGrid") failures.push(`${asset}: unsupported focus surface ${surface}`);
  if (!fs.existsSync(path.join(root, owner))) failures.push(`${asset}: geometry owner ${owner} does not exist`);
  if (canvas.some((value) => value % 3 !== 0)) failures.push(`${asset}: focus canvas must divide evenly by 3 for Roku's FHD-to-HD scaling`);
  if ([...image, ...outline, ...anchorCompensation].some((value) => !Number.isInteger(value))) failures.push(`${asset}: focus geometry must use integer FHD coordinates`);

  const [canvasWidth, canvasHeight] = canvas;
  const [imageX, imageY, imageWidth, imageHeight] = image;
  if (imageWidth <= 0 || imageHeight <= 0 || imageX < 0 || imageY < 0 || imageX + imageWidth > canvasWidth || imageY + imageHeight > canvasHeight) {
    failures.push(`${asset}: visible image rectangle ${image} must fit inside canvas ${canvas}`);
  }

  const expectedBounds = focusAlphaBounds(definition);
  try {
    const actual = decodePng(path.join(root, asset));
    if (actual.width !== canvasWidth || actual.height !== canvasHeight) failures.push(`${asset}: ${name} ${surface} canvas expected ${canvasWidth}x${canvasHeight}, found ${actual.width}x${actual.height}`);
    if (actual.bounds.join(",") !== expectedBounds.join(",")) failures.push(`${asset}: expected derived alpha bounds ${expectedBounds}, found ${actual.bounds}`);

    const desiredFhdBounds = [
      expectedBounds[0] - anchorCompensation[0],
      expectedBounds[1] - anchorCompensation[1],
      expectedBounds[2] - anchorCompensation[2],
      expectedBounds[3] - anchorCompensation[3],
    ];
    const hdImageBounds = scaleInclusiveBounds([imageX, imageY, imageX + imageWidth - 1, imageY + imageHeight - 1]);
    const hdOutlineBounds = scaleInclusiveBounds(desiredFhdBounds);
    if (hdOutlineBounds[0] > hdImageBounds[0] || hdOutlineBounds[1] > hdImageBounds[1] || hdOutlineBounds[2] < hdImageBounds[2] || hdOutlineBounds[3] < hdImageBounds[3]) {
      failures.push(`${asset}: projected 720p outline ${hdOutlineBounds} does not cover projected image ${hdImageBounds}`);
    }
  } catch (error) {
    failures.push(`${asset}: ${error.message}`);
  }
}

for (const [relativePath, fragments] of Object.entries(focusSourceChecks)) {
  const contents = fs.readFileSync(path.join(root, relativePath), "utf8");
  for (const fragment of fragments) {
    if (!contents.includes(fragment)) failures.push(`${relativePath}: focus geometry source no longer contains ${fragment}`);
  }
}

const verifyMaskAlphaSignature = (relativePath, actual) => {
  const [topLeft, topRight, bottomLeft, bottomRight, center] = actual.alphaSignature;
  if (center !== 255) failures.push(`${relativePath}: mask center must be fully opaque`);
  if (relativePath.endsWith("media-shell-backdrop-mask.png")) {
    if (topLeft !== 0 || topRight === 0 || bottomLeft !== 0 || bottomRight !== 0) failures.push(`${relativePath}: media-shell corner alpha signature is invalid`);
  } else if (topLeft !== 0 || topRight !== 0 || bottomLeft !== 0 || bottomRight !== 0) {
    failures.push(`${relativePath}: rounded mask corners must be fully transparent`);
  }
};

for (const [relativePath, [expectedWidth, expectedHeight, expectedBounds]] of Object.entries(assets)) {
  if (path.basename(relativePath) !== path.basename(relativePath).toLowerCase() || path.basename(relativePath).includes("_")) {
    failures.push(`${relativePath}: filename must use dash-case`);
  }
  try {
    const actual = decodePng(path.join(root, relativePath));
    if (actual.width !== expectedWidth || actual.height !== expectedHeight) failures.push(`${relativePath}: expected ${expectedWidth}x${expectedHeight}, found ${actual.width}x${actual.height}`);
    if (actual.bounds.join(",") !== expectedBounds.join(",")) failures.push(`${relativePath}: expected alpha bounds ${expectedBounds}, found ${actual.bounds}`);
    if (relativePath.startsWith("images/masks/fhd/")) verifyMaskAlphaSignature(relativePath, actual);
  } catch (error) {
    failures.push(`${relativePath}: ${error.message}`);
  }
}

for (const [relativePath, [expectedWidth, expectedHeight, expectedBounds, fhdWidth, fhdHeight]] of Object.entries(hdMaskAssets)) {
  if (path.basename(relativePath) !== path.basename(relativePath).toLowerCase() || path.basename(relativePath).includes("_")) {
    failures.push(`${relativePath}: filename must use dash-case`);
  }
  try {
    const actual = decodePng(path.join(root, relativePath));
    if (actual.width !== expectedWidth || actual.height !== expectedHeight) failures.push(`${relativePath}: expected ${expectedWidth}x${expectedHeight}, found ${actual.width}x${actual.height}`);
    if (actual.bounds.join(",") !== expectedBounds.join(",")) failures.push(`${relativePath}: expected alpha bounds ${expectedBounds}, found ${actual.bounds}`);
    if (expectedWidth !== Math.round(fhdWidth * 2 / 3) || expectedHeight !== Math.round(fhdHeight * 2 / 3)) failures.push(`${relativePath}: HD mask must be the rounded two-thirds size of its FHD canvas`);
    verifyMaskAlphaSignature(relativePath, actual);
  } catch (error) {
    failures.push(`${relativePath}: ${error.message}`);
  }
}

for (const [relativePath, [expectedWidth, expectedHeight, expectedBounds, fhdWidth, fhdHeight]] of Object.entries(hdImageAssets)) {
  try {
    const actual = decodePng(path.join(root, relativePath));
    if (actual.width !== expectedWidth || actual.height !== expectedHeight) failures.push(`${relativePath}: expected ${expectedWidth}x${expectedHeight}, found ${actual.width}x${actual.height}`);
    if (actual.bounds.join(",") !== expectedBounds.join(",")) failures.push(`${relativePath}: expected alpha bounds ${expectedBounds}, found ${actual.bounds}`);
    if ((expectedWidth * 3) !== (fhdWidth * 2) || (expectedHeight * 3) !== (fhdHeight * 2)) failures.push(`${relativePath}: HD image must be exactly two-thirds of its FHD canvas`);
  } catch (error) {
    failures.push(`${relativePath}: ${error.message}`);
  }
}

for (const [filename, profiles] of Object.entries(libraryMaskAssets)) {
  for (const resolution of ["fhd", "hd"]) {
    const [expectedWidth, expectedHeight] = profiles[resolution];
    const relativePath = `images/masks/${resolution}/${filename}`;
    try {
      const actual = decodePng(path.join(root, relativePath));
      if (actual.width !== expectedWidth || actual.height !== expectedHeight) failures.push(`${relativePath}: expected ${expectedWidth}x${expectedHeight}, found ${actual.width}x${actual.height}`);
      if (actual.bounds.join(",") !== `0,0,${expectedWidth - 1},${expectedHeight - 1}`) failures.push(`${relativePath}: expected full alpha bounds, found ${actual.bounds}`);
      verifyMaskAlphaSignature(relativePath, actual);
    } catch (error) {
      failures.push(`${relativePath}: ${error.message}`);
    }
  }
}

for (const [filename, [expectedWidth, expectedHeight, expectedBounds]] of Object.entries(libraryFocusAssets)) {
  for (const resolution of ["fhd", "hd"]) {
    const relativePath = `images/library/${resolution}/${filename}`;
    try {
      const actual = decodePng(path.join(root, relativePath));
      if (actual.width !== expectedWidth || actual.height !== expectedHeight) failures.push(`${relativePath}: expected ${expectedWidth}x${expectedHeight}, found ${actual.width}x${actual.height}`);
      if (actual.bounds.join(",") !== expectedBounds.join(",")) failures.push(`${relativePath}: expected alpha bounds ${expectedBounds}, found ${actual.bounds}`);
    } catch (error) {
      failures.push(`${relativePath}: ${error.message}`);
    }
  }
}

const sharedMaskNames = Object.keys(generatedMaskSources).sort();
const libraryMaskNames = Object.keys(libraryMaskAssets).sort();
const expectedMaskNames = [...sharedMaskNames, ...libraryMaskNames].sort();
for (const resolution of ["fhd", "hd"]) {
  const directory = path.join(root, "images", "masks", resolution);
  const actualNames = fs.readdirSync(directory).filter((name) => name.endsWith(".png")).sort();
  if (actualNames.join(",") !== expectedMaskNames.join(",")) failures.push(`images/masks/${resolution}: expected ${expectedMaskNames}, found ${actualNames}`);
}

for (const [filename, sourcePath] of Object.entries(generatedMaskSources)) {
  const source = fs.readFileSync(path.join(root, sourcePath));
  const generatedFhd = fs.readFileSync(path.join(root, "images", "masks", "fhd", filename));
  if (!source.equals(generatedFhd)) failures.push(`images/masks/fhd/${filename}: does not match canonical source ${sourcePath}`);
}

const referencedImages = new Set();
const hdOnlyHomepageAssets = new Set([
  "home-page-my-media-first-focus.png",
]);

const addHomepageAssetReference = (filename, sourcePath) => {
  const resolutions = hdOnlyHomepageAssets.has(filename) ? ["hd"] : ["fhd", "hd"];
  for (const resolution of resolutions) {
    const relativeImagePath = `images/homepage/${resolution}/${filename}`;
    referencedImages.add(relativeImagePath);
    if (!fs.existsSync(path.join(root, relativeImagePath))) failures.push(`${sourcePath}: missing pkg:/${relativeImagePath}`);
  }
};

const scanImageReferences = (directory) => {
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const entryPath = path.join(directory, entry.name);
    if (entry.isDirectory()) {
      scanImageReferences(entryPath);
    } else if (entry.name.endsWith(".bs") || entry.name.endsWith(".brs") || entry.name.endsWith(".xml")) {
      const contents = fs.readFileSync(entryPath, "utf8");
      for (const match of contents.matchAll(/pkg:\/images\/[^"'\s+]+\.png/g)) {
        const relativeImagePath = match[0].substring("pkg:/".length);
        referencedImages.add(relativeImagePath);
        if (!fs.existsSync(path.join(root, relativeImagePath))) failures.push(`${path.relative(root, entryPath)}: missing ${match[0]}`);
      }
      for (const match of contents.matchAll(/focusBitmapFilename(?::|\s*=)\s*"([^"]+)"/g)) {
        addHomepageAssetReference(match[1], path.relative(root, entryPath));
      }
      for (const match of contents.matchAll(/HomepageAssets_GetUri\("([^"]+)"\)/g)) {
        addHomepageAssetReference(match[1], path.relative(root, entryPath));
      }
      for (const match of contents.matchAll(/ResolutionAssets\.GetHomepageImageUri\("([^"]+)"\)/g)) {
        addHomepageAssetReference(match[1], path.relative(root, entryPath));
      }
    }
  }
};
scanImageReferences(path.join(root, "components"));
scanImageReferences(path.join(root, "source"));
for (const definition of focusGeometry) {
  if (!referencedImages.has(definition.asset)) failures.push(`${definition.asset}: focus geometry asset is not referenced by SceneGraph code`);
}

const temporaryRoot = fs.mkdtempSync(path.join(os.tmpdir(), "starfin-mask-geometry-"));
try {
  const generation = spawnSync("powershell", [
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", path.join(root, "scripts", "generate-hd-mask-assets.ps1"),
    "-SourceRoot", root,
    "-OutputRoot", temporaryRoot,
  ], { encoding: "utf8" });
  if (generation.status !== 0) {
    failures.push(`temporary mask generation failed: ${generation.stderr || generation.stdout}`);
  } else {
    for (const resolution of ["fhd", "hd"]) {
      for (const filename of sharedMaskNames) {
        const expected = fs.readFileSync(path.join(root, "images", "masks", resolution, filename));
        const regenerated = fs.readFileSync(path.join(temporaryRoot, "images", "masks", resolution, filename));
        if (!expected.equals(regenerated)) failures.push(`images/masks/${resolution}/${filename}: differs from regenerated output`);
      }
    }
  }
} finally {
  fs.rmSync(temporaryRoot, { recursive: true, force: true });
}

const temporaryLibraryRoot = fs.mkdtempSync(path.join(os.tmpdir(), "starfin-library-geometry-"));
try {
  const generation = spawnSync("powershell", [
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", path.join(root, "scripts", "generate-library-card-assets.ps1"),
    "-Root", temporaryLibraryRoot,
  ], { encoding: "utf8" });
  if (generation.status !== 0) {
    failures.push(`temporary library asset generation failed: ${generation.stderr || generation.stdout}`);
  } else {
    for (const resolution of ["fhd", "hd"]) {
      for (const filename of libraryMaskNames) {
        const expected = fs.readFileSync(path.join(root, "images", "masks", resolution, filename));
        const regenerated = fs.readFileSync(path.join(temporaryLibraryRoot, "images", "masks", resolution, filename));
        if (!expected.equals(regenerated)) failures.push(`images/masks/${resolution}/${filename}: differs from regenerated output`);
      }
      for (const filename of Object.keys(libraryFocusAssets)) {
        const expected = fs.readFileSync(path.join(root, "images", "library", resolution, filename));
        const regenerated = fs.readFileSync(path.join(temporaryLibraryRoot, "images", "library", resolution, filename));
        if (!expected.equals(regenerated)) failures.push(`images/library/${resolution}/${filename}: differs from regenerated output`);
      }
    }
  }
} finally {
  fs.rmSync(temporaryLibraryRoot, { recursive: true, force: true });
}

for (const [relativePath, fragments] of Object.entries(geometryChecks)) {
  const contents = fs.readFileSync(path.join(root, relativePath), "utf8");
  for (const fragment of fragments) {
    if (!contents.includes(fragment)) failures.push(`${relativePath}: missing geometry ${fragment}`);
  }
}

if (failures.length > 0) {
  console.error(failures.join("\n"));
  process.exitCode = 1;
} else {
  console.log(`Verified ${Object.keys(assets).length} fixed assets, ${focusGeometry.length} focus geometries, and ${Object.keys(hdMaskAssets).length} HD mask assets.`);
}
