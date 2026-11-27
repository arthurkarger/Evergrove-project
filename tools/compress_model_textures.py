"""Set GPU compression for embedded Blender textures extracted by the first Godot import."""
from pathlib import Path

textures = list(Path("assets/models/generated").glob("*.png.import"))
if not textures:
    raise SystemExit("No imported Blender textures found")
for sidecar in textures:
    text = sidecar.read_text()
    text = text.replace("compress/mode=0\n", "compress/mode=2\n")
    text = text.replace("mipmaps/generate=false", "mipmaps/generate=true")
    sidecar.write_text(text)
print(f"Configured {len(textures)} Blender texture imports")
