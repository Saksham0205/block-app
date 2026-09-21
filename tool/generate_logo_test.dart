// Renders the launcher-icon PNGs from the LogoMark painter.
// Run:  flutter test tool/generate_logo_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:block/widgets/logo_mark.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const _px = 1024;

Future<void> _render(WidgetTester tester, String path, List<CustomPainter> layers) async {
  await tester.runAsync(() async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    for (final layer in layers) {
      layer.paint(canvas, const ui.Size(1024, 1024));
    }
    final image = await recorder.endRecording().toImage(_px, _px);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  testWidgets('generate logo assets', (tester) async {
    // Full-bleed legacy icon.
    await _render(tester, 'assets/icon/icon.png',
        [const LogoBackgroundPainter(), const LogoPainter(extent: 0.68)]);
    // Adaptive layers: the cube stays inside the 66/108 safe zone.
    await _render(tester, 'assets/icon/background.png', [const LogoBackgroundPainter()]);
    await _render(tester, 'assets/icon/foreground.png', [const LogoPainter(extent: 0.58)]);
    await _render(tester, 'assets/icon/monochrome.png',
        [const LogoPainter(extent: 0.58, glow: false, monochrome: true)]);
    // Preview for humans.
    await _render(tester, 'assets/icon/logo_preview.png',
        [const LogoBackgroundPainter(), const LogoPainter(extent: 0.8)]);
  });
}
