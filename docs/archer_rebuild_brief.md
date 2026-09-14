# Archer Rebuild Brief

Status: candidate brief, not yet a runtime replacement.

## Goal

Replace the current archer fallback image with a compact neutral-faction
chibi archer whose profession reads at 40 pixels and whose silhouette belongs
to the existing rounded Western medieval-fantasy unit family.

## Visual specification

- One original chibi medieval archer, full body, centered on a transparent
  square canvas.
- Use a compact recurved bow held beside the body; the bow must not form a ring
  around or behind the character.
- Use the same approximate body scale as the warrior and tank, with a stable
  ground pivot near the bottom of the canvas.
- Use broad painted planes, rounded bevels, restrained glossy highlights, warm
  upper-left key light, and cool lower-right ambient shadow.
- Keep the palette in muted green cloth, warm wood, neutral leather, and soft
  steel. Avoid a faction-specific red, purple, or blue costume.
- Preserve clear separation between hood, face, bow, quiver, hands, and boots.

## Hard constraints

- Transparent background; no text, logo, watermark, floor, or cast shadow.
- No circular bow, oversized prop, loose ribbons, thin detail, or perspective
  distortion.
- Do not overwrite `assets/generated/unit_archer.png` until review is complete.
- Candidate target is `assets/generated/unit_archer_candidate_v2.png`.
- Keep the candidate at 512x512 and under 512 KiB, then inspect it at 96, 64,
  and 40 pixels before runtime approval.

## Review checklist

1. The archer is recognizable without color.
2. The bow reads as a weapon at 40 pixels without dominating the character.
3. The occupied canvas area is comparable to the other combat units.
4. The lighting direction and material response match the unit style audit.
5. Transparent edges are clean and the ground pivot is stable.
6. The asset audit passes in strict mode.
