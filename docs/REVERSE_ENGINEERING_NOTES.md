# Reverse Engineering & Trainer Architecture Notes

Comprehensive documentation of reverse engineering techniques, injection patterns, and runtime architectures implemented across all trainers in the **Drake Trainer** suite.

---

## 1. Engine & Injection Architecture Matrix

| Engine / Runtime | Games | Injection Route | Key Tools Used |
| :--- | :--- | :--- | :--- |
| **Unity Mono** | Shogun Showdown, Bō: Path of the Teal Lotus, 9 Years of Shadows, Ogu & the Secret Forest, Voidwrought | **BepInEx 5.4.23 + HarmonyX** (`winhttp.dll` Doorstop) | ILSpy, dnSpy, MonoMod, HarmonyX, C# |
| **Unity IL2CPP (DX11)** | Ghost Song | **Native Proxy DLL** (`version.dll`) + **MinHook** + **Dear ImGui (DX11)** | Ghidra, Il2CppDumper, MinHook, DirectX 11 SDK |
| **Unreal Engine 4** | Afterimage | **UE4SS Mod Loader** (`dwmapi.dll`) + Custom Lua mod | UE4SS, Lua, Unreal Engine 4 Reflection |
| **Unreal Engine 4 (Native x64)** | Creature in the Well | **Native Proxy DLL** (`xinput1_3.dll`) + MinHook | Ghidra, Capstone, PDB symbol dump, C |
| **Chowdren (Construct-to-C++)** | Astral Ascent | **Native Proxy DLL** (`winmm.dll`) + Function cave hooks | Ghidra MCP, Cheat Engine, C |
| **GameMaker Studio 2 (VM)** | Death's Gambit: Afterlife | **UTMT Bytecode Hook** + **xdelta3** binary delta patch | UndertaleModTool (UTMT CLI), CSX scripts, xdelta3 |
| **HashLink / Heaps** | Dead Cells | **Bytecode Modifier** (HL bytecode structure patcher) | Custom Python bytecode parser & assembler |
| **Java 8 / LWJGL (Packr)** | Gunslugs 1, Gunslugs 2, Gunslugs 3: Rogue Tactics | **URLClassLoader Prepend** (`config.json` classpath override) | CFR decompiler, javac / JDK 8/21, Packr internals |
| **Unity Mono (Direct IL)** | Wizard of Legend | **Mono.Cecil IL Injector** (`GameController.Update` hook) | Mono.Cecil 0.11.5, ILSpy, PowerShell |

---

## 2. In-Depth Injection Methodologies

### 2.1 BepInEx 5 + HarmonyX (`winhttp.dll` Doorstop)
* **Target Games**: *Shogun Showdown*, *Bō: Path of the Teal Lotus*, *9 Years of Shadows*, *Ogu and the Secret Forest*, *Voidwrought*.
* **Mechanism**:
  - The game executable loads Windows `winhttp.dll` dynamically on startup.
  - Placing a custom `winhttp.dll` (Unity Doorstop) in the game root diverts execution to BepInEx before the Mono runtime finishes initialization.
  - HarmonyX applies non-destructive runtime IL detours (Prefixes, Postfixes, and Transpilers) in memory.
  - **Zero modified game files**: uninstalling simply requires removing `winhttp.dll` and `BepInEx/`.

### 2.2 Native Proxy DLLs + MinHook + DirectX 11 ImGui
* **Target Games**: *Ghost Song*, *Astral Ascent*, *Creature in the Well*, *Guacamelee! STCE*.
* **Mechanism**:
  - Hijacks standard system exports (`version.dll`, `winmm.dll`, `xinput1_3.dll`, `dinput8.dll`) using `*.def` export forwarding to `%WINDIR%\System32\*.dll`.
  - Inside `DllMain(DLL_PROCESS_ATTACH)`, a background worker thread initializes hooks via MinHook.
  - In *Ghost Song*, the trainer hooks `IDXGISwapChain::Present` to inject a full **Dear ImGui** overlay, synchronized with the game render loop and mouse/keyboard input.

### 2.3 Packr / ClassLoader Classpath Injection
* **Target Games**: *Gunslugs*, *Gunslugs 2*, *Gunslugs 3: Rogue Tactics*.
* **Mechanism**:
  - The games ship as 64-bit Packr executables packaging a bundled JRE (`jre/bin/server/jvm.dll`) and game assets in `*.dat` files.
  - Packr reads `config.json` to build a `URLClassLoader` from the `"classpath"` (or `"classPath"`) array.
  - By modifying `config.json` to place our custom JAR (`gunslugs-trainer.jar`) ahead of `gunslugs.dat`, Java resolves our patched classes first without altering the executable or original dat file.
  - In *Gunslugs*, native borderless fullscreen window mode was injected to resolve a notorious legacy LWJGL 2 desktop resolution crash on Windows 10/11.

### 2.4 GameMaker Studio 2 VM & xdelta3
* **Target Games**: *Death's Gambit: Afterlife*.
* **Mechanism**:
  - UTMT CLI executed automated CSX scripts against `data.win`, inserting trainer hotkeys and global stat clamps directly into `scr_player_jump`, `obj_unit_parent`, and `GlobalVariables Step_0`.
  - The resulting modified binary was converted into a compact ~1 MB `xdelta3` patch.
  - The portable installer automatically verifies SHA-256 hashes of the target file, creates a `.VANILLA` backup, and applies the delta patch with 100% byte verification.

### 2.5 HashLink Bytecode Patching
* **Target Games**: *Dead Cells*.
* **Mechanism**:
  - Dead Cells uses Shiro Games' HashLink virtual machine.
  - Python-based bytecode scanning locates opcode sequences for gold reduction, cell consumption, and invulnerability timers, replacing decrements with no-ops or additions.

---

## 3. Coexistence & Reliability Principles

1. **Safety First**: All trainers feature automatic backups of vanilla files (`.VANILLA` extension) and verified uninstallation scripts.
2. **Translation Compatibility**: Dual-loader architectures ensure trainers run concurrently with Vietnamese translation packs (e.g., UE4SS coexistence for *Afterimage*, BepInEx coexistence for *Voidwrought* and *Bō*).
3. **No External Dependencies**: Portable packages require zero installed runtimes (Python, Java, or .NET SDKs are not required by end-users; scripts are pure PowerShell/Batch with bundled pre-compiled DLLs/JARs).
