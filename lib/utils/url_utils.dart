/// Turns whatever the user pasted into a bare host we can match against.
///
/// `https://www.YouTube.com/watch?v=abc` → `youtube.com`
/// `m.reddit.com/r/all`                  → `m.reddit.com`
///
/// Returns null when the input doesn't look like a domain.
String? normalizeDomain(String input) {
  var value = input.trim().toLowerCase();
  if (value.isEmpty) return null;

  value = value.replaceFirst(RegExp(r'^[a-z][a-z0-9+.-]*://'), '');
  value = value.split(RegExp(r'[/?#]')).first;
  value = value.split('@').last; // strip user:pass@
  value = value.replaceFirst(RegExp(r':\d+$'), ''); // strip port
  value = value.replaceFirst(RegExp(r'^www\.'), '');
  value = value.replaceAll(RegExp(r'\.+$'), '');

  final valid = RegExp(r'^([a-z0-9]([a-z0-9-]*[a-z0-9])?\.)+[a-z]{2,}$');
  return valid.hasMatch(value) ? value : null;
}

/// Splits pasted text (spaces, commas, newlines) into normalised domains.
List<String> parseDomains(String input) {
  final seen = <String>{};
  for (final part in input.split(RegExp(r'[\s,;]+'))) {
    final domain = normalizeDomain(part);
    if (domain != null) seen.add(domain);
  }
  return seen.toList();
}
