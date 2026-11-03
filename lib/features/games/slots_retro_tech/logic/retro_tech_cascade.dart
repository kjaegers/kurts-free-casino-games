import 'retro_tech_paytable.dart';
import 'retro_tech_symbols.dart';

/// A spin ends after this many paying cascades even if the grid would win
/// again (the last one is still paid). At the published weights a chain
/// anywhere near this long is vanishingly unlikely; the cap only keeps a
/// spin finite.
const int retroTechMaxCascades = 50;

/// A group of [retroTechMinCluster] or more matching symbols joined edge
/// to edge (not diagonally).
class RetroTechCluster {
  const RetroTechCluster({required this.symbol, required this.cells});

  final RetroTechSymbol symbol;

  /// Grid indices (see [retroTechIndex]), in ascending order.
  final List<int> cells;

  int get size => cells.length;

  /// What the cluster pays per bet level.
  int get pays => retroTechClusterPays(symbol, size);
}

/// Every winning cluster on [grid], in order of the top-left cell of each.
List<RetroTechCluster> findRetroTechClusters(RetroTechGrid grid) {
  final seen = List<bool>.filled(retroTechCellCount, false);
  final clusters = <RetroTechCluster>[];
  final stack = <int>[];
  for (var start = 0; start < retroTechCellCount; start++) {
    if (seen[start]) continue;
    final symbol = grid[start];
    final cells = <int>[];
    seen[start] = true;
    stack.add(start);
    while (stack.isNotEmpty) {
      final cell = stack.removeLast();
      cells.add(cell);
      final row = cell ~/ retroTechColumns;
      final column = cell % retroTechColumns;
      for (final next in [
        if (row > 0) cell - retroTechColumns,
        if (row < retroTechRows - 1) cell + retroTechColumns,
        if (column > 0) cell - 1,
        if (column < retroTechColumns - 1) cell + 1,
      ]) {
        if (!seen[next] && grid[next] == symbol) {
          seen[next] = true;
          stack.add(next);
        }
      }
    }
    if (cells.length >= retroTechMinCluster) {
      cells.sort();
      clusters.add(
        RetroTechCluster(symbol: symbol, cells: List.unmodifiable(cells)),
      );
    }
  }
  return clusters;
}

/// One paying moment of a spin: the [grid] as it landed and the
/// [clusters] it paid, which then vanish.
class RetroTechCascadeStep {
  const RetroTechCascadeStep({required this.grid, required this.clusters});

  final RetroTechGrid grid;
  final List<RetroTechCluster> clusters;

  /// What the step pays per bet level.
  int get pays => clusters.fold(0, (sum, c) => sum + c.pays);

  /// Every cell of every cluster, removed after paying.
  Set<int> get removed => {for (final c in clusters) ...c.cells};
}

/// Everything a spin does, worked out the moment it starts.
///
/// [grids] are what the player sees in turn: the grid as it first lands,
/// then the grid after each cascade. Each grid but the last is a winning
/// [steps] entry. [fallFrom] says where each cell of a grid came from, for
/// the falling animation.
class RetroTechSpinResult {
  const RetroTechSpinResult._({
    required this.drops,
    required this.steps,
    required this.grids,
    required this.fallFrom,
  });

  /// Every symbol drawn, per column in the order drawn. The whole spin can
  /// be rebuilt from these with [replay], so they're what gets saved.
  final List<List<RetroTechSymbol>> drops;
  final List<RetroTechCascadeStep> steps;
  final List<RetroTechGrid> grids;

  /// For each of [grids], per cell: the row it fell from in the grid
  /// before, or a negative row (above the window) for a new symbol. Every
  /// cell of the first grid is new and falls a whole window height.
  final List<List<int>> fallFrom;

  RetroTechGrid get finalGrid => grids.last;

  /// Paying cascades, counting the first landing.
  int get cascades => steps.length;

