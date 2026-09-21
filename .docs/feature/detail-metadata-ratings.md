# Detail Metadata Ratings

Movie, TV-show, and episode detail pages show the server's community rating with
an original yellow star icon, without the word "Rating". When Jellyfin supplies
`CriticRating`, the same metadata row also shows a tomato icon and a percentage.
Critic scores are rounded once to a whole percentage. The displayed percentage
and icon use that same normalized value: 60 or higher is fresh, lower is rotten. Zero is a valid critic score. Missing, nonnumeric, negative, and above-100
critic scores are hidden. Community scores keep the existing one-decimal format.

Content classifications such as PG-13 and TV-14 have a white rounded border with
horizontal padding. The label sits one pixel below geometric center to visually
balance the system font inside the border. Runtime has a solid white clock face
with two dark hands.
Both are separate layout elements, without preceding bullets. Other metadata
separators remain unchanged. Missing runtime/classification hides its entire
group; item changes clear prior text and icons. Absent metadata items move to a hidden
container outside the LayoutGroups; visible items return to their row in display
order on each content update. This applies to both movie and episode rows and
prevents missing classifications or scores from reserving width or spacing. Movie runtime and classification
use the primary row, while episode runtime follows its date on the secondary
row. The classification label is capped for unusually long server values.

Pages pass `CommunityRating` and `CriticRating` from their own item metadata to
MediaShell. MediaShell owns the shared icon layout and clears missing scores on
item changes. Movie and TV-show ratings follow primary metadata; episode ratings
follow the date/runtime on the secondary row. Season-summary pages retain their
existing metadata without inheriting an episode's ratings. Empty text or score
groups do not leave placeholder labels. Long metadata leaves room for the scores.

This uses the existing Jellyfin item response; Starfin makes no additional
Rotten Tomatoes or other external-provider requests. The critic field reflects
whatever metadata the server provides, and is not guaranteed to exist for every
title.

`images/icons/ratings/tomato-fresh.png` and `tomato-rotten.png` were copied
unchanged from `C:\dev\jellyfin-roku\images\fresh.png` and `rotten.png` in the local
Jellyfin Roku checkout. The yellow star is an original icon stored as `rating-star.png` and used by
the Roku Poster.

Behavior is covered by MediaMetadata, MediaShell, Movie, TVShow, and TVEpisode
Rooibos suites, including score boundaries, missing data, item transitions, and
which metadata row owns the rating icons, runtime clock, and content badge.

Logo fitting reserves the configured gap before sizing the image. Standard movie
layouts allow at most 190 pixels of logo height above the metadata (230-pixel
anchor minus a 40-pixel gap), preserving aspect ratio for tall and wide logos.
Cinematic movies retain their 220-pixel maximum because more space is available.
Episode logos reserve their existing gap above the episode title.

The primary metadata row uses white text to match the content-rating badge.
The secondary row remains the secondary text color, including runtime and score
text when those elements appear on the episode secondary row. Star and tomato
artwork retain their original colors.

MediaShell separates metadata rendering from row layout. XML owns the row width,
icon sizes, badge padding and maximum text width, and uniform group spacing.
Layout measures visible children using those values and the actual font, then
reserves the remaining width for the metadata text. It recalculates on every
item update, including long-to-short text and changes between primary and
secondary rows. Regression coverage checks the complete row bounds, adjusted
icon/spacing values, and already-loaded logos switching display modes.
