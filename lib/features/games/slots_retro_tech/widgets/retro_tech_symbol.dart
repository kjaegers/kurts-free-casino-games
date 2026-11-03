import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../logic/retro_tech_symbols.dart';

/// One grid symbol as glowing 16 × 16 pixel art, filling a [size] square.
/// Each symbol differs in shape as well as colour.
class RetroTechSymbolIcon extends StatelessWidget {
  const RetroTechSymbolIcon({
    super.key,
    required this.symbol,
    required this.size,
    this.dimmed = false,
  });

  final RetroTechSymbol symbol;
  final double size;

  /// Faded, for symbols that aren't part of a winning cluster.
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: RetroTechSymbolPainter(symbol: symbol, dimmed: dimmed),
      ),
    );
  }
}

/// Paints a symbol's sprite: a soft halo in its glow colour, then the
/// pixels themselves, hard-edged like an old screen.
class RetroTechSymbolPainter extends CustomPainter {
  const RetroTechSymbolPainter({required this.symbol, this.dimmed = false});

  final RetroTechSymbol symbol;
  final bool dimmed;

  static const int _pixels = 16;

  /// Each sprite's pixels as paths in a 16-unit square, one per colour,
  /// built once.
  static final Map<RetroTechSymbol, _SpritePaths> _cache = {};

  @override
  void paint(Canvas canvas, Size size) {
    final sprite = _cache[symbol] ??= _SpritePaths.build(_sprites[symbol]!);
    final s = size.shortestSide;
    canvas.save();
    canvas.translate((size.width - s) / 2, (size.height - s) / 2);
    canvas.scale(s / _pixels);
    if (dimmed) {
      canvas.saveLayer(
        const Rect.fromLTWH(0, 0, 16, 16),
        Paint()..color = const Color(0x4DFFFFFF),
      );
    }
    canvas.drawPath(
      sprite.outline,
      Paint()
        ..color = sprite.glow.withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.9),
    );
    for (final (color, path) in sprite.layers) {
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..isAntiAlias = false,
      );
    }
    if (dimmed) canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(RetroTechSymbolPainter oldDelegate) =>
      oldDelegate.symbol != symbol || oldDelegate.dimmed != dimmed;
}

class _Sprite {
  const _Sprite({
    required this.glow,
    required this.palette,
    required this.rows,
  });

  /// The halo colour.
  final Color glow;

  /// The colour of each letter used in [rows]; '.' is transparent.
  final Map<String, Color> palette;

  /// 16 rows of 16 pixels, top to bottom.
  final List<String> rows;
}

class _SpritePaths {
  const _SpritePaths({
    required this.glow,
    required this.layers,
    required this.outline,
  });

  factory _SpritePaths.build(_Sprite sprite) {
    final paths = <String, Path>{};
    final outline = Path()..fillType = ui.PathFillType.nonZero;
    for (var y = 0; y < sprite.rows.length; y++) {
      final row = sprite.rows[y];
      for (var x = 0; x < row.length; x++) {
        final key = row[x];
        if (key == '.') continue;
        final pixel = Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 1);
        (paths[key] ??= Path()).addRect(pixel);
        outline.addRect(pixel);
      }
    }
    return _SpritePaths(
      glow: sprite.glow,
      layers: [
        for (final MapEntry(:key, :value) in paths.entries)
          (sprite.palette[key]!, value),
      ],
      outline: outline,
    );
  }

  final Color glow;
  final List<(Color, Path)> layers;
  final Path outline;
}

