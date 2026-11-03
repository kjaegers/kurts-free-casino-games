import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurts_free_casino_games/app/kfg_licenses.dart';
import 'package:kurts_free_casino_games/app/kfg_theme.dart';
import 'package:kurts_free_casino_games/features/about/about_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String textOf(LicenseEntry entry) =>
      entry.paragraphs.map((p) => p.text).join('\n');

  test('the app license and every bundled font license load from the app bundle', () async {
    final entries = await KfgLicenses.collect(bundle: rootBundle).toList();
    final byPackage = {
      for (final entry in entries) entry.packages.single: textOf(entry),
    };

    expect(
      byPackage[KfgLicenses.appPackage],
      contains('GNU GENERAL PUBLIC LICENSE'),
    );
    expect(byPackage['Roboto (font)'], contains('Apache License'));
    for (final noto in [
      'Noto Sans Symbols 2 (font, bundled as KfgSymbols)',
      'Noto Sans Math (font, bundled as KfgArrows)',
      'Noto Emoji (font, bundled as KfgEmoji)',
    ]) {
      expect(byPackage[noto], contains('SIL Open Font License'), reason: noto);
    }
  });

  test('registering adds the entries to the license registry once', () async {
    KfgLicenses.register();
    KfgLicenses.register();
    final packages = await LicenseRegistry.licenses
        .expand((entry) => entry.packages)
        .toList();
    expect(packages.where((p) => p == 'Roboto (font)'), hasLength(1));
  });

  testWidgets('About opens the open-source licenses page', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: KfgTheme.dark,
        home: const Scaffold(body: AboutScreen()),
      ),
    );
    final entry = find.textContaining('Open-source licenses —');
    await tester.scrollUntilVisible(entry, 200);
    await tester.tap(entry);
    // The page keeps a spinner up while it reads the license files, so it
    // never settles under the test clock; pump through the route transition.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(LicensePage), findsOneWidget);
  });
}