  /// What the whole spin pays per bet level.
  int get pays => steps.fold(0, (sum, s) => sum + s.pays);

  /// Plays out a spin, drawing every symbol from [draw]: five per column to
  /// fill the grid, then one for every cell a cascade empties.
  static RetroTechSpinResult resolve(RetroTechSymbolDraw draw) {
    final drops = List.generate(retroTechColumns, (_) => <RetroTechSymbol>[]);
    RetroTechSymbol take(int column) {
      final symbol = draw(column);
      drops[column].add(symbol);
      return symbol;
    }

    // The first symbol drawn for a column lands at the bottom.
    final first = List<RetroTechSymbol?>.filled(retroTechCellCount, null);
    for (var column = 0; column < retroTechColumns; column++) {
      for (var row = retroTechRows - 1; row >= 0; row--) {
        first[retroTechIndex(row, column)] = take(column);
      }
    }
    RetroTechGrid grid = List.unmodifiable([for (final s in first) s!]);
    final grids = <RetroTechGrid>[grid];
    final fallFrom = <List<int>>[
      List.unmodifiable([
        for (var i = 0; i < retroTechCellCount; i++)
          i ~/ retroTechColumns - retroTechRows,
      ]),
    ];
    final steps = <RetroTechCascadeStep>[];
    while (steps.length < retroTechMaxCascades) {
      final clusters = findRetroTechClusters(grid);
      if (clusters.isEmpty) break;
      final step = RetroTechCascadeStep(grid: grid, clusters: clusters);
      steps.add(step);
      if (steps.length == retroTechMaxCascades) break;
      final (next, from) = _collapse(grid, step.removed, take);
      grid = next;
      grids.add(grid);
      fallFrom.add(from);
    }
    return RetroTechSpinResult._(
      drops: List.unmodifiable([
        for (final d in drops) List<RetroTechSymbol>.unmodifiable(d),
      ]),
      steps: List.unmodifiable(steps),
      grids: List.unmodifiable(grids),
      fallFrom: List.unmodifiable(fallFrom),
    );
  }

  /// Rebuilds a spin from its saved [drops]. Returns null when they don't
  /// make a whole spin: a column runs out early or has symbols left over.
  static RetroTechSpinResult? replay(List<List<RetroTechSymbol>> drops) {
    if (drops.length != retroTechColumns) return null;
    final used = List<int>.filled(retroTechColumns, 0);
    try {
      final result = resolve((column) => drops[column][used[column]++]);
      for (var column = 0; column < retroTechColumns; column++) {
        if (used[column] != drops[column].length) return null;
      }
      return result;
    } on RangeError {
      return null;
    }
  }

  /// Removes [removed] from [grid], lets the symbols above fall into the
  /// gaps and fills each column from the top with new symbols from [take].
  /// The first new symbol lands lowest, as if it dropped in first.
  static (RetroTechGrid, List<int>) _collapse(
    RetroTechGrid grid,
    Set<int> removed,
    RetroTechSymbol Function(int column) take,
  ) {
    final next = List<RetroTechSymbol?>.filled(retroTechCellCount, null);
    final from = List<int>.filled(retroTechCellCount, 0);
    for (var column = 0; column < retroTechColumns; column++) {
      var target = retroTechRows - 1;
      for (var row = retroTechRows - 1; row >= 0; row--) {
        final index = retroTechIndex(row, column);
        if (removed.contains(index)) continue;
        next[retroTechIndex(target, column)] = grid[index];
        from[retroTechIndex(target, column)] = row;
        target--;
      }
      final missing = target + 1;
      for (var row = target; row >= 0; row--) {
        next[retroTechIndex(row, column)] = take(column);
        from[retroTechIndex(row, column)] = row - missing;
      }
    }
    return (
      List<RetroTechSymbol>.unmodifiable([for (final s in next) s!]),
      List<int>.unmodifiable(from),
    );
  }
}