// dart format off
const Map<RetroTechSymbol, _Sprite> _sprites = {
  // A golden arcade token with a diamond stamped in the middle.
  RetroTechSymbol.token: _Sprite(
    glow: Color(0xFFFFC400),
    palette: {
      'D': Color(0xFFB8860B),
      'Y': Color(0xFFFFC400),
      'L': Color(0xFFFFF59D),
      'W': Color(0xFFFFFFFF),
    },
    rows: [
      '................',
      '....DDDDDDDD....',
      '...DYYYYYYYYD...',
      '..DYWLYYYYYYYD..',
      '.DYWLYYYYYYYYYD.',
      '.DYLYYYDDYYYYYD.',
      '.DYYYYDLLDYYYYD.',
      '.DYYYDLLLLDYYYD.',
      '.DYYYDLLLLDYYYD.',
      '.DYYYYDLLDYYYYD.',
      '.DYYYYYDDYYYYYD.',
      '.DYYYYYYYYYYYYD.',
      '..DYYYYYYYYYYD..',
      '...DYYYYYYYYD...',
      '....DDDDDDDD....',
      '................',
    ],
  ),
  // A little helmeted hero, mid-stride.
  RetroTechSymbol.runner: _Sprite(
    glow: Color(0xFFFF4FD8),
    palette: {
      'H': Color(0xFF00E5FF),
      'S': Color(0xFFFFCC99),
      'E': Color(0xFF1A1A2E),
      'B': Color(0xFFFF4FD8),
      'P': Color(0xFF9D7BFF),
      'K': Color(0xFFFFFFFF),
    },
    rows: [
      '................',
      '.......HHHH.....',
      '......HHHHHH....',
      '......SSSESS....',
      '......SSSSSS....',
      '.......SSSS.....',
      '.....BBBBBB.....',
      '....BBBBBBBBSS..',
      '..SSBBBBBB......',
      '......BBBB......',
      '.....PPPPPP.....',
      '....PPP..PPP....',
      '...PPP....PPP...',
      '..PPP......PP...',
      '.KKK.......KKK..',
      '................',
    ],
  ),
  // A ball-top joystick on its base, fire button to one side.
  RetroTechSymbol.joystick: _Sprite(
    glow: Color(0xFFFF2B4A),
    palette: {
      'R': Color(0xFFFF2B4A),
      'L': Color(0xFFFFA8B4),
      'G': Color(0xFFB0BEC5),
      'Y': Color(0xFFFFEA00),
      'c': Color(0xFF00B8D4),
      'C': Color(0xFF006978),
    },
    rows: [
      '................',
      '......RRRR......',
      '.....RLLRRR.....',
      '.....RLRRRR.....',
      '.....RRRRRR.....',
      '......RRRR......',
      '.......GG.......',
      '.......GG.......',
      '..YY...GG.......',
      '..YY..cGGc......',
      '.cccccccccccccc.',
      '.cCCCCCCCCCCCCc.',
      '.cCCCCCCCCCCCCc.',
      '.cccccccccccccc.',
      '................',
      '................',
    ],
  ),
  // A green-screen monitor with a few lines of text and a power light.
  RetroTechSymbol.monitor: _Sprite(
    glow: Color(0xFF39FF14),
    palette: {
      'M': Color(0xFF90A4AE),
      'S': Color(0xFF0B3D1E),
      'T': Color(0xFF39FF14),
      'R': Color(0xFFFF1744),
    },
    rows: [
      '................',
      '.MMMMMMMMMMMMMM.',
      '.MSSSSSSSSSSSSM.',
      '.MSTTTSSSSSSSSM.',
      '.MSSSSSSSSSSSSM.',
      '.MSTTTTTSSSSSSM.',
      '.MSSSSSSSSSSSSM.',
      '.MSTTSTTTSSSSSM.',
      '.MSSSSSSSSSSSSM.',
      '.MSTSTTSSSSSSSM.',
      '.MSSSSSSSSSSSSM.',
      '.MMMMMMMMMMMMMM.',
      '.MMMMMMMMMMMRMM.',
      '.....MMMMMM.....',
      '...MMMMMMMMMM...',
      '................',
    ],
  ),
  // A 5.25-inch floppy: label, hub, read slot and write-protect notch.
  RetroTechSymbol.floppy: _Sprite(
    glow: Color(0xFFE040FB),
    palette: {
      'O': Color(0xFFE040FB),
      'J': Color(0xFF4A148C),
      'L': Color(0xFFECEFF1),
      'l': Color(0xFF00B0FF),
      'H': Color(0xFFB0BEC5),
      'K': Color(0xFF12001F),
    },
    rows: [
      'OOOOOOOOOOOOOOOO',
      'OJLLLLLLLLLLLLJO',
      'OJLllllllllllLJO',
      'OJLLLLLLLLLLLLJ.',
      'OJJJJJJJJJJJJJJ.',
      'OJJJJJHHHHJJJJJO',
      'OJJJJHHKKHHJJJJO',
      'OJJJJHKKKKHJJJJO',
      'OJJJJHKKKKHJJJJO',
      'OJJJJHHKKHHJJJJO',
      'OJJJJJHHHHJJJJJO',
      'OJJJJJJJJJJJJJJO',
      'OJJJJJJKKJJJJJJO',
      'OJJJJJJKKJJJJJJO',
      'OJJJJJJKKJJJJJJO',
      'OOOOOOOOOOOOOOOO',
    ],
  ),
  // A game cartridge: ridged shell, picture label and gold contacts.
  RetroTechSymbol.cartridge: _Sprite(
    glow: Color(0xFFFF9100),
    palette: {
      'c': Color(0xFFE65100),
      'C': Color(0xFFFF9100),
      'L': Color(0xFFFFF3E0),
      'a': Color(0xFFD500F9),
      'b': Color(0xFF00E5FF),
      'Y': Color(0xFFFFD600),
    },
    rows: [
      '................',
      '..cccccccccccc..',
      '..cCCCCCCCCCCc..',
      '..cCLLLLLLLLCc..',
      '..cCLaaaaabLCc..',
      '..cCLabbbaaLCc..',
      '..cCLaaaaaaLCc..',
      '..cCLLLLLLLLCc..',
      '..cCCCCCCCCCCc..',
      '..cCcCcCcCcCCc..',
      '..cCCCCCCCCCCc..',
      '...cccccccccc...',
      '.....Y.Y.Y.Y....',
      '.....Y.Y.Y.Y....',
      '................',
      '................',
    ],
  ),
  // A cassette tape: label stripe, and two reels behind the window.
  RetroTechSymbol.cassette: _Sprite(
    glow: Color(0xFFFF4081),
    palette: {
      'S': Color(0xFFFF4081),
      'D': Color(0xFF311B92),
      'l': Color(0xFF00E5FF),
      'W': Color(0xFFFFFFFF),
      'K': Color(0xFF0D0221),
    },
    rows: [
      '................',
      '................',
      'SSSSSSSSSSSSSSSS',
      'SllllllllllllllS',
      'SDDDDDDDDDDDDDDS',
      'SDKKKKKKKKKKKKDS',
      'SDKWWKKKKKKWWKDS',
      'SDWKKWKKKKWKKWDS',
      'SDWKKWKKKKWKKWDS',
      'SDKWWKKKKKKWWKDS',
      'SDKKKKKKKKKKKKDS',
      'SDDDDDDDDDDDDDDS',
      'SSSSSSSSSSSSSSSS',
      '.SDDDDDDDDDDDDS.',
      '..SSSSSSSSSSSS..',
      '................',
    ],
  ),
  // A microchip with pins on every side and a glowing die.
  RetroTechSymbol.chip: _Sprite(
    glow: Color(0xFF00E5FF),
    palette: {
      'P': Color(0xFFB0BEC5),
      'O': Color(0xFF00E5FF),
      'B': Color(0xFF1A237E),
      'W': Color(0xFFFFFFFF),
      'G': Color(0xFF76FF03),
      'g': Color(0xFF33691E),
    },
    rows: [
      '................',
      '....P.P..P.P....',
      '....P.P..P.P....',
      '...OOOOOOOOOO...',
      'PPPOWBBBBBBBOPPP',
      '...OBBBBBBBBO...',
      'PPPOBBGGGGBBOPPP',
      '...OBBGggGBBO...',
      '...OBBGggGBBO...',
      'PPPOBBGGGGBBOPPP',
      '...OBBBBBBBBO...',
      'PPPOBBBBBBBBOPPP',
      '...OOOOOOOOOO...',
      '....P.P..P.P....',
      '....P.P..P.P....',
      '................',
    ],
  ),
};
// dart format on
