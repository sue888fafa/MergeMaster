# Crowd Unit Runtime Atlases

Each unit class may provide two `1024x1024` PNG files:

- `<class>_base.png`: neutral-color RGBA artwork.
- `<class>_mask.png`: white RGBA faction-color regions with transparent non-team regions.

The current art set uses a six-direction static layout. The first six `96x96`
cells in the top row are selected by the runtime movement mapping. In atlas-cell
order they correspond to the logical movement vectors down-right, up-right,
left, up-left, down-left, and right; all remaining cells are transparent. These
frames are selected from movement direction and are not animation frames.

Legacy animated atlases may still use all 96 cells of `96x96` pixels in the
10-column grid. Their frame order is
`down`, `left`, `right`, `up`; inside each direction the order is `idle` (4),
`move` (6), `attack` (6), `hit` (2), `death` (6). The unused final four cells
remain transparent.

Source frames use `<direction>_<animation>_<two-digit-index>.png`. All 96 base
frames must share one canvas size and one foot pivot. The packer calculates one
union crop across the full animation set, so animation silhouettes do not bob
from frame-by-frame trimming. Pack base and mask together to guarantee exact
registration:

```powershell
python .tools/build_unit_atlas.py path/to/base_frames assets/units/runtime/warrior_base.png --mask-source path/to/mask_frames --mask-destination assets/units/runtime/warrior_mask.png
```

Install the offline art-tool dependency into the active Python environment with
`python -m pip install -r .tools/requirements-art.txt`. This dependency is only
used by the atlas packer and is not shipped in the Godot runtime.

Godot import settings: VRAM Compressed, ETC2/ASTC enabled, mipmaps enabled,
alpha border fixing enabled, and no per-instance material duplication.

Do not divide the 1024-pixel sheet into ten equal UV cells: the runtime shader
uses an explicit `96 / 1024` frame step and leaves the final 64-pixel gutter
unused.
