import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/block_rule.dart';
import '../models/installed_app.dart';
import 'windows_blocker.dart';

/// Talks to the Kotlin side (installed apps, rule sync, accessibility state).
///
/// Blocking exists on Android (accessibility service) and Windows
/// ([WindowsBlocker]). On other platforms (web, macOS, Linux, used for
/// previewing the UI) every call falls back to harmless sample data.
class NativeBridge {
  NativeBridge._();
  static final instance = NativeBridge._();

  static const _channel = MethodChannel('com.example.block/native');

  bool get isWindows =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<List<InstalledApp>> getInstalledApps() async {
    if (isWindows) {
      return (await WindowsBlocker.instance.installedApps())
        ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    }
    if (!isSupported) return _sampleApps;
    final raw = await _channel.invokeListMethod<Map>('getInstalledApps') ?? [];
    final apps = raw
        .map((m) => InstalledApp(
              packageName: m['package'] as String,
              label: m['label'] as String,
              icon: m['icon'] as Uint8List?,
            ))
        .toList()
      ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    return apps;
  }

  /// Pushes the current rules to the native service, which keeps its own copy
  /// so blocking works even when the Flutter UI isn't running.
  Future<void> syncRules(List<BlockRule> rules) async {
    if (isWindows) return WindowsBlocker.instance.syncRules(rules);
    if (!isSupported) return;
    final json = rules.map((r) => r.toJson()).toList();
    await _channel.invokeMethod('saveRules', {'rules': json});
  }

  /// Android: the accessibility service is on. Windows: we can edit the hosts
  /// file whenever a rule blocks a site (needs administrator rights).
  Future<bool> isBlockingServiceEnabled() async {
    if (isWindows) return !await WindowsBlocker.instance.needsAdmin;
    if (!isSupported) return true;
    return await _channel.invokeMethod<bool>('isServiceEnabled') ?? false;
  }

  /// Android: opens accessibility settings. Windows: restarts as administrator.
  Future<void> openAccessibilitySettings() async {
    if (isWindows) return WindowsBlocker.instance.relaunchAsAdmin();
    if (!isSupported) return;
    await _channel.invokeMethod('openAccessibilitySettings');
  }

  Future<void> openAppInfo() async {
    if (!isSupported) return;
    await _channel.invokeMethod('openAppInfo');
  }
}

const _sampleApps = [
  InstalledApp(packageName: 'com.google.android.youtube', label: 'YouTube'),
  InstalledApp(packageName: 'com.instagram.android', label: 'Instagram'),
  InstalledApp(packageName: 'com.facebook.katana', label: 'Facebook'),
  InstalledApp(packageName: 'com.twitter.android', label: 'X'),
  InstalledApp(packageName: 'com.reddit.frontpage', label: 'Reddit'),
  InstalledApp(packageName: 'com.zhiliaoapp.musically', label: 'TikTok'),
  InstalledApp(packageName: 'com.snapchat.android', label: 'Snapchat'),
  InstalledApp(packageName: 'com.whatsapp', label: 'WhatsApp'),
  InstalledApp(packageName: 'com.netflix.mediaclient', label: 'Netflix'),
  InstalledApp(packageName: 'com.supercell.clashofclans', label: 'Clash of Clans'),
];
