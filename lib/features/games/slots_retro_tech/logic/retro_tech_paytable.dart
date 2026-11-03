import 'retro_tech_symbols.dart';

/// Credits in one bet level. Clusters pay per level, so small wins can pay
/// a fraction of the bet in whole credits.
const int retroTechCreditsPerLevel = 10;

/// The smallest group of matching symbols that pays.
const int retroTechMinCluster = 4;

/// A band of cluster sizes that pay the same, one column of the paytable.
class RetroTechTier {
  const RetroTechTier(this.min, this.max, this.label);

  final int min;
  final int max;
  final String label;

  bool contains(int size) => size >= min && size <= max;
}

const List<RetroTechTier> retroTechTiers = [
  RetroTechTier(4, 4, '4'),
  RetroTechTier(5, 5, '5'),
  RetroTechTier(6, 6, '6'),
  RetroTechTier(7, 7, '7'),
  RetroTechTier(8, 10, '8–10'),
  RetroTechTier(11, retroTechCellCount, '11+'),
];

/// What a cluster pays per bet level (10 credits), by symbol and then by
/// [retroTechTiers] column.
const Map<RetroTechSymbol, List<int>> retroTechPaytable = {
  RetroTechSymbol.token: [50, 120, 250, 500, 2500, 10000],
  RetroTechSymbol.runner: [40, 80, 150, 300, 1000, 5000],
  RetroTechSymbol.joystick: [30, 50, 100, 200, 500, 2500],
  RetroTechSymbol.monitor: [25, 40, 80, 150, 300, 1500],
  RetroTechSymbol.floppy: [20, 30, 50, 100, 200, 1000],
  RetroTechSymbol.cartridge: [15, 25, 40, 60, 120, 500],
  RetroTechSymbol.cassette: [10, 15, 30, 50, 100, 400],
  RetroTechSymbol.chip: [10, 15, 20, 30, 60, 200],
};

/// The paytable column for a cluster of [size], or null when too small.
int? retroTechTierOf(int size) {
  for (var i = 0; i < retroTechTiers.length; i++) {
    if (retroTechTiers[i].contains(size)) return i;
  }
  return null;
}

/// What a cluster of [size] [symbol]s pays per bet level; 0 when too small.
int retroTechClusterPays(RetroTechSymbol symbol, int size) {
  final tier = retroTechTierOf(size);
  return tier == null ? 0 : retroTechPaytable[symbol]![tier];
}

/// The long-run return, estimated by `tools/slots_retro_tech/return_check.dart`
/// and published in How to Play.
const String retroTechReturnPercent = '96.0';
