import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/block_rule.dart';
import '../models/installed_app.dart';

const hostsBegin = '# >>> Block app (managed, do not edit) >>>';
const hostsEnd = '# <<< Block app (managed, do not edit) <<<';

/// Subdomains worth listing next to a blocked domain: the hosts file has no
/// wildcards, so these are the ones people actually land on.
const _hostPrefixes = ['', 'www.', 'm.', 'mobile.'];

/// Processes that must never be closed, whatever a rule says.
const _protectedProcesses = {
  'explorer.exe',
  'svchost.exe',
  'winlogon.exe',
  'csrss.exe',
  'lsass.exe',
  'services.exe',
  'dwm.exe',
  'system',
};

final _hostsPath =
    '${Platform.environment['SystemRoot'] ?? r'C:\Windows'}\\System32\\drivers\\etc\\hosts';

/// Returns [hosts] with the managed block replaced by one that sends every
/// domain in [domains] nowhere. Lines outside the block are left untouched,
/// and an empty [domains] removes the block entirely.
String withBlockedHosts(String hosts, Iterable<String> domains) {
  final kept = <String>[];
  var inside = false;
  for (final line in hosts.split(RegExp(r'\r?\n'))) {
    final trimmed = line.trim();
    if (trimmed == hostsBegin) {
      inside = true;
    } else if (trimmed == hostsEnd) {
      inside = false;
    } else if (!inside) {
      kept.add(line);
    }
  }
  while (kept.isNotEmpty && kept.last.trim().isEmpty) {
    kept.removeLast();
  }

  final sorted = domains.toSet().toList()..sort();
  if (sorted.isEmpty) return kept.isEmpty ? '' : '${kept.join('\r\n')}\r\n';

  return [
    ...kept,
    if (kept.isNotEmpty) '',
    hostsBegin,
    for (final domain in sorted)
      for (final prefix in _hostPrefixes) ...[
        '0.0.0.0 $prefix$domain',
        ':: $prefix$domain',
      ],
    hostsEnd,
    '',
  ].join('\r\n');
}

/// Image names out of `tasklist /FO CSV /NH`, lower-cased.
Set<String> parseTasklist(String output) {
  final names = <String>{};
  for (final line in const LineSplitter().convert(output)) {
    final match = RegExp(r'^"([^"]+)"').firstMatch(line);
    if (match != null) names.add(match.group(1)!.toLowerCase());
  }
  return names;
}

/// Blocking on Windows.
///
/// Apps are closed as soon as they're running during an active slot. Sites
/// are pointed at nowhere in the system `hosts` file, which every browser
/// honours but Windows only lets administrators edit. Both are enforced from
/// here, so the Block window has to be open (minimised is fine).
class WindowsBlocker {
  WindowsBlocker._();
  static final instance = WindowsBlocker._();

  static const _tick = Duration(seconds: 3);

  List<BlockRule> _rules = const [];
  Timer? _timer;
  bool _busy = false;

  /// Domains currently written to the hosts file; null until first synced.
  Set<String>? _applied;
  bool? _isAdmin;

