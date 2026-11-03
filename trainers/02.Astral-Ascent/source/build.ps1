# Rebuild winmm.dll from source (no MSVC needed).  Requires Python:  pip install ziglang==0.13.0.post1
# If Windows is not installed in C:\Windows, first edit winmm.def: replace "C:\Windows\System32\winmm." with your System32 path.
Set-Location $PSScriptRoot
python -m ziglang cc -target x86_64-windows-gnu -shared -O2 -Wall -Wextra -o winmm.dll debugmenu.c winmm.def -luser32 -lgdi32
if ($LASTEXITCODE -eq 0) { Write-Host "built $PSScriptRoot\winmm.dll - copy it over ..\winmm.dll to use it with install.ps1" }
