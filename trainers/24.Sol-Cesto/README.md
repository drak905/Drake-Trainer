# Sol Cesto — trainer toolkit

**Architecture: Construct 3 (HTML5/JavaScript) running inside WebView2.**
Values are reached through the **Chrome DevTools Protocol**, by name — not by
memory address.

---

## Why this game needs a browser approach

`SolCesto.exe` is only a ~620 KB host shell. The evidence, from its module list:

- `scirra-filesystem-x64.ext.dll` — Scirra is the Construct engine vendor
- `WebView2Loader.dll`, `WV2ExtManager.dll`, `EmbeddedBrowserWebView.dll`
- `EOSSDK-Win64-Shipping.dll` — Epic Online Services

The game logic lives in a **WebView2 renderer process** (`msedgewebview2.exe`),
and within that, Construct runs its runtime inside a **Web Worker**
(`workermain.js`). So:

- Attaching Cheat Engine to `SolCesto.exe` finds nothing useful.
- Even in the renderer, the runtime is **not** on `window` — it is in ES-module
  scope inside a worker.

Memory scanning does work but is painful: V8 uses **pointer compression**, so a
small integer is stored as `value << 1` in 32 bits (gold of 111 reads as raw
`222`). Worse, addresses are session-scoped. `SolCesto_stats.CT` documents that
route but you should prefer the CDP route below.

---

## Quick start

**Everything in one step — double-click `PlaySolCesto.bat`.**

It sets the debug port for that launch only, starts the game, waits for the port,
then runs the trainer in enforcement mode. Leave the console window open while
you play; closing it stops enforcement.

If the game is **already running with the port open**, use `StartTrainer.bat`.

Manual equivalent:

```powershell
$env:WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS="--remote-debugging-port=9222"
& "E:\EpicGames\SolCesto\SolCesto.exe"
python solcesto_trainer.py
```

Requires **Python 3.10+**. No pip installs — the CDP/WebSocket client is
implemented from scratch in `solcesto_cdp.py`.

---

## Files

| File | Purpose |
|---|---|
| `PlaySolCesto.bat` / `.ps1` | Launch game with debug port + start trainer |
| `StartTrainer.bat` | Trainer only (game already running) |
| `solcesto_trainer.py` | **Main tool.** Continuously enforces your loadout |
| `c3vars.py` | Read/write any Construct value by name (CLI) |
| `solcesto_cdp.py` | Zero-dependency CDP + WebSocket client |
| `stash_runtime.py` | Pins the Construct runtime (used by the trainer) |
| `worker_eval.py` | Run JS inside the runtime Web Worker |
| `meta_backup.json` | Backup of the meta-progression save arrays |
| `SolCesto_stats.CT` | Memory-based table (session-only; superseded) |
| `probe_*.js`, `debug_worker.py`, `pause_inspect.py`, `show_acquis.py`, `unlock_stars.js`, `verify_cells.js`, `arr.json` | Diagnostic scratch from the reverse-engineering session; kept for reference |

---

## Usage

```powershell
python solcesto_trainer.py            # enforce loadout (leave running)
python solcesto_trainer.py --show     # read current values
python solcesto_trainer.py --once     # apply once and exit

python c3vars.py list                 # all 94 global variables
python c3vars.py get porte_Requis
python c3vars.py set coffrePieces_multi 10
python c3vars.py inst heros            # hero stats with names
python c3vars.py setinst heros 0 vie 100
python c3vars.py find 42               # locate a value across all instances
```

Edit the loadout at the top of `solcesto_trainer.py`:

```python
ENFORCE_VARS = {
    "vie": 100, "vieMax": 100,
    "pouvoir_force": 10, "pouvoir_magie": 10,
    "capacite_seuilMax": 1, "or_multiplicateur": 100,
    "inventaireMax": 6, "bouclierActif": 100,
}
```

---

## Known values

Hero instance variables (`heros` object, French names):

| Name | Meaning |
|---|---|
| `vie` / `vieMax` | HP / max HP |
| `or` | Gold |
| `or_multiplicateur` | Gold multiplier (multiplies pickup value) |
| `pouvoir_force` / `pouvoir_magie` | Attack / magic attack |
| `pouvoir_BONUS` | Bonus power |
| `actions` | Action counter (counts toward `porte_Requis`) |
| `capacite_seuilActuel` / `capacite_seuilMax` | Special skill charge / threshold |
| `capacite`, `capa` | Capacity level / ability name |
| `inventaireMax`, `inventaire1..6` | Inventory size / slot contents |
| `bouclierActif`, `poison`, `rez`, `soinMult` | Shield, poison, revives, heal multiplier |
| `attirance_*` | Attraction to chests / heals / monsters / spikes |

Useful globals (94 total, see `c3vars.py list`):

| Name | Meaning |
|---|---|
| `porte_Requis` | Door requirement (template; live door also has its own) |
| `coffrePieces_multi` | Chest coin multiplier |
| `Prix_multiplicateur` | Shop price multiplier |
| `Gemme_chanceApparitionGemme` | Gem spawn chance (%) |
| `EtageActuel` / `BiomeActuel` | Current floor / biome |
| `heros_nom` | Selected character |

---

## Gotchas learned the hard way

**Don't write `actions`.** The exit door opens on a *trigger* — the game compares
`actions` to `Porte.requis` at the moment you act. Writing the value satisfies
the comparison but never fires the check, so the door stays shut, and
re-running the trainer wipes real progress. `PER_RUN_VARS` is intentionally
empty for this reason.

**Gate tampering is removed.** `ENFORCE_GLOBALS` / `ENFORCE_OBJECTS` are empty
by design. Lowering the requirement needs *both* the global `porte_Requis` and
the live `Porte` object's own `requis` field, because the global is only the
template used when a door is created.

**Enforcement, not one-shot writes.** Construct sets hero stats a moment *after*
creating the instance and resets them on new runs, so a single write loses the
race. The trainer re-asserts every second.

**Hero UID is reused** (always 20), so "new run" cannot be detected by UID.

**Meta-progression is already saved.** All 85 unlocks — every star upgrade, all
7 characters, all 10 talents — are written into the game's own save and need no
re-running. `meta_backup.json` is the safety copy.

---

## Reverse-engineering notes (for agents)

The path to reaching the runtime, since the obvious routes all fail:

1. Attach to the **renderer** process, not the host exe.
2. Worker targets refuse direct `/devtools/page/<id>` connections. You must
   attach to the **page** target, then call `Target.setAutoAttach` with
   `flatten: true` on that session — that surfaces `workermain.js`.
3. The runtime object is not on `globalThis` (ES-module scope). A bounded
   3,560-step object-graph walk finds nothing.
4. **Solution:** `Debugger.pause` the worker and read `Debugger.paused` →
   `callFrames[].scopeChain`. Frame `Step_RunEventsEtc` has a local
   `C3.EventSheetManager`; frame `Tick`'s `this` is the runtime. Assign both onto
   `globalThis` *while still paused* so they survive the resume. Every later call
   is then a plain `Runtime.evaluate`.

That is what `stash_runtime.py` automates.
