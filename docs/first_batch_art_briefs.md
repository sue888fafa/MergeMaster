# First-Batch Art Briefs

These images are production references, not final sprite sheets. Generate each
asset separately at high resolution, then perform animation cleanup, pivot
alignment, faction-mask painting, and atlas packing offline.

The shared target is an original Western chibi medieval-fantasy look with the
same material hierarchy as `assets/concepts/medieval_hex_battle_ui_concept_v1_master.png`:
large readable forms, warm upper-left key light, cool ambient shadow, rounded
bevels, restrained edge wear, and two or three value planes. Do not reproduce
characters, logos, buildings, or UI from any existing commercial game.

## Crowd warrior turnaround

Use case: stylized-concept
Asset type: crowd-unit orthographic turnaround reference
Primary request: an original neutral-faction chibi medieval sword warrior for a mobile strategy game
Subject: one 2.7-head-tall warrior with a broad chest, large gloved hands, short straight sword, compact kite shield, simple breastplate, large shoulder plates, cloth tabard, sturdy boots, and a friendly determined face
Composition/framing: four separate full-body views in one clean reference board, down/front, left, right, and up/back; identical proportions, equipment dimensions, stance, and foot pivot in every view; generous separation between views
Lighting/mood: warm upper-left key light and cool lower-right ambient shadow, readable rather than dramatic
Color palette: neutral steel, warm leather, muted cream cloth; reserve tabard, shield face, shoulder inset, and helmet plume as plain mid-value faction-color zones
Materials/textures: broad painted metal, leather, and cloth planes; very limited scratches; no detail smaller than four pixels at a 96-pixel frame
Constraints: transparent background, no cast shadow, no text, no logo, no watermark; strong sword-and-shield silhouette at 40-pixel display height; no perspective camera; all four views use matching orthographic scale
Avoid: thin chain mail, individual hair strands, tiny buckles, hanging ribbons, reflective glitter, realistic anatomy, toy-like candy plastic, flat vector outlines

## Crowd archer turnaround

Use case: stylized-concept
Asset type: crowd-unit orthographic turnaround reference
Primary request: an original neutral-faction chibi medieval archer for a mobile strategy game
Subject: one 2.7-head-tall archer with a large recurved bow, compact quiver, leather bracers, short hooded mantle, simple tunic, sturdy boots, and an alert friendly face
Composition/framing: four separate full-body views in one clean reference board, down/front, left, right, and up/back; identical proportions, bow length, quiver placement, stance, and foot pivot in every view; generous separation between views
Lighting/mood: warm upper-left key light and cool lower-right ambient shadow, readable rather than dramatic
Color palette: warm wood, neutral leather, muted cream cloth; reserve hood mantle, chest sash, bracers, and quiver badge as plain mid-value faction-color zones
Materials/textures: broad wood, leather, and cloth planes; bow remains thick enough to read at 40 pixels; very limited wear
Constraints: transparent background, no cast shadow, no text, no logo, no watermark; unmistakable bow silhouette at 40-pixel display height; no perspective camera; all views use matching orthographic scale
Avoid: thin bow string as the only action cue, loose hair strands, feather micro-detail, dangling straps, realistic anatomy, toy-like candy plastic, flat vector outlines

## Level-one barracks concept

Use case: stylized-concept
Asset type: isometric mobile-game building concept
Primary request: an original compact level-one medieval barracks for a bright chibi strategy game
Subject: a squat one-story stone-and-timber barracks with a blue-neutral tiled roof, broad wooden door, tiny training dummy, weapon rack, short banner pole, and one reinforced corner tower base that can visually grow in later upgrade levels
Composition/framing: isolated three-quarter isometric view, full building visible, centered on a transparent canvas, footprint readable inside one hex tile, door facing lower-right
Lighting/mood: warm upper-left sunlight, cool right-side ambient shadow, baked contact shadow and ambient occlusion
Color palette: pale limestone, honey-brown timber, restrained blue-gray roof, dark iron fasteners; banner cloth is a neutral mid-value faction-color zone
Materials/textures: chunky stone blocks, broad timber grain, thick roof tiles, rounded metal bevels, restrained edge wear; detail must survive a 256-pixel runtime image
Constraints: transparent background except one soft baked contact shadow, no terrain base, no text, no logo, no watermark, no characters, clear upgrade silhouette hooks
Avoid: cathedral scale, dense roof shingles, tiny props, ultra-realistic stone, candy plastic, flat vector rendering, dramatic dark lighting

## Production checks

- Review each crowd unit at 96, 64, and 40 pixels before approving the master.
- Confirm profession recognition with all color removed; faction color must not be
  required to distinguish warrior from archer.
- Paint masks only after the neutral master is locked. White mask value carries
  material shading; transparent pixels do not tint.
- Keep all 96 action frames on one fixed source canvas with a stable foot pivot.
- Never accept a generated sprite sheet as final. Correct face, hands, weapon
  length, silhouette, orthographic consistency, lighting, and transparent edges
  before running `.tools/build_unit_atlas.py`.
