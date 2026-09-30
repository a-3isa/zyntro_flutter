/// One-shot launch payload for recap PR celebration (Z-ENH-007).
class RecapLaunchExtras {
  const RecapLaunchExtras({
    this.newStrengthPrNames = const [],
    this.newCardioPrNames = const [],
  });

  final List<String> newStrengthPrNames;
  final List<String> newCardioPrNames;

  bool get hasNewPrs =>
      newStrengthPrNames.isNotEmpty || newCardioPrNames.isNotEmpty;

  static RecapLaunchExtras? take() {
    final value = _pending;
    _pending = null;
    return value;
  }

  static void stage(RecapLaunchExtras extras) {
    _pending = extras;
  }

  static RecapLaunchExtras? _pending;
}
