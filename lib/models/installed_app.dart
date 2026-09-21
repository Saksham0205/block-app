import 'package:flutter/foundation.dart';

@immutable
class InstalledApp {
  const InstalledApp({
    required this.packageName,
    required this.label,
    this.icon,
  });

  final String packageName;
  final String label;

  /// PNG bytes of the launcher icon, if available.
  final Uint8List? icon;
}
