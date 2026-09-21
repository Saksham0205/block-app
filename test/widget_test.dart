import 'package:block/models/block_rule.dart';
import 'package:block/state/status.dart';
import 'package:block/utils/url_utils.dart';
import 'package:flutter_test/flutter_test.dart';

BlockRule _rule({
  required int start,
  required int end,
  Set<int> days = const {1, 2, 3, 4, 5},
  bool enabled = true,
}) =>
    BlockRule(
      id: '1',
      name: 't',
      apps: const ['a'],
      domains: const [],
      days: days,
      startMinute: start,
      endMinute: end,
      enabled: enabled,
    );

void main() {
  group('normalizeDomain', () {
    test('strips scheme, www, path, query and port', () {
      expect(normalizeDomain('https://www.YouTube.com/watch?v=1'), 'youtube.com');
      expect(normalizeDomain('m.reddit.com/r/all'), 'm.reddit.com');
      expect(normalizeDomain('http://example.com:8080/x#y'), 'example.com');
    });

    test('rejects non-domains', () {
      expect(normalizeDomain('hello'), isNull);
      expect(normalizeDomain(''), isNull);
      expect(normalizeDomain('two words.com'), isNull);
    });

    test('parseDomains splits and de-duplicates', () {
      expect(
        parseDomains('youtube.com, https://www.youtube.com/x\nreddit.com'),
        ['youtube.com', 'reddit.com'],
      );
    });
  });

  group('BlockRule.isActiveAt', () {
    // 2026-09-21 is a Monday.
    test('daytime slot', () {
      final r = _rule(start: 9 * 60, end: 17 * 60);
      expect(r.isActiveAt(DateTime(2026, 9, 21, 12)), isTrue);
      expect(r.isActiveAt(DateTime(2026, 9, 21, 17)), isFalse);
      expect(r.isActiveAt(DateTime(2026, 9, 26, 12)), isFalse); // Saturday
    });

    test('overnight slot spills into the next morning', () {
      final r = _rule(start: 22 * 60, end: 6 * 60, days: {5}); // Fridays
      expect(r.isActiveAt(DateTime(2026, 9, 25, 23)), isTrue); // Fri night
      expect(r.isActiveAt(DateTime(2026, 9, 26, 5)), isTrue); // Sat morning
      expect(r.isActiveAt(DateTime(2026, 9, 26, 23)), isFalse); // Sat night
    });

    test('start == end means all day', () {
      final r = _rule(start: 0, end: 0);
      expect(r.isActiveAt(DateTime(2026, 9, 21, 3)), isTrue);
      expect(r.isActiveAt(DateTime(2026, 9, 21, 23, 59)), isTrue);
    });

    test('disabled rules never block', () {
      final r = _rule(start: 0, end: 0, enabled: false);
      expect(r.isActiveAt(DateTime(2026, 9, 21, 12)), isFalse);
    });
  });

  group('countdown logic agrees with the blocking logic', () {
    // windowAt drives the hero countdown, isActiveAt mirrors the native
    // service. If they ever disagree the UI would lie about what is blocked.
    for (final rule in [
      _rule(start: 9 * 60, end: 17 * 60),
      _rule(start: 22 * 60, end: 6 * 60, days: {5, 7}),
      _rule(start: 0, end: 0, days: {2}),
      _rule(start: 23 * 60 + 30, end: 30, days: {1, 2, 3, 4, 5, 6, 7}),
    ]) {
      test('rule ${rule.startMinute}-${rule.endMinute} ${rule.days}', () {
        var t = DateTime(2026, 9, 20); // a Sunday, walk a full week
        final stop = t.add(const Duration(days: 8));
        while (t.isBefore(stop)) {
          expect(rule.windowAt(t) != null, rule.isActiveAt(t), reason: '$t');
          t = t.add(const Duration(minutes: 7));
        }
      });
    }

    test('window end and next start', () {
      final r = _rule(start: 22 * 60, end: 6 * 60, days: {5}); // Fridays
      final w = r.windowAt(DateTime(2026, 9, 26, 2))!; // Sat 02:00
      expect(w.start, DateTime(2026, 9, 25, 22));
      expect(w.end, DateTime(2026, 9, 26, 6));
      expect(r.nextStart(DateTime(2026, 9, 26, 2)), DateTime(2026, 10, 2, 22));
    });

    test('summarize picks the soonest end and counts distinct targets', () {
      final a = BlockRule(
        id: 'a', name: 'A', apps: const ['x', 'y'], domains: const ['d.com'],
        days: const {1, 2, 3, 4, 5, 6, 7}, startMinute: 0, endMinute: 12 * 60,
      );
      final b = BlockRule(
        id: 'b', name: 'B', apps: const ['y'], domains: const [],
        days: const {1, 2, 3, 4, 5, 6, 7}, startMinute: 0, endMinute: 10 * 60,
      );
      final s = summarize([a, b], DateTime(2026, 9, 21, 8));
      expect(s.isLive, isTrue);
      expect(s.lockedCount, 3); // x, y, d.com
      expect(s.unlockAt, DateTime(2026, 9, 21, 10));
      expect(formatSpan(const Duration(hours: 1, minutes: 24)), '1h 24m');
    });
  });
}
