# Unit Visual Performance Baseline

Recorded on 2026-09-11 with Godot 4.7.2, GL Compatibility project settings,
and the current legacy static unit images. These desktop results validate the
test fixtures and establish a regression baseline; they do not prove the
30 FPS target on a 4 GB Android device.

## Visual-only stress test

Command:

```powershell
E:\godot\godot.exe --headless --path E:\demo-zhancheng tests/UnitVisualStressTest.tscn
```

| Zoom | Units | Average FPS | Active unit batches | Batch budget | Static memory |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 0.50 | 600 | 107.2 | 41 | 44 | 72.5 MiB |
| 1.02 | 600 | 143.2 | 44 | 44 | 72.5 MiB |
| 1.20 | 600 | 144.6 | 44 | 44 | 72.5 MiB |

The headless renderer reports zero measured draw calls because it uses the
dummy rendering backend. `active unit batches` is the live MultiMesh count;
the design ceiling is 5 classes x 8 depth buckets plus four shared decoration
batches. Verify actual scene draw calls with the Godot profiler on device.

## Simulation stress test

Command:

```powershell
E:\godot\godot.exe --headless --path E:\demo-zhancheng tests/UnitSimulationStressTest.tscn
```

| Target/live units | Average FPS | Average process monitor | Static memory |
| ---: | ---: | ---: | ---: |
| 400 / 400 | 134.5 | 18.46 ms | 71.9 MiB |
| 600 / 600 | 103.1 | 20.36 ms | 73.3 MiB |

The fixture pauses match-result and AI-controller frame callbacks, sets test
unit damage and movement speed to zero, and keeps unit `_process`, target
refresh, target validation, and combat branching active. This prevents deaths,
captures, and faction elimination from changing the sample count.

## GL capture and Android export

- GL Compatibility captures were validated at 720x1280 for zoom 0.50, 1.02,
  and 1.20 under `tests/output/`.
- Base sprites, shared shadows, faction halos, and conditional health bars were
  visible in all three captures.
- Android debug export completed and signed successfully. Temporary APK size:
  62,751,591 bytes. The temporary APK was removed after validation; the existing
  project APK was not overwritten.
- Export warnings: no application icon configured and Target SDK build tools
  fell back to installed version 35.0.1.

## Required device pass

Profile 400 and 600 live units at all three zoom levels on the actual minimum
4 GB Android target. Record average and one-percent-low FPS, process time,
render time, total scene draw calls, static memory, and thermal state. If the
simulation thread exceeds budget before the unit textures do, optimize target
search and unit scheduling without reducing the approved 96-pixel sprite
clarity.

