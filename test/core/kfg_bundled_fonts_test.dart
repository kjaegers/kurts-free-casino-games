import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A raw [TextPainter] doesn't inherit the app theme's bundled fonts. On web,
/// text it paints without `fontFamily`/`fontFamilyFallback` can make the
/// engine download fallback fonts at runtime, which breaks offline play.
void main() {
  test('every file that builds a TextPainter uses the bundled fonts', () {
    final offenders = <String>[];
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));
    for (final file in files) {
      final source = file.readAsStringSync();
      if (source.contains('TextPainter(') && !source.contains('KfgFonts')) {
        offenders.add(file.path);
      }
    }
    expect(offenders, isEmpty, reason: 'Set fontFamily: KfgFonts.family');
  });
}
