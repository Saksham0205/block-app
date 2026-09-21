import '../models/block_rule.dart';

/// Everything the home hero needs, derived from the rules and the clock.
class BlockStatus {
  const BlockStatus({
    required this.liveRules,
    required this.lockedCount,
    this.unlockAt,
    this.progress = 0,
    this.next,
    this.nextStart,
  });

  final List<BlockRule> liveRules;

  /// Distinct apps + sites currently blocked.
  final int lockedCount;

  /// When the earliest-ending live slot finishes.
  final DateTime? unlockAt;

  /// 0…1 through that slot.
  final double progress;

  /// The soonest upcoming rule (when nothing is live).
  final BlockRule? next;
  final DateTime? nextStart;

  bool get isLive => liveRules.isNotEmpty;
}

BlockStatus summarize(List<BlockRule> rules, DateTime now) {
  final live = <BlockRule>[];
  final targets = <String>{};
  DateTime? unlockAt;
  double progress = 0;

  for (final rule in rules) {
    final window = rule.windowAt(now);
    if (window == null) continue;
    live.add(rule);
    targets
      ..addAll(rule.apps)
      ..addAll(rule.domains);
    if (unlockAt == null || window.end.isBefore(unlockAt)) {
      unlockAt = window.end;
      final total = window.end.difference(window.start).inSeconds;
      progress = total == 0
          ? 0
          : (now.difference(window.start).inSeconds / total).clamp(0.0, 1.0);
    }
  }

  BlockRule? next;
  DateTime? nextStart;
  for (final rule in rules) {
    final start = rule.nextStart(now);
    if (start != null && (nextStart == null || start.isBefore(nextStart))) {
      next = rule;
      nextStart = start;
    }
  }

  return BlockStatus(
    liveRules: live,
    lockedCount: targets.length,
    unlockAt: unlockAt,
    progress: progress,
    next: next,
    nextStart: nextStart,
  );
}

/// "1h 24m", "45m", "2d 3h".
String formatSpan(Duration d) {
  if (d.inMinutes < 1) return 'under a minute';
  final days = d.inDays;
  final hours = d.inHours % 24;
  final minutes = d.inMinutes % 60;
  if (days > 0) return hours > 0 ? '${days}d ${hours}h' : '${days}d';
  if (d.inHours > 0) return minutes > 0 ? '${d.inHours}h ${minutes}m' : '${d.inHours}h';
  return '${minutes}m';
}
