"""Small images made in memory; no photos or machine-specific fixtures."""
import importlib.util
from pathlib import Path
import re
import tempfile
import unittest

from PIL import Image

SPEC = importlib.util.spec_from_file_location("palette", Path(__file__).resolve().parents[2] / "dragon-core/palette.py")
palette = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(palette)


class Extraction(unittest.TestCase):
    def test_colors_determinism_contrast_and_lightness(self):
        accents = set()
        with tempfile.TemporaryDirectory() as directory:
            for color in ("#1254D5", "#D51B24", "#158C32"):
                with self.subTest(color=color):
                    image = Path(directory) / "input.png"
                    Image.new("RGB", (64, 48), color).save(image)
                    data = palette.extract(image)
                    self.assertEqual(data, palette.extract(image))
                    self.assertFalse(data["fallback"])
                    self.assertGreaterEqual(palette.contrast(data["accent"], data["onAccent"]), 4.5)
                    self.assertTrue(0.68 <= palette.oklab(palette.rgb(data["accent"]))[0] <= 0.82)
                    self.assertLessEqual(palette.oklab(palette.rgb(data["tint"]))[0], 0.12)
                    for key in palette.DRAGON:
                        colors = data[key] if key == "swatches" else [data[key]]
                        for value in colors:
                            self.assertRegex(value, re.compile(r"^#[0-9A-F]{6}$"))
                    self.assertEqual(len(data["swatches"]), 5)
                    accents.add(data["accent"])
        self.assertEqual(len(accents), 3)

    def test_fallback(self):
        with tempfile.TemporaryDirectory() as directory:
            for color in ("#888888", "#000000", "#FEFEFD", "#888789"):
                image = Path(directory) / "gray.png"
                Image.new("RGB", (40, 40), color).save(image)
                data = palette.extract(image)
                self.assertTrue(data["fallback"])
                for key, value in palette.DRAGON.items():
                    self.assertEqual(data[key], value)

    def test_hash_is_of_reduced_pixels(self):
        with tempfile.TemporaryDirectory() as directory:
            png, bmp = (Path(directory) / name for name in ("a.png", "b.bmp"))
            image = Image.new("RGB", (400, 300), "blue")
            image.save(png)
            image.save(bmp)
            self.assertEqual(palette.extract(png)["sourceHash"], palette.extract(bmp)["sourceHash"])

    def test_unreadable_input(self):
        with self.assertRaises(OSError):
            palette.extract("/does-not-exist/palette.png")


if __name__ == "__main__":
    unittest.main()
