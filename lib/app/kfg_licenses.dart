import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Licenses for content the app bundles itself, shown alongside the package
/// licenses Flutter collects automatically on the licenses page (About >
/// Open-Source Licenses).
///
/// The app's own license and the font license files ship as assets so the
/// full text is available offline; when a bundled font is added, add its
/// license file to `pubspec.yaml` and to [_fontLicenses].
abstract final class KfgLicenses {
  /// Package name the app's own license (GPLv3, the repo's `LICENSE`) is
  /// listed under.
  static const String appPackage = "Kurt's Free Casino Games";
  static const String _appLicense = 'LICENSE';

  /// (packages shown on the licenses page, bundled license file)
  static const List<(List<String>, String)> _fontLicenses = [
    (['Roboto (font)'], 'assets/fonts/LICENSE-Roboto.txt'),
    (
      ['Noto Sans Symbols 2 (font, bundled as KfgSymbols)'],
      'assets/fonts/OFL-NotoSansSymbols2.txt',
    ),
    (
      ['Noto Sans Math (font, bundled as KfgArrows)'],
      'assets/fonts/OFL-NotoSansMath.txt',
    ),
    (
      ['Noto Emoji (font, bundled as KfgEmoji)'],
      'assets/fonts/OFL-NotoEmoji.txt',
    ),
  ];

  static bool _registered = false;

  /// Adds the bundled licenses to [LicenseRegistry]. Safe to call more than
  /// once. The files are only read when the licenses page is opened.
  static void register({AssetBundle? bundle}) {
    if (_registered) return;
    _registered = true;
    LicenseRegistry.addLicense(() => collect(bundle: bundle ?? rootBundle));
  }

  /// The bundled license entries, read from [bundle].
  @visibleForTesting
  static Stream<LicenseEntry> collect({required AssetBundle bundle}) async* {
    yield LicenseEntryWithLineBreaks([
      appPackage,
    ], await bundle.loadString(_appLicense));
    for (final (packages, path) in _fontLicenses) {
      yield LicenseEntryWithLineBreaks(packages, await bundle.loadString(path));
    }
  }
}
