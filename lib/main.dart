import 'package:flutter/material.dart';

import 'app/kfg_app.dart';
import 'app/kfg_binding.dart';
import 'app/kfg_licenses.dart';
import 'core/services/credits_service.dart';
import 'core/services/favorites_service.dart';
import 'core/services/settings_service.dart';
import 'core/services/stats_service.dart';

Future<void> main() async {
  KfgBinding();
  KfgLicenses.register();
  await StatsService.instance.ensureLoaded();
  await CreditsService.instance.ensureLoaded();
  await FavoritesService.instance.ensureLoaded();
  await SettingsService.instance.ensureLoaded();
  runApp(const KfgApp());
}
