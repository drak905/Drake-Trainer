@echo off
rem Rebuild dinput8.dll (32-bit) with Zig's bundled clang - no Visual Studio needed.
rem   python -m pip install ziglang==0.13.0.post1
set MH=%~dp0minhook
python -m ziglang cc -target x86-windows-gnu -shared -O2 -Wall -Wextra -Wno-unused-parameter -Wno-missing-field-initializers -Wno-cast-function-type -o dinput8.dll guac_trainer.c %MH%\src\hook.c %MH%\src\buffer.c %MH%\src\trampoline.c %MH%\src\hde\hde32.c -I%MH%\include -luser32 -lkernel32 dinput8.def
