# Ghost Song - Offline Trainer v2.0 (in-game menu)

A trainer for **Ghost Song** (Old Moon, GOG / Steam, Windows x64) whose control menu is drawn **inside the game window**
(Dear ImGui on the game's own Direct3D 11 frame) - no separate window any more, so it also works in borderless / fullscreen.

> Tóm tắt tiếng Việt: giải nén -> **tắt game** -> chạy **`Install.bat`** -> vào game, bấm **F10** (hoặc **Insert**) để mở menu trainer
> ngay trong game. Menu có thể chuyển sang **Tiếng Việt** ở mục *Cài đặt (Settings) -> Ngôn ngữ*. Gỡ cài đặt: **`Uninstall.bat`**.

Verified on the retail build **1.2.12b** (`GameAssembly.dll` SHA-256 `43A0C121...D66246`). Single-player only; no anti-cheat or DRM is touched.
No game file is modified: the trainer is a `version.dll` proxy that is loaded next to `GhostSong.exe` and works through the game's own IL2CPP API.

---

## 1. Install (any PC that has the game)

1. **Close the game.**
2. Unzip this package anywhere (Desktop is fine).
3. Double-click **`Install.bat`**.
   * The installer finds the game by itself (GOG registry, Steam libraries, common folders on every drive).
   * If it cannot, it asks for the folder that contains `GhostSong.exe`. You can also run
     `powershell -ExecutionPolicy Bypass -File install.ps1 -GameDir "D:\Games\Ghost Song"`.
4. Start the game the way you always do (GOG Galaxy, Steam or `GhostSong.exe`).
5. Press **F10** (or **Insert**) in the game: the trainer menu opens. Press it again to hide it.

Only **one file** is copied into the game folder: `version.dll` (listed in `GhostSongTrainer_install_manifest.txt`).
Re-running the installer is safe. It also **upgrades a v1.0 trainer** in place (same file name) and removes the stale
`version.dll.orig` copy that old installers left behind. If another mod already uses `version.dll`, it is saved as `version.dll.orig`
and restored by the uninstaller (two `version.dll` proxies cannot run together).

Works together with the **Ghost Song Vietnamese pack** (that one uses `winmm.dll`).

### Uninstall

Close the game and run **`Uninstall.bat`**. Add `-Purge` (`powershell -File uninstall.ps1 -Purge`) to also delete the trainer's log, settings
and self-test files. Saves are never touched by the installer.

---

## 2. Using the menu

Press **F10 / Insert** to open or close the menu. While it is open the game does **not** receive your mouse and keyboard (the cursor is
drawn by the menu); close it to play. Click a checkbox/button, or use the hotkeys below at any time (the hotkeys only react while the
**game window is in the foreground** - they no longer leak to other programs).

| Hotkey | Menu entry | What it does |
|---|---|---|
| **F1** | Player -> God mode | Sets the game's own `charcon.isImmortal` flag and keeps health full. |
| **F2** | Economy -> Add Spirit | Adds *Amount* (editable, default 10000) Spirit and raises the Spirit cap by the same amount, so it stays. Press repeatedly for more. |
| **F3** | Economy -> Infinite Spirit | Cap 99999 and the balance kept full. Switching **off** restores your original cap. |
| **F4** | Player -> Unlimited jump | 99 extra air jumps. Switching off restores the original value. |
| **F5** | Player -> Move speed x2 | Doubles run speed. Switching off puts it back. |
| **F6** | Combat -> One-hit kill | Any enemy that takes damage dies. Bosses with phases may behave oddly - use with care. |
| **F7** | Player -> Heal | Health to maximum. |
| **F8** | Player -> Infinite stamina | Stamina kept at maximum. |
| **F9** | World -> Show all on map | Unlocks every map chunk and redraws the map. |
| **F10 / Insert** | - | Show / hide the menu. |
| **F11** | World -> Give all items | Every item, like the game's own cheat. In the menu you must click **twice** (confirmation). |
| **F12** | Settings -> Write diagnostics | Writes the game state to `gs_trainer.log` (useful for bug reports). |

The top of the menu shows live **HP / Spirit / Stamina**. With the menu closed, a small strip in the top-left corner lists the active cheats
(*Settings -> Show active cheats on screen* turns it off) and a message flashes in the top centre whenever you toggle something.
**Settings** also holds the **language** (English / Tieng Viet), the **UI scale**, and the diagnostics button.
Your choices are remembered in `gs_trainer.ini`; the menu position in `gs_trainer_ui.ini` (both in the game folder).

---

## 3. Good to know

* The trainer works only **inside a running game** (load a save or start a new game). On the title screen the menu says *waiting for a running game*.
* **Add Spirit, Infinite Spirit and Give all items change your save** (they raise caps / item counters, and the game saves them). That is their purpose.
  Make a copy of `%USERPROFILE%\AppData\LocalLow\Old Moon\GhostSong\SaveData` first if you want to be able to go back.
* The menu needs the game to render with **Direct3D 11** (the default). If you force another API (`-force-vulkan`, `-force-d3d12`) the menu cannot appear
  (the log says so); the F-key features still work.
* In **exclusive fullscreen** the menu is drawn too, because it lives in the game's own frame.
* **Other game builds:** the installer warns when `GameAssembly.dll` differs. The trainer checks the code bytes of its 4 hook targets and skips any that do not match
  (speed x2, one-hit kill and the per-frame tick are lost; name-based features and the menu keep working) instead of crashing.
* Antivirus programs sometimes flag any `version.dll` proxy as "DLL hijacking". It is a false positive - the full source is in `source\`. Add the game folder to the exclusions if needed.
* Not compatible with another mod that also ships a `version.dll`.

## 4. Troubleshooting

* Log: `gs_trainer.log` in the game folder. A healthy start looks like:
  ```
  il2cpp runtime ready
  hooks installed: 4/4 (skipped 0)
  overlay: Present hooked at ...
  overlay: ImGui initialised (1280x720, ...)
  ```
* No menu on **F10** and no `overlay:` lines -> the game does not use D3D11, or the installer did not copy `version.dll` (check the game folder).
* `overlay: ... disabled` lines state the reason.
* Open the menu automatically at start (for screenshots/tests): set the environment variable `GS_MENU_AUTOOPEN=1` or create an empty file `trainer_menu_open.flag` in the game folder.
* **Self-test** (optional): create an empty file `trainer_selftest.flag` in the game folder, start the game, wait about 40 s and read `trainer_selftest_report.json`
  (`PASS_READY_FOR_HUMAN` expected; it restores the values it touches). Delete the flag and the report afterwards.

## 5. How it works (for modders)

Ghost Song is **Unity 2020.3.36f1 IL2CPP** (x64, D3D11). `UnityPlayer.dll` imports `VERSION.dll`, so our `version.dll` is loaded first; it forwards all 17 exports to the real
system DLL and starts the trainer in a thread.

* **Game logic** (`source\src\gs_trainer.c`): everything is looked up **by name** through the il2cpp C API exported by `GameAssembly.dll`
  (`status`, `charcon`, `playermovement`, `DamageCalcScript`, `themap`). Four 1-argument MinHook detours: `status.Update` (+0x2CB8F0, captures the singleton),
  `status.LateUpdate` (+0x2BF540, per-frame tick), `playermovement.FixedUpdate` (+0x244C00, speed), `DamageCalcScript.FixedUpdate` (+0x69BF00, one-hit kill).
  The menu and the hotkey thread never touch il2cpp: they flip flags / post requests that are executed on the game thread inside the `LateUpdate` hook.
* **Overlay** (`source\src\gs_overlay.cpp`): a throw-away D3D11 device on a hidden window is created once to read the address of `IDXGISwapChain::Present`
  (vtable slot 8); `Present` is detoured with MinHook. Every frame the hook draws a Dear ImGui frame onto the back buffer and then calls the real `Present`.
  The game window's `WndProc` is subclassed so mouse/keyboard go to ImGui while the menu is open (key-up and `Alt` messages always pass through).
  The shader compiler (`d3dcompiler_47.dll`) is loaded lazily, so a missing DLL can never stop the game from starting.
* **Rebuild:** `cd source` -> `pip install ziglang==0.13.0.post1` -> `python build.py` -> `out\version.dll`. Third-party sources are included in
  `source\third_party` (MinHook, BSD-2-Clause; Dear ImGui v1.91.9, MIT).

## 6. Package contents

```
Install.bat / install.ps1        installer (finds the game, copies version.dll, upgrades v1.0)
Uninstall.bat / uninstall.ps1    removes the trainer again
payload\version.dll              the trainer itself (~660 KB)
source\                          full source, build.py, MinHook + Dear ImGui sources and licences
SHA256SUMS.txt                   hashes of every file in this package
```

Credits: [MinHook](https://github.com/TsudaKageyu/minhook) (BSD-2-Clause), [Dear ImGui](https://github.com/ocornut/imgui) (MIT).
*Ghost Song* belongs to Old Moon; this is an unofficial fan tool that contains no game assets.
