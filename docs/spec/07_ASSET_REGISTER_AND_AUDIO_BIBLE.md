# 07 — Asset Register and Audio Bible

## 1. Asset policy
Free/open-source only, prioritize CC0. “Free download” does not mean unrestricted use. Every imported asset must have a source URL, author, license, retrieval date, attribution requirement, modification notes and evidence of permission. Do not ship assets with unclear terms.

## 2. Candidate asset sources (verify each individual asset)
| Source | Potential use | Required checks |
|---|---|---|
| Kenney — https://kenney.nl/assets | UI, props, prototypes, icons, environments | Confirm each pack license and fit |
| OpenGameArt — https://opengameart.org | Pixel art, tiles, music, effects | Per-asset license and attribution |
| itch.io asset packs — https://itch.io/game-assets | Pixel characters, tilesets, UI | Per-pack license; free does not imply CC0 |
| LibreSprite — https://libresprite.github.io | Pixel-art editing | Software license and export workflow |
| Tiled — https://www.mapeditor.org | Tilemap authoring | Tool license; also track asset licenses |
| Freesound — https://freesound.org | Sound effects/ambience | Per-file CC0/CC-BY and attribution |
| Open Font Library — https://openfontlibrary.org | Fonts | Per-font license and embedding rights |

## 3. Asset register fields
`asset_id`, `filename`, `category`, `creator`, `source_url`, `license_spdx`, `license_text_url`, `attribution_text`, `commercial_use_allowed`, `modification_allowed`, `retrieved_at`, `modified`, `review_status`, `release_usage`.

Block release if any shipped asset has `unknown` or `unreviewed` license status.

## 4. Original asset list
- Player sprites: 8-way movement, idle, walk, interact, inspect, celebrate.
- Main cast: portraits, overworld sprites, dialogue expressions.
- District tilesets: exterior/interior, roads, sidewalks, storefronts, industrial, hospital, school, studio, office.
- UI: panels, buttons, tabs, icons, map markers, evidence cards, alert states, controller glyphs.
- Cyber artifacts: fictional workstation, router, server rack, badge reader, camera, terminal, dashboard.
- Effects: rain, steam, streetlight glow, subtle UI pulses, alert transition.
- Portraits and signage: original, licensed, culturally reviewed.

## 5. Audio direction
Blend original instrumental hip-hop, soulful electronic textures, boom-bap percussion, atmospheric synths and regional city ambience. Do not imitate a living artist or use uncleared samples. Commission original music or use verified permissive licenses.

Audio zones:
- Main menu: confident, reflective, forward-looking theme.
- The Block: warm neighborhood ambience, distant traffic and community activity.
- Switchboard HQ: low electronic pulse, keyboard textures, restrained alert sounds.
- Market Row: storefront ambience and rhythmic percussion.
- Meridian Medical: calm, restrained, minimal soundscape.
- Ironworks: industrial ambience, low mechanical rhythms.
- Cloud Nine: airy digital textures.
- The Undergrid: tense but not horror-heavy.
- Mission complete: short musical resolution, not arcade overload.

## 6. Audio accessibility
Subtitles/captions for meaningful cues, independent music/SFX/ambience volume, mute options, no critical information conveyed by sound alone.
