Astral Ascent - in-game trainer (portable patch v1)
====================================================
For the OFFLINE, SINGLE-PLAYER game only. It does not touch anti-cheat or online features (the game has none
that matter here), and it does not modify Astral Ascent.exe, Assets.dat or your save files.

Tested on: Astral Ascent 2.7.1, Epic Games build, Windows 11, x64.
Needs:     Windows installed in C:\Windows (the DLL forwards to C:\Windows\System32\winmm.dll).

INSTALL
  1. Close the game completely (check Task Manager for "Astral Ascent.exe").
  2. Double-click Install.bat   (or: powershell -ExecutionPolicy Bypass -File install.ps1 -GameDir "D:\path\to\game").
     It finds the Epic install folder automatically, checks the exe version, backs up any existing winmm.dll
     and copies winmm.dll into the game folder.
  3. Start the game from the Epic Games launcher (starting the exe directly makes it exit immediately - Epic
     Online Services needs the launcher). Load your save, then press F10.

WHAT YOU GET (F10 panel; F10 again hides it; keep the game in windowed/borderless mode)
  - God mode              HP is locked at max
  - Infinite mana
  - Unlimited jump        unlimited air jumps
  - One-hit kill          damage x~1000 (the "dmg N" counter in the panel rises on every hit)
  - Currencies            +1000 all / set all to 99999 / infinite currency (pins the 6 currencies)
  - Max HP setter, Heal full
  - Editor for 123 numeric game variables (filter, set, lock)

CHECK THAT IT LOADED
  Open <game folder>\aa_debugmenu.log. A good start-up shows:
     game object verified
     hooks: 5/5 call sites patched
  If it says "signature mismatch" or "site ... skipped" your game build differs; the trainer disables the
  affected part instead of crashing.  Optional self-test: create an empty file trainer_selftest.flag in the game
  folder, start the game once and read trainer_selftest_report.json (delete the flag afterwards).

UNINSTALL
  Close the game, run Uninstall.bat (removes winmm.dll, restores any previous one, deletes the log/report files).
  Epic's "Verify" does not remove it by itself but may flag the extra file.

KNOWN ISSUES
  - Pinned currency (99999) and any value you set are written into your save. Back up
    "%USERPROFILE%\Saved Games\Astral Ascent" first.
  - After a local save change Epic may show a cloud-sync conflict dialog on the next launch; that choice is yours.
  - On some machines the game process lingers after closing the window (GPU driver stall, seen with Intel Iris Xe);
    end it in Task Manager before reinstalling/uninstalling.
  - God mode refills HP every ~4 ms: a single hit larger than your max HP or an instant-death hazard can still kill.
  - One-hit kill vs bosses has not been verified.

FILES
  winmm.dll        the trainer (proxy DLL; forwards all real winmm functions)
  install.ps1 / uninstall.ps1 / *.bat
  source\          debugmenu.c, globals_table.h, winmm.def, build.ps1 (rebuild without Visual Studio)
  SHA256SUMS.txt   checksums of the files in this package
