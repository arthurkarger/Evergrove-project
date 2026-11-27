# Evergrove 0.6.7 — Desktop support

Windows 10/11 x64 build: GitHub Actions → Windows Desktop → artifact Evergrove-Windows-x64. Extract the entire ZIP and keep Evergrove.pck beside Evergrove.exe. The executable is not Authenticode-signed.

- WASD or arrows: movement; Shift: run.
- E, Space or left-click in the world: use the current contextual target/tool (proximity rules preserved).
- I/Tab: inventory; 1–6 or mouse wheel: hotbar; B: construction; C: crafting.
- Construction: left click a tile, drag to pan, R to rotate, Enter to confirm a valid placement, Delete to remove the selected object.
- Esc: back/pause; F11: fullscreen.
- Settings: window resolution, FPS limit, VSync and fullscreen; stored separately in desktop.cfg. Window resolution is applied in windowed mode.
- Touch-only controls hidden on desktop. Android export, save format, package and signature remain intact. Saves are local to each device, not synchronized.

The Windows workflow runs existing headless regression tests, a desktop keyboard/preferences test, exports the game with the same Blender generation pipeline, and starts the exported binary headlessly on Windows. Actual graphics, controls and performance still require an interactive Windows test.
