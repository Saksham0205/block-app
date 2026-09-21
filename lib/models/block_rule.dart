import 'package:material_ui/material_ui.dart';

/// A single "block these apps / sites during this time slot" rule.
@immutable
class BlockRule {
  const BlockRule({
    required this.id,
    required this.name,
    required this.apps,
    required this.domains,
    required this.days,
    required this.startMinute,
    required this.endMinute,
    this.enabled = true,
  });

  final String id;
  final String name;

  /// Android package names.
  final List<String> apps;

  /// Normalised hosts, e.g. `youtube.com`.
  final List<String> domains;

  /// ISO weekdays, 1 = Monday … 7 = Sunday.
  final Set<int> days;

  /// Minutes since midnight.
  final int startMinute;
  final int endMinute;
  final bool enabled;

  TimeOfDay get start => TimeOfDay(hour: startMinute ~/ 60, minute: startMinute % 60);
  TimeOfDay get end => TimeOfDay(hour: endMinute ~/ 60, minute: endMinute % 60);

  /// The slot runs past midnight (e.g. 22:00 → 06:00).
  bool get isOvernight => endMinute <= startMinute;

  int get targetCount => apps.length + domains.length;

  BlockRule copyWith({
    String? name,
    List<String>? apps,
    List<String>? domains,
    Set<int>? days,
    int? startMinute,
    int? endMinute,
    bool? enabled,
  }) {
    return BlockRule(
      id: id,
      name: name ?? this.name,
      apps: apps ?? this.apps,
      domains: domains ?? this.domains,
      days: days ?? this.days,
      startMinute: startMinute ?? this.startMinute,
      endMinute: endMinute ?? this.endMinute,
      enabled: enabled ?? this.enabled,
    );
  }

  /// Whether the rule is blocking at [now]. Mirrors `BlockRule.isActive` in
  /// the Kotlin service so the UI can show a live "Blocking now" state.
  bool isActiveAt(DateTime now) {
    if (!enabled) return false;
    final minute = now.hour * 60 + now.minute;
    if (!isOvernight) {
      return days.contains(now.weekday) &&
          minute >= startMinute &&
          minute < endMinute;
    }
    // Overnight: the evening part belongs to the start day, the morning part
    // to the day after it.
    if (minute >= startMinute) return days.contains(now.weekday);
    if (minute < endMinute) {
      final previous = now.weekday == 1 ? 7 : now.weekday - 1;
      return days.contains(previous);
    }
    return false;
  }

  /// How long one occurrence of the slot lasts (start == end means 24 h).
  Duration get length => Duration(
      minutes: endMinute > startMinute
          ? endMinute - startMinute
          : 24 * 60 - startMinute + endMinute);

  DateTime _startOn(DateTime now, int dayOffset) => DateTime(
      now.year, now.month, now.day + dayOffset, startMinute ~/ 60, startMinute % 60);

  /// The occurrence covering [now], if the rule is enabled and blocking.
  ({DateTime start, DateTime end})? windowAt(DateTime now) {
    if (!enabled) return null;
    for (final offset in const [-1, 0]) {
      final start = _startOn(now, offset);
      final end = start.add(length);
      if (days.contains(start.weekday) && !now.isBefore(start) && now.isBefore(end)) {
        return (start: start, end: end);
      }
    }
    return null;
  }

  /// The next time this rule starts blocking, after [now].
  DateTime? nextStart(DateTime now) {
    if (!enabled || days.isEmpty) return null;
    for (var offset = 0; offset <= 7; offset++) {
      final start = _startOn(now, offset);
      if (days.contains(start.weekday) && start.isAfter(now)) return start;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'apps': apps,
        'domains': domains,
        'days': days.toList()..sort(),
        'startMinute': startMinute,
        'endMinute': endMinute,
        'enabled': enabled,
      };

  factory BlockRule.fromJson(Map<String, dynamic> json) {
    return BlockRule(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      apps: List<String>.from(json['apps'] as List? ?? const []),
      domains: List<String>.from(json['domains'] as List? ?? const []),
      days: Set<int>.from(json['days'] as List? ?? const [1, 2, 3, 4, 5, 6, 7]),
      startMinute: json['startMinute'] as int? ?? 9 * 60,
      endMinute: json['endMinute'] as int? ?? 17 * 60,
      enabled: json['enabled'] as bool? ?? true,
    );
  }
}
