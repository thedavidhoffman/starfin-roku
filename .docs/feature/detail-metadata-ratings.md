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

`MediaMetadataRow` owns rendering and layout for leading text, the runtime clock,
classification badge, star score, and tomato score. It clears missing values on
item changes. Formatting and rating normalization helpers remain in
`MediaMetadata`.

Pages pass `CommunityRating` and `CriticRating` from their own item metadata to
MediaShell. MediaShell supplies values to two `MediaMetadataRow` instances and
chooses their placement. Movie and TV-show ratings follow primary metadata; episode ratings
follow the date/runtime on the secondary row. Season-summary pages retain their
existing metadata without inheriting an episode's ratings. Empty text or score
groups do not leave placeholder labels. Long metadata leaves room for the scores.

Detailed library cards use the same component, supplying the year, formatted
runtime, classification, and review scores from their item. Custom `metadataText`
continues to use the card's plain-text label instead. `showMetadata` controls
visibility for either presentation.

This uses the existing Jellyfin item response; Starfin makes no additional
Rotten Tomatoes or other external-provider requests. The critic field reflects
whatever metadata the server provides, and is not guaranteed to exist for every
title.

`images/icons/ratings/tomato-fresh.png` and `tomato-rotten.png` were copied
unchanged from `C:\dev\jellyfin-roku\images\fresh.png` and `rotten.png` in the local
Jellyfin Roku checkout. The yellow star is an original icon stored as `rating-star.png` and used by
the Roku Poster.

Behavior has test coverage in the MediaMetadata, MediaMetadataRow,
VideoDetailedCard, MediaShell, Movie, TVShow, and TVEpisode
Rooibos suites, including score boundaries, missing data, item transitions, and
which metadata row owns the rating icons, runtime clock, and content badge.

Logo fitting reserves the configured gap before sizing the image. Standard movie
layouts allow at most 190 pixels of logo height above the metadata (230-pixel
anchor minus a 40-pixel gap), preserving aspect ratio for tall and wide logos.
Cinematic movies retain their 220-pixel maximum because more space is available.
Episode logos reserve their existing gap above the episode title.

MediaMetadataRow always uses white text for leading text, runtime, classification,
and review scores, including detailed library cards and both media-shell rows.
There is no caller-specific text-color override. Star and tomato artwork retain
their original colors.

MediaMetadataRow's XML defines fonts, icon sizes, badge padding and maximum text
width, and group spacing. Callers supply the available width and fitting policy.
The component measures visible children using the actual font. In MediaShell,
it reserves space for trailing groups and limits leading text to the remaining
width. Rendering and layout recalculate when input fields change, including
long-to-short content updates. MediaShell continues to own logo fitting and
placement of the primary and secondary rows.

Detailed library cards opt into uniform scale-to-fit for their 516-pixel metadata
row. Overflowing rows scale text, icons, badges, and gaps together, retaining all
metadata, left alignment, and vertical centering. Rows that fit remain at natural
size; content and width changes recalculate the scale. MediaShell keeps its
existing layout behavior.
