"""Builds the subset fonts bundled in assets/fonts/.

The app must render every glyph offline (CLAUDE.md section 2). Flutter web
otherwise downloads Roboto and Noto fallback fonts from fonts.gstatic.com at
runtime, so the fonts the app needs ship as assets instead, subset to keep the
download small.

Dev-time only: needs `pip install fonttools` and the source fonts below,
downloaded once into SOURCE_DIR (all SIL OFL 1.1 or Apache 2.0):

  roboto-*.ttf                  <flutter sdk>/bin/cache/artifacts/material_fonts/
  NotoSansSymbols2-Regular.ttf  github.com/notofonts/notofonts.github.io (fonts/NotoSansSymbols2)
  NotoSansMath-Regular.ttf      github.com/notofonts/notofonts.github.io (fonts/NotoSansMath)
  NotoEmoji[wght].ttf           github.com/google/fonts (ofl/notoemoji)

Usage:
  python tools/fonts/build_bundled_fonts.py <SOURCE_DIR>

When a game starts rendering a new symbol or emoji, add its code point to the
matching list below, rebuild, and check it with `--check`.
"""

import os
import sys

from fontTools import subset
from fontTools.ttLib import TTFont

OUT_DIR = os.path.join(os.path.dirname(__file__), '..', '..', 'assets', 'fonts')

# Latin text, punctuation, currency, letterlike symbols and number forms.
ROBOTO_RANGES = [
    (0x0020, 0x024F),
    (0x02B0, 0x036F),
    (0x2000, 0x206F),
    (0x20A0, 0x20CF),
    (0x2100, 0x218F),
]

ROBOTO_FILES = {
    'roboto-regular.ttf': 'Roboto-Regular.ttf',
    'roboto-italic.ttf': 'Roboto-Italic.ttf',
    'roboto-medium.ttf': 'Roboto-Medium.ttf',
    'roboto-bold.ttf': 'Roboto-Bold.ttf',
    'roboto-black.ttf': 'Roboto-Black.ttf',
}

# Text-style symbols Roboto lacks. Deliberately explicit: a broad range would
# also capture code points that native platforms draw as colour emoji.
SYMBOLS = [
    0x2022,  # • bullet
    0x232B,  # ⌫ erase to the left (Word Guess keyboard)
    0x2660, 0x2661, 0x2662, 0x2663,  # ♠ ♡ ♢ ♣
    0x2664, 0x2665, 0x2666, 0x2667,  # ♤ ♥ ♦ ♧ (card suits)
    0x2713, 0x2714, 0x2715, 0x2716, 0x2717, 0x2718,  # ✓ ✔ ✕ ✖ ✗ ✘
]

# Arrows block (Parking Panic, Klondike, Word Guess).
ARROW_RANGES = [(0x2190, 0x21FF)]

# Emoji drawn as text by Memory Tiles and Realm Rally. Only used on web (see
# KfgFonts); native platforms keep their own colour emoji font.
EMOJI = [
    0x2694, 0x26BD, 0xFE0F,
    0x1F31F, 0x1F340, 0x1F349, 0x1F355, 0x1F369, 0x1F381, 0x1F388, 0x1F3A7,
    0x1F3AF, 0x1F3B2, 0x1F3B7, 0x1F419, 0x1F434, 0x1F525, 0x1F680, 0x1F9E9,
]


def _expand(ranges):
    return [cp for lo, hi in ranges for cp in range(lo, hi + 1)]


def _subset(src, dst, unicodes):
    options = subset.Options()
    options.layout_features = ['*']
    options.name_IDs = ['*']
    options.notdef_outline = True
    options.drop_tables += ['DSIG']
    font = TTFont(src)
    subsetter = subset.Subsetter(options)
    subsetter.populate(unicodes=unicodes)
    subsetter.subset(font)
    font.save(dst)
    print(f'{os.path.basename(dst):32} {os.path.getsize(dst):>8} bytes')


def build(source_dir):
    os.makedirs(OUT_DIR, exist_ok=True)
    roboto = _expand(ROBOTO_RANGES)
    for src, dst in ROBOTO_FILES.items():
        _subset(os.path.join(source_dir, src), os.path.join(OUT_DIR, dst), roboto)
    _subset(
        os.path.join(source_dir, 'NotoSansSymbols2-Regular.ttf'),
        os.path.join(OUT_DIR, 'KfgSymbols-Regular.ttf'),
        SYMBOLS,
    )
    _subset(
        os.path.join(source_dir, 'NotoSansMath-Regular.ttf'),
        os.path.join(OUT_DIR, 'KfgArrows-Regular.ttf'),
        _expand(ARROW_RANGES),
    )
    _subset(
        os.path.join(source_dir, 'NotoEmoji[wght].ttf'),
        os.path.join(OUT_DIR, 'KfgEmoji-Regular.ttf'),
        EMOJI,
    )


def check(code_points):
    """Prints which bundled font covers each code point, or MISSING."""
    fonts = {
        name: set(TTFont(os.path.join(OUT_DIR, name)).getBestCmap())
        for name in sorted(os.listdir(OUT_DIR))
        if name.endswith('.ttf')
    }
    missing = 0
    for cp in code_points:
        owners = [n for n, cmap in fonts.items() if cp in cmap]
        if not owners:
            missing += 1
        print(f'U+{cp:04X} {owners[0] if owners else "MISSING"}')
    return missing


if __name__ == '__main__':
    if len(sys.argv) >= 2 and sys.argv[1] == '--check':
        cps = [int(a.removeprefix('U+'), 16) for a in sys.argv[2:]]
        sys.exit(1 if check(cps) else 0)
    if len(sys.argv) != 2:
        print(__doc__)
        sys.exit(2)
    build(sys.argv[1])
