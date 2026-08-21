// Focus geometry is expressed in canonical 1080p SceneGraph coordinates.
// Rectangles use [x, y, width, height]. Insets use [left, top, right, bottom].
// anchorCompensation records Roku's measured focus-bitmap anchoring difference
// after the desired outline is placed around the visible image rectangle.
export const focusGeometry = [
  {
    name: "cast-row",
    asset: "images/cast/cast-focus-246x264.png",
    owner: "components/pages/Video/Cast/Cast/Cast.xml",
    surface: "RowList",
    canvas: [246, 264],
    image: [6, 6, 195, 195],
    outline: [3, 3, 3, 3],
    anchorCompensation: [19, -3, 24, 1],
  },
  {
    name: "home-music-row",
    asset: "images/homepage/fhd/home-page-music-focus.png",
    owner: "components/pages/HomePage/HomeShelf/HomeShelf.xml",
    surface: "RowList",
    canvas: [345, 423],
    image: [21, 33, 300, 300],
    outline: [3, 3, 3, 3],
    anchorCompensation: [24, 1, 20, -3],
  },
  {
    name: "home-music-hd-row",
    asset: "images/homepage/hd/home-page-music-focus.png",
    owner: "components/pages/HomePage/HomeShelf/HomeShelf.xml",
    surface: "RowList",
    canvas: [345, 423],
    image: [21, 33, 300, 300],
    outline: [3, 3, 3, 3],
    anchorCompensation: [24, 1, 20, -3],
  },
  {
    name: "home-thumbnail-row",
    asset: "images/homepage/fhd/home-page-thumbnail-focus.png",
    owner: "components/pages/HomePage/HomeShelf/HomeShelf.xml",
    surface: "RowList",
    canvas: [486, 348],
    image: [21, 0, 441, 249],
    outline: [3, 0, 3, 3],
    anchorCompensation: [21, 0, 22, 0],
  },
  {
    name: "home-thumbnail-hd-row",
    asset: "images/homepage/hd/home-page-thumbnail-focus.png",
    owner: "components/pages/HomePage/HomeShelf/HomeShelf.xml",
    surface: "RowList",
    canvas: [486, 348],
    image: [21, 0, 441, 249],
    outline: [3, 0, 3, 3],
    anchorCompensation: [17, 0, 18, -2],
  },
  {
    name: "person-episode-hd-row",
    asset: "images/homepage/hd/person-episode-focus.png",
    owner: "components/pages/Video/Cast/Person/Person.xml",
    surface: "RowList",
    canvas: [486, 348],
    image: [21, 0, 441, 249],
    outline: [3, 0, 3, 3],
    anchorCompensation: [17, 0, 18, 0],
  },
  {
    name: "person-episode-row",
    asset: "images/homepage/fhd/person-episode-focus.png",
    owner: "components/pages/Video/Cast/Person/Person.xml",
    surface: "RowList",
    canvas: [486, 348],
    image: [21, 0, 441, 249],
    outline: [3, 0, 3, 3],
    anchorCompensation: [21, 0, 22, 0],
  },
  {
    name: "home-my-media-thumbnail-row",
    asset: "images/homepage/fhd/home-page-my-media-thumbnail-focus.png",
    owner: "components/pages/HomePage/HomeShelf/HomeShelf.xml",
    surface: "RowList",
    canvas: [486, 306],
    image: [21, 0, 441, 249],
    outline: [3, 0, 3, 3],
    anchorCompensation: [21, 0, 22, 0],
  },
  {
    name: "home-my-media-thumbnail-hd-row",
    asset: "images/homepage/hd/home-page-my-media-thumbnail-focus.png",
    owner: "components/pages/HomePage/HomeShelf/HomeShelf.xml",
    surface: "RowList",
    canvas: [486, 306],
    image: [21, 0, 441, 249],
    outline: [3, 0, 3, 3],
    anchorCompensation: [20, 0, 21, -2],
  },
  {
    name: "home-my-media-first-hd-row",
    asset: "images/homepage/hd/home-page-my-media-first-focus.png",
    owner: "components/pages/HomePage/HomeShelf/HomeShelf.xml",
    surface: "RowList",
    canvas: [486, 306],
    image: [21, 0, 441, 249],
    outline: [3, 0, 3, 3],
    anchorCompensation: [17, 0, 18, -2],
  },
  {
    name: "home-poster-row",
    asset: "images/homepage/fhd/home-page-poster-focus.png",
    owner: "components/pages/HomePage/HomeShelf/HomeShelf.xml",
    surface: "RowList",
    canvas: [297, 465],
    image: [21, 0, 252, 378],
    outline: [3, 0, 3, 3],
    anchorCompensation: [21, 0, 22, 0],
  },
  {
    name: "home-poster-hd-row",
    asset: "images/homepage/hd/home-page-poster-focus.png",
    owner: "components/pages/HomePage/HomeShelf/HomeShelf.xml",
    surface: "RowList",
    canvas: [297, 465],
    image: [21, 0, 252, 378],
    outline: [3, 0, 3, 3],
    anchorCompensation: [17, 0, 18, -2],
  },
  {
    name: "library-poster-grid",
    asset: "images/library/poster-focus-297x465.png",
    owner: "components/pages/Collections/Collections.xml",
    surface: "MarkupGrid",
    canvas: [297, 465],
    image: [21, 0, 252, 378],
    outline: [3, 0, 3, 0],
    anchorCompensation: [-2, 0, 2, 0],
  },
  {
    name: "library-thumbnail-grid",
    asset: "images/library/thumbnail-focus-465x348.png",
    owner: "components/pages/Collections/Collections.xml",
    surface: "MarkupGrid",
    canvas: [465, 348],
    image: [21, 0, 441, 249],
    outline: [4, 0, 2, 2],
    anchorCompensation: [0, 0, 0, 0],
  },
  {
    name: "music-card-grid",
    asset: "images/music/music-card-focus-360x432.png",
    owner: "components/pages/Music/MusicLibrary/MusicLibrary.xml",
    surface: "MarkupGrid",
    canvas: [360, 432],
    image: [9, 1, 342, 342],
    outline: [1, 1, 1, 1],
    anchorCompensation: [1, 0, 0, 0],
  },
  {
    name: "artist-album-row",
    asset: "images/music/artist-album-horizontal-focus-360x399.png",
    owner: "components/pages/Music/Artist/Artist.xml",
    surface: "RowList",
    canvas: [360, 399],
    image: [30, 0, 300, 300],
    outline: [2, 0, 2, 2],
    anchorCompensation: [19, 0, 18, 0],
  },
  {
    name: "episode-row",
    asset: "images/tv-season/episode-thumbnail-horizontal-focus-576x591.png",
    owner: "components/pages/Video/TVSeason/TVSeason.xml",
    surface: "RowList",
    canvas: [576, 591],
    image: [21, 39, 531, 300],
    outline: [3, 3, 3, 3],
    anchorCompensation: [19, -1, 20, 0],
  },
  {
    name: "episode-grid",
    asset: "images/tv-season/episode-thumbnail-vertical-focus-576x591.png",
    owner: "components/pages/Video/TVSeason/TVSeason.xml",
    surface: "MarkupGrid",
    canvas: [576, 591],
    image: [21, 39, 531, 300],
    outline: [3, 3, 3, 3],
    anchorCompensation: [1, -1, -2, 0],
  },
  {
    name: "season-grid",
    asset: "images/tv-show/season-poster-focus-207x381.png",
    owner: "components/pages/Video/TVShow/TVShow.xml",
    surface: "MarkupGrid",
    canvas: [207, 381],
    image: [0, 0, 207, 312],
    outline: [0, 0, 0, 1],
    anchorCompensation: [0, 0, 0, 0],
  },
];

