#!/usr/bin/env python3
"""Opt-in offline art pipeline. Never invoked by the game or CI."""
import argparse
import io
import os
import pathlib
import urllib.request

from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parents[1]
ITEMS = {
    "axe": "wooden handled axe with a steel head",
    "pick": "wooden handled pickaxe",
    "hoe": "small garden hoe",
    "can": "teal watering can",
    "seed": "paper seed packet with tiny sprout",
    "wood": "short cut log with visible growth rings",
    "stone": "rounded gray rock",
    "twig": "small forked twig",
    "fruit": "single ripe red apple",
    "flower": "single yellow garden flower with green leaves",
    "turnip": "cream and lavender turnip with leaves",
}

def destination(kind, name):
    return ROOT / "assets" / "art" / ("icons" if kind == "icon" else "textures") / (name + ".png")

def prompt_for(kind, name):
    if kind == "icon":
        return (
            "Original cozy rural simulation game inventory icon of " + ITEMS[name] +
            ", single isolated object centered, rounded silhouette, clean dark colored outline, "
            "saturated natural colors, simple two-tone shading, soft highlight from upper left, "
            "uniform plain background for manual removal, no letters, no watermark, no frame. "
            "Readable at 32 pixels. Square composition, generous margins."
        )
    return (
        "Seamless tileable square hand-painted grass albedo texture for an original cozy rural game, "
        "fresh natural green with fine subtle leaf and grass hints, soft low-contrast variation, "
        "flat top down material, no lighting, no shadows, no objects, no borders, no text. "
        "Perfectly repeatable edges, not a landscape illustration."
    )

def install(kind, name, source, replace):
    target = destination(kind, name)
    if target.exists() and not replace:
        raise SystemExit("Asset exists. Use --replace only after review.")
    with Image.open(source) as original:
        original.load()
        if original.width > 8192 or original.height > 8192:
            raise SystemExit("Source exceeds size limit")
        if original.width != original.height:
            raise SystemExit("Provide a square image; crop manually first.")
        if kind == "icon":
            img = original.convert("RGBA")
            if img.getchannel("A").getextrema()[0] == 255:
                raise SystemExit("Icon needs actual transparency; remove the background first.")
            img = img.resize((128, 128), Image.Resampling.LANCZOS)
        else:
            img = original.convert("RGB").resize((512, 512), Image.Resampling.LANCZOS)
        target.parent.mkdir(parents=True, exist_ok=True)
        img.save(target, format="PNG", optimize=True)
    print("Installed:", target.relative_to(ROOT))

def generate(kind, name, output):
    # Paid external generation is explicit; FAL_KEY stays in the local environment.
    if not os.environ.get("FAL_KEY"):
        raise SystemExit("Set FAL_KEY locally; never commit it.")
    import fal_client
    result = fal_client.subscribe("fal-ai/flux/schnell", arguments={
        "prompt": prompt_for(kind, name),
        "image_size": "square_hd",
        "num_images": 1,
    })
    url = result["images"][0]["url"]
    if not url.startswith("https://"):
        raise SystemExit("Unexpected output URL")
    with urllib.request.urlopen(url, timeout=60) as response:
        data = response.read(25 * 1024 * 1024 + 1)
    if len(data) > 25 * 1024 * 1024:
        raise SystemExit("Image too large")
    with Image.open(io.BytesIO(data)) as img:
        output.parent.mkdir(parents=True, exist_ok=True)
        img.save(output, format="PNG")
    print("Staged for review:", output)
    print("Review originality, transparency or seams before using the install command.")

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("action", choices=["prompt", "install", "generate"])
    p.add_argument("kind", choices=["icon", "texture"])
    p.add_argument("name")
    p.add_argument("--source", type=pathlib.Path)
    p.add_argument("--output", type=pathlib.Path)
    p.add_argument("--replace", action="store_true")
    args = p.parse_args()
    if args.name not in (ITEMS if args.kind == "icon" else {"grass"}):
        p.error("Unknown asset ID")
    if args.action == "prompt":
        print(prompt_for(args.kind, args.name))
    elif args.action == "install":
        if not args.source:
            p.error("--source is required")
        install(args.kind, args.name, args.source, args.replace)
    else:
        if not args.output:
            p.error("--output is required (staging location outside the asset directory)")
        if args.output.resolve().is_relative_to((ROOT / "assets").resolve()):
            p.error("Generate into staging, not directly into game assets")
        if args.output.exists():
            p.error("Staging output already exists")
        generate(args.kind, args.name, args.output)

if __name__ == "__main__":
    main()