  final _ownExe = Platform.resolvedExecutable.split(r'\').last.toLowerCase();

  /// Sites can only be blocked when we're allowed to write the hosts file.
  Future<bool> get isAdmin async => _isAdmin ??= await _canWriteHosts();

  /// True when a rule needs the hosts file but we can't write it.
  Future<bool> get needsAdmin async =>
      _rules.any((r) => r.enabled && r.domains.isNotEmpty) && !await isAdmin;

  Future<bool> _canWriteHosts() async {
    try {
      // Appending nothing: succeeds only with write access.
      final handle = await File(_hostsPath).open(mode: FileMode.append);
      await handle.close();
      return true;
    } on FileSystemException {
      return false;
    }
  }

  /// Takes the latest rules and starts (or keeps) the enforcement loop.
  void syncRules(List<BlockRule> rules) {
    _rules = rules;
    _timer ??= Timer.periodic(_tick, (_) => _enforce());
    unawaited(_enforce());
  }

  Future<void> _enforce() async {
    if (_busy) return;
    _busy = true;
    try {
      final now = DateTime.now();
      final active = _rules.where((r) => r.isActiveAt(now)).toList();
      final apps =
          {for (final r in active) ...r.apps.map((a) => a.toLowerCase())}
            ..removeAll(_protectedProcesses)
            ..remove(_ownExe);
      final domains = {for (final r in active) ...r.domains};

      if (apps.isNotEmpty) await _closeRunning(apps);
      await _syncHosts(domains);
    } catch (e) {
      debugPrint('Block: enforcement pass failed: $e');
    } finally {
      _busy = false;
    }
  }

  Future<void> _closeRunning(Set<String> apps) async {
    final result = await Process.run('tasklist', ['/FO', 'CSV', '/NH']);
    if (result.exitCode != 0) return;
    for (final name in parseTasklist(
      result.stdout as String,
    ).intersection(apps)) {
      await Process.run('taskkill', ['/F', '/T', '/IM', name]);
    }
  }

  Future<void> _syncHosts(Set<String> domains) async {
    final applied = _applied;
    if (applied != null &&
        applied.length == domains.length &&
        applied.containsAll(domains)) {
      return;
    }
    final file = File(_hostsPath);
    try {
      final current = utf8.decode(
        await file.readAsBytes(),
        allowMalformed: true,
      );
      final updated = withBlockedHosts(current, domains);
      if (updated != current) {
        await file.writeAsString(updated);
        await Process.run('ipconfig', ['/flushdns']);
      }
      _applied = {...domains};
    } on FileSystemException {
      // Not elevated: leave _applied unset so we retry, e.g. after a restart
      // as administrator.
      _isAdmin = false;
    }
  }

  /// Every app with a Start menu shortcut, keyed by its `.exe` name.
  Future<List<InstalledApp>> installedApps() async {
    const script = r'''
$ErrorActionPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Add-Type -AssemblyName System.Drawing
$shell = New-Object -ComObject WScript.Shell
$roots = @("$env:ProgramData\Microsoft\Windows\Start Menu\Programs", "$env:APPDATA\Microsoft\Windows\Start Menu\Programs")
$seen = @{}
$out = @()
foreach ($root in $roots) {
  Get-ChildItem -Path $root -Filter *.lnk -Recurse | ForEach-Object {
    if ($_.BaseName -match 'uninstall') { return }
    $link = $shell.CreateShortcut($_.FullName)
    $target = $link.TargetPath
    if (-not $target -or -not $target.ToLower().EndsWith('.exe')) { return }
    $exe = [System.IO.Path]::GetFileName($target).ToLower()
    # Squirrel apps (Discord, Slack, Teams) launch through Update.exe.
    if ($link.Arguments -match '--processStart[= ]"?([^"\s]+\.exe)') { $exe = $Matches[1].ToLower() }
    if ($seen.ContainsKey($exe)) { return }
    $seen[$exe] = $true
    $icon = $null
    try {
      $ms = New-Object System.IO.MemoryStream
      [System.Drawing.Icon]::ExtractAssociatedIcon($target).ToBitmap().Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
      $icon = [Convert]::ToBase64String($ms.ToArray())
    } catch {}
    $out += [pscustomobject]@{ package = $exe; label = $_.BaseName; icon = $icon }
  }
}
ConvertTo-Json -InputObject @($out) -Compress
''';
    // -EncodedCommand takes base64 of UTF-16LE, which sidesteps all quoting.
    final encoded = base64.encode(
      Uint8List.fromList([
        for (final unit in script.codeUnits) ...[unit & 0xff, unit >> 8],
      ]),
    );
    final result = await Process.run('powershell', [
      '-NoProfile',
      '-NonInteractive',
      '-EncodedCommand',
      encoded,
    ], stdoutEncoding: utf8);
    if (result.exitCode != 0) return const [];

    final decoded = jsonDecode((result.stdout as String).trim()) as List;
    return [
      for (final m in decoded)
        if ((m['package'] as String) != _ownExe)
          InstalledApp(
            packageName: m['package'] as String,
            label: m['label'] as String,
            icon: m['icon'] == null ? null : base64.decode(m['icon'] as String),
          ),
    ];
  }

  /// Reopens Block with administrator rights (UAC prompt) and closes this
  /// copy. Does nothing if the prompt is declined.
  Future<void> relaunchAsAdmin() async {
    final exe = Platform.resolvedExecutable.replaceAll("'", "''");
    final result = await Process.run('powershell', [
      '-NoProfile',
      '-Command',
      "Start-Process -FilePath '$exe' -Verb RunAs",
    ]);
    if (result.exitCode == 0) exit(0);
  }
}
