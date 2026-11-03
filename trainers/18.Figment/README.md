# Figment — plug-and-play Cheat Engine trainer

**Architecture:** Unity + Mono. The table resolves the current player and camera
from Mono metadata and static singleton slots. It does not contain saved heap
addresses and does not perform memory or Mono heap scans.

## Quick start

1. Start **Figment** and enter a level.
2. Open Cheat Engine and attach it to `Figment.exe`.
3. Load `Figment.CT`.
4. Check **Figment Trainer - Activate**.

No MCP bridge or AI connection is required. Activating the script creates three
editable child entries:

- **Camera Zoom-Out Addition** — `2.663460255` (`0.28125` is stock)
- **Character Speed Multiplier** — `2.0` (`1.0` is stock)
- **No Damage** — Enabled/Disabled

Unchecking the main activation entry stops the keeper and restores stock camera,
speed, and damage settings where the current scene objects are available.

## Scene transitions

Figment recreates or replaces managed objects during scene/save transitions.
Freezing old addresses therefore does not work. The table runs a lightweight
keeper every **3000 ms** that follows these fixed static roots:

```text
PlayerManager.instance + 0x98 -> AnimatorParameterWrapper
PlayerManager.instance + 0x58 -> PlayerHealth
CameraManager.instance + 0x28 -> CameraController
```

The keeper performs only pointer reads, field reads, and calls to methods resolved
from the concrete live wrapper instance. It never invokes methods obtained from
the open generic ``AnimatorParameterWrapper`1`` definition. It may take up to three
seconds for settings to reapply after a scene change.

## Known fields

| Class | Field | Offset | Type |
|---|---|---:|---|
| `CameraController` | `orthographicSizeAddition` | `0xBC` | float |
| `PlayerHealth` | `isInvulnerable` | `0x100` | byte/bool |
| `PlayerHealth` | `health` | `0x10C` | int32 |
| `PlayerHealth` | `maxHealth` | `0xD8` | int32 |

Movement is applied through
`AnimatorParameterWrapper<PlayerAnimatorParameter>.SetFloat(1, value)`, where
enum index `1` is `LocomotionSpeedMultiplier`.

## Safety

- Single-player use only.
- Attach to the game before activating the table.
- Deactivate the trainer before switching to another target process.
- Cheat Engine → Settings → Extra → disable **Query memory region routines**.

The table is self-contained; paths can be moved or renamed.
