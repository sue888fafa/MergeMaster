# Mobile Art Asset Pipeline

The concept art in `assets/concepts/` is a lighting and material target, not a
runtime sprite source. Crowd units, heroes, buildings, terrain, and UI have
different detail and memory budgets.

## Crowd units

- Five classes, four authored directions, and 96 frames per class.
- Runtime frame size: `96x96`; atlas and faction mask: `1024x1024` each.
- Keep the body neutral and reserve large tabard, shield, shoulder, plume, and
  scarf regions for the faction mask.
- Use a strong outer silhouette and two or three value planes. Details that do
  not survive at 40 pixels should be removed before animation cleanup.
- AI output is reference material. Lock face, weapon length, pivot, light
  direction, and body proportions before packing final frames.

## Heroes, buildings, and UI

- Heroes: `192x192` frames, limited to eight live hero visuals.
- Buildings: `256x256`; headquarters may use `384x384`. Bake lighting, contact
  shadow, ambient occlusion, and surface wear into the diffuse artwork.
- Terrain: reusable `256x256` seamless grass, soil, and rock material swatches;
  tile geometry and state outlines stay procedural.
- UI: lossless nine-slice PNG frames and `96-128` pixel icons. Text remains
  native Godot UI and is never baked into generated images.

## Runtime limits

- Unit source PNG budget: 25 MiB; estimated compressed GPU budget: 16 MiB.
- Crowd visuals share five class materials. Each class is split across eight
  coarse vertical depth buckets, preserving crowd overlap while keeping the
  unit body ceiling at 40 batches.
- Base art and the faction mask are composited in one shader pass. Four shared
  MultiMeshes handle shadows, faction halos, health backgrounds, and health
  fills, for a unit-visual ceiling of 44 batches.
- Near, mid, and far refresh rates are 24, 12, and 8 FPS. Far LOD omits unit
  shadows and health bars.
- No permanent per-unit particles, glow, blur, or unique shader materials.
- MultiMesh capacity is reused between refreshes, and live units are grouped by
  node reference rather than allocating per-unit visual dictionaries.

When runtime atlases are absent, the catalog falls back to the existing static
class images. This keeps the project playable while art production is ongoing,
but the fallback does not provide directional or action animation.