// These checks bind the declarative model above to the SceneGraph geometry it
// describes. They intentionally include both list/grid canvases and item image
// translations so changing either side cannot leave the verifier stale.
export const focusSourceChecks = {
  "components/pages/Video/Cast/Cast/Cast.xml": [
    "rowItemSize=\"[[246,264]]\"",
    "focusBitmapUri=\"pkg:/images/cast/cast-focus-246x264.png\"",
  ],
  "components/pages/Video/Cast/CastItem/CastItem.xml": [
    "translation=\"[6,6]\" maskUri=\"pkg:/images/masks/fhd/cast-mask.png\" maskSize=\"[195,195]\"",
  ],
  "components/pages/HomePage/HomePage.brs": [
    "width: 345, height: 423",
    "width: 486, height: 306",
    "width: 486, height: 348",
    "width: 297, height: 465",
    "focusBitmapFilename: \"home-page-thumbnail-focus.png\"",
    "focusBitmapFilename: \"home-page-poster-focus.png\"",
  ],
  "components/pages/HomePage/HomeMusicAlbumCard/HomeMusicAlbumCard.xml": [
    "translation=\"[21,0]\"",
    "translation=\"[0,33]\" maskUri=\"pkg:/images/masks/fhd/album-mask-300.png\" maskSize=\"[300,300]\"",
  ],
  "components/pages/HomePage/HomeShelf/HomeShelf.brs": [
    "focusBitmapFilename = \"home-page-my-media-first-focus.png\"",
  ],
  "components/pages/Video/VideoMediaCard/VideoMediaCard.xml": [
    "translation=\"[21,0]\"",
    "maskSize=\"[252,378]\"",
  ],
  "components/pages/Video/VideoMediaCard/VideoMediaCard.brs": [
    "m.poster.width = 441",
    "m.poster.height = 249",
  ],
  "components/pages/Video/Cast/Person/Person.xml": [
    "rowItemSize=\"[[486,348]]\"",
    "focusBitmapUri=\"pkg:/images/homepage/fhd/person-episode-focus.png\"",
  ],
  "components/pages/Video/Cast/Person/Person.brs": [
    "m.relatedRows.focusBitmapUri = HomepageAssets_GetUri(\"home-page-poster-focus.png\")",
    "m.relatedEpisodeRows.focusBitmapUri = HomepageAssets_GetUri(\"person-episode-focus.png\")",
  ],
  "components/pages/Collections/Collections.xml": [
    "itemSize=\"[297,465]\"",
    "focusBitmapUri=\"pkg:/images/library/poster-focus-297x465.png\"",
  ],
  "components/pages/Collections/Collections.brs": [
    "m.collectionsGrid.itemSize = [465, 348]",
    "m.collectionsGrid.focusBitmapUri = \"pkg:/images/library/thumbnail-focus-465x348.png\"",
  ],
  "components/pages/Music/MusicLibrary/MusicLibrary.xml": [
    "itemSize=\"[360,432]\"",
    "focusBitmapUri=\"pkg:/images/music/music-card-focus-360x432.png\"",
  ],
  "components/pages/Music/MusicAlbumCard/MusicAlbumCard.xml": [
    "translation=\"[9,0]\"",
    "translation=\"[0,1]\" maskUri=\"pkg:/images/masks/fhd/album-mask-342.png\" maskSize=\"[342,342]\"",
  ],
  "components/pages/Music/MusicArtistCard/MusicArtistCard.xml": [
    "<Group translation=\"[9,0]\">",
    "translation=\"[0,1]\" maskUri=\"pkg:/images/masks/fhd/album-mask-342.png\" maskSize=\"[342,342]\"",
    "maskSize=\"[342,342]\"",
  ],
  "components/pages/Music/Artist/Artist.xml": [
    "rowItemSize=\"[[360,399]]\"",
    "focusBitmapUri=\"pkg:/images/music/artist-album-horizontal-focus-360x399.png\"",
  ],
  "components/pages/Music/ArtistAlbumRowItem/ArtistAlbumRowItem.xml": [
    "<Group translation=\"[30,0]\">",
    "maskSize=\"[300,300]\"",
  ],
  "components/pages/Video/TVSeason/TVSeason.xml": [
    "rowItemSize=\"[[576,591]]\"",
    "itemSize=\"[576,591]\"",
  ],
  "components/pages/Video/TVSeason/TVEpisodeCard/TVEpisodeCard.xml": [
    "translation=\"[21,0]\"",
    "<TVEpisodePoster id=\"episodePoster\" translation=\"[0,39]\" />",
  ],
  "components/pages/Video/TVSeason/TVEpisodePoster/TVEpisodePoster.xml": [
    "maskSize=\"[531,300]\"",
  ],
  "components/pages/Video/TVShow/TVShow.xml": [
    "itemSize=\"[207,381]\"",
    "focusBitmapUri=\"pkg:/images/tv-show/season-poster-focus-207x381.png\"",
  ],
  "components/pages/Video/TVShow/TVSeasonCard/TVSeasonCard.xml": [
    "maskSize=\"[207,312]\"",
  ],
};

export function focusAlphaBounds(definition) {
  const [canvasWidth, canvasHeight] = definition.canvas;
  const [x, y, width, height] = definition.image;
  const [left, top, right, bottom] = definition.outline;
  const [anchorLeft, anchorTop, anchorRight, anchorBottom] = definition.anchorCompensation;

  return [
    Math.max(0, x - left + anchorLeft),
    Math.max(0, y - top + anchorTop),
    Math.min(canvasWidth - 1, x + width - 1 + right + anchorRight),
    Math.min(canvasHeight - 1, y + height - 1 + bottom + anchorBottom),
  ];
}

export function scaleInclusiveBounds(bounds, numerator = 2, denominator = 3) {
  return [
    Math.floor((bounds[0] * numerator) / denominator),
    Math.floor((bounds[1] * numerator) / denominator),
    Math.ceil(((bounds[2] + 1) * numerator) / denominator) - 1,
    Math.ceil(((bounds[3] + 1) * numerator) / denominator) - 1,
  ];
}
