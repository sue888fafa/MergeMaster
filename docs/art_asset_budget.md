# Art Asset Budget

This project treats concept art and runtime art as different asset classes.
Concept images are visual references and are not loaded by the game. The
`assets/concepts/.gdignore` marker keeps them out of Godot imports and exports.
Runtime images must be sized for their actual display use and should not retain
unused working-resolution pixels.

Run the inventory audit from the project root:

```powershell
python .tools/audit_art_assets.py
```

The report separates repository art from the estimated Godot package art, so
large ignored concept references do not get confused with runtime payload.

The Android export preset also excludes `tests/*`. Test scenes, scripts, and
the roughly 2 MiB of captured screenshots remain available for local
performance checks but are not release package content.

An Android debug export was verified on 2026-09-11 as
`output/HexDominion-art-audit.apk` at 56.27 MiB. APK contents contained the
runtime generated-art import records but no `tests/` files, test screenshots,
or concept references. This is a package regression baseline, not a release
build-size guarantee; verify again after adding new assets.

The follow-up export `output/HexDominion-art-audit-v2.apk` is 56.25 MiB after
excluding the unused `assets/cartoon-shield.svg`; its generated `.ctex` is also
absent from the APK. The repository source remains intact for reference.
The APK contains 27 imported texture files totaling 1.006 MiB; the remaining
package size is engine, native library, script, and Android runtime overhead.

After adding the five static faction masks, the verified package
`output/HexDominion-faction-mask-audit.apk` is 56.36 MiB. The five mask
textures add roughly 0.11 MiB to the APK and remain below the 60 MiB review
ceiling.

Run the release package check with:

```powershell
powershell -ExecutionPolicy Bypass -File .\validate_android_art_pack.ps1
```

The default review ceiling is 60 MiB. Pass another APK path as the first
argument when checking a new export.

Use `--strict` in a release check. The default mode reports review warnings
without blocking development while existing reference images are still being
used.

## Review thresholds

| Asset group | Review threshold | Reason |
| --- | ---: | --- |
| `assets/generated/` file size | 512 KiB | Generated unit art should be compact before runtime import. |
| `assets/generated/` maximum dimension | 512 px | Current static unit sources are 512x512; larger files need a specific reason. |
| `assets/concepts/` file size | 2 MiB | Concept art is not runtime art, but oversized references still inflate the project. |
| `assets/concepts/` export status | excluded | Concept references stay in the repository for review but are not package content. |
| Crowd runtime base/mask atlases | 25 MiB total source | Enforced by `validate_art_budget.py`. |
| Crowd runtime GPU estimate | 16 MiB | Enforced by `validate_art_budget.py`. |

When a threshold is exceeded, first confirm whether the file is a source,
reference, or runtime asset. Do not reduce a concept image and then use it as a
sprite. For runtime images, preserve transparent edges and silhouette clarity
at the documented display size before choosing PNG optimization or a smaller
source canvas.
