# Runtime Art Style Audit

Reviewed on 2026-09-11 from the seven images in `assets/generated/`.

## Current baseline

The intended direction is an original Western chibi medieval-fantasy look:
large readable silhouettes, rounded bevels, warm upper-left key light, cool
ambient shadow, and two or three broad value planes.

The current runtime images share transparent backgrounds and glossy rounded
forms, but they are not yet a consistent production set:

- The tank, warrior, mage, assassin, and monster use a glossy toy-like render
  with strong specular highlights, but their proportions and material response
  vary noticeably.
- The archer is a silhouette outlier. Its oversized circular bow occupies most
  of the canvas and competes with the character at the intended small display
  size. It should be rebuilt with a compact readable bow and a normal combat
  stance before becoming a runtime style reference.
- The merchant is a cat mascot with a softer costume and different facial
  language. It can remain a special NPC, but it should use the same lighting,
  edge treatment, and value-plane rules as the unit set.
- The source images are 512x512. The runtime pipeline currently displays them
  as static art; do not approve them as the final 96-pixel directional unit
  atlas without silhouette and pivot cleanup.

## Canvas occupancy baseline

The alpha-bound scan uses an alpha threshold of 8/255. All current images are
centered consistently, but the occupied bounding-box area varies from 47.6%
to 76.2% of the canvas:

| Asset | Occupied area | Bounding box |
| --- | ---: | ---: |
| `unit_archer.png` | 76.2% | 455x439 |
| `unit_warrior.png` | 65.4% | 410x418 |
| `wild_monster.png` | 63.8% | 391x428 |
| `unit_tank.png` | 60.7% | 351x453 |
| `unit_assassin.png` | 53.3% | 308x454 |
| `unit_mage.png` | 50.5% | 309x428 |
| `merchant.png` | 47.6% | 343x364 |

The centered pivots are suitable for the current static fallback, but the
archer is materially denser than the other units because of the circular bow.
Canvas normalization alone will not solve that silhouette problem.

## Acceptance gate for new runtime art

Before adding a new generated image to runtime use, review it at 96, 64, and
40 pixels and confirm:

1. The profession or role reads from silhouette without color.
2. The subject occupies a comparable canvas area and has a stable ground pivot.
3. The light comes from the upper left and the shadow remains cool and broad.
4. Materials use broad planes with restrained highlights; no micro-detail is
   required to identify the subject.
5. The image has no text, logo, watermark, cast background, or accidental
   opaque pixels outside the subject.
6. The file stays within the generated-art budget enforced by
   `.tools/audit_art_assets.py`.

## Priority

1. Rebuild the archer silhouette and verify it at 40 pixels.
2. Normalize the unit set's canvas occupancy, pivot, and key-light direction.
3. Revisit the merchant as an NPC exception after the core unit set is stable.
4. Generate directional/action frames only after the neutral masters pass this
   gate; the current static images remain fallback references.
