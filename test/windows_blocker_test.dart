import 'package:block/services/windows_blocker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const original = '127.0.0.1 localhost\r\n# my note\r\n';

  test('adds a managed block and keeps existing lines', () {
    final out = withBlockedHosts(original, {'youtube.com'});
    expect(out, startsWith(original.trimRight()));
    expect(out, contains('0.0.0.0 youtube.com'));
    expect(out, contains('0.0.0.0 www.youtube.com'));
    expect(out, contains(hostsBegin));
    expect(out, endsWith('$hostsEnd\r\n'));
  });

  test('is idempotent and replaces the previous block', () {
    final once = withBlockedHosts(original, {'youtube.com'});
    expect(withBlockedHosts(once, {'youtube.com'}), once);
    final swapped = withBlockedHosts(once, {'reddit.com'});
    expect(swapped, isNot(contains('youtube.com')));
    expect(swapped, contains('0.0.0.0 reddit.com'));
  });

  test('no domains removes the block and restores the original', () {
    final once = withBlockedHosts(original, {'youtube.com'});
    expect(withBlockedHosts(once, {}), original);
    expect(withBlockedHosts(original, {}), original);
  });

  test('parses tasklist CSV names', () {
    const out =
        '"Chrome.exe","123","Console","1","10 K"\r\n'
        '"Discord.exe","456","Console","1","20 K"\r\n';
    expect(parseTasklist(out), {'chrome.exe', 'discord.exe'});
  });
}
