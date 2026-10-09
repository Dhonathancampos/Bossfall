@echo off
REM Duplo clique aqui para rodar os testes.
cd /d "%~dp0"
"C:\Godot\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe" --headless --path . --script res://tests/run_tests.gd
pause
