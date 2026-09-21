import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';

/// The Block logo: an isometric cube with a lock set into its front face and
/// a coral "locked" light on its side. Painted in code so the in-app mark and
/// the launcher icon are the same drawing.
class LogoMark extends StatelessWidget {
  const LogoMark({super.key, this.size = 44});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: LogoPainter(extent: 0.9, glow: false)),
    );
  }
}

class LogoPainter extends CustomPainter {
  const LogoPainter({
    this.extent = 0.7,
    this.glow = true,
    this.monochrome = false,
  });

  /// Height of the cube as a fraction of the canvas.
  final double extent;

  /// Soft violet light pooling under the cube.
  final bool glow;

  /// Single-colour silhouette with the lock cut out (Android themed icons).
  final bool monochrome;

  static const _top = Color(0xFFB7A6FF);
  static const _topDeep = Color(0xFF9A85FF);
  static const _left = Color(0xFF7C5CFF);
  static const _leftDeep = Color(0xFF6244F0);
  static const _right = Color(0xFF4B30C9);
  static const _rightDeep = Color(0xFF34209B);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide * extent / 2; // hexagon radius
    final c = Offset(size.width / 2, size.height / 2);
    Offset p(double x, double y) => c + Offset(x * s, y * s);

    const k = 0.8660254; // cos(30°)
    final t = p(0, -1), ur = p(k, -.5), lr = p(k, .5);
    final b = p(0, 1), ll = p(-k, .5), ul = p(-k, -.5), ctr = p(0, 0);

    Path face(List<Offset> pts) => Path()..addPolygon(pts, true);
    final topFace = face([t, ur, ctr, ul]);
    final leftFace = face([ul, ctr, b, ll]);
    final rightFace = face([ctr, ur, lr, b]);

    if (monochrome) {
      canvas.saveLayer(Offset.zero & size, Paint());
      final white = Paint()..color = const Color(0xFFFFFFFF);
      for (final f in [topFace, leftFace, rightFace]) {
        canvas.drawPath(f, white);
        canvas.drawPath(
          f,
          white
            ..style = PaintingStyle.stroke
            ..strokeWidth = s * 0.06
            ..strokeJoin = StrokeJoin.round,
        );
        white.style = PaintingStyle.fill;
      }
      _withFaceTransform(canvas, ul, Offset(k * s, .5 * s), Offset(0, s), () {
        _lock(canvas, Paint()..blendMode = BlendMode.clear, null);
      });
      canvas.restore();
      return;
    }

    if (glow) {
      canvas.drawOval(
        Rect.fromCenter(center: p(0, 1.16), width: s * 2.1, height: s * .42),
        Paint()
          ..color = AppColors.violet.withValues(alpha: 0.55)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * .16),
      );
    }

    void fillFace(Path f, Color a, Color bColor, Offset from, Offset to) {
      final shader = LinearGradient(colors: [a, bColor])
          .createShader(Rect.fromPoints(from, to));
      canvas.drawPath(f, Paint()..shader = shader);
      // A same-colour round stroke softens the corners so it feels moulded.
      canvas.drawPath(
        f,
        Paint()
          ..shader = shader
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * .07
          ..strokeJoin = StrokeJoin.round,
      );
    }

    fillFace(rightFace, _right, _rightDeep, ur, b);
    fillFace(leftFace, _left, _leftDeep, ul, ll);
    fillFace(topFace, _top, _topDeep, t, ctr);

    // Light catching the edges.
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      Path()
        ..moveTo(ul.dx, ul.dy)
        ..lineTo(t.dx, t.dy)
        ..lineTo(ur.dx, ur.dy),
      edge
        ..strokeWidth = s * .035
        ..color = const Color(0xFFFFFFFF).withValues(alpha: .55),
    );
    canvas.drawLine(
      ul, ctr,
      edge
        ..strokeWidth = s * .03
        ..color = const Color(0xFFFFFFFF).withValues(alpha: .28),
    );
    canvas.drawLine(
      ctr, ur,
      edge
        ..strokeWidth = s * .03
        ..color = const Color(0xFFFFFFFF).withValues(alpha: .16),
    );
    canvas.drawLine(
      ctr, b,
      edge
        ..strokeWidth = s * .04
        ..color = const Color(0xFF1B0F5C).withValues(alpha: .45),
    );

    // Lock, set into the left (front) face.
    _withFaceTransform(canvas, ul, Offset(k * s, .5 * s), Offset(0, s), () {
      // Shadow first so the lock reads as raised off the face.
      canvas.save();
      canvas.translate(.025, .035);
      _lock(canvas, Paint()..color = const Color(0xFF1B0F5C).withValues(alpha: .5), null);
      canvas.restore();
      _lock(canvas, Paint()..color = const Color(0xFFFFFFFF), _leftDeep);
    });

    // The "locked" light on the right face.
    _withFaceTransform(canvas, ctr, Offset(k * s, -.5 * s), Offset(0, s), () {
      canvas.drawCircle(
        const Offset(.5, .26),
        .16,
        Paint()
          ..color = AppColors.coral.withValues(alpha: .7)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, .09),
      );
      canvas.drawCircle(const Offset(.5, .26), .075, Paint()..color = AppColors.coral);
      canvas.drawCircle(
        const Offset(.475, .235),
        .026,
        Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: .85),
      );
    });
  }

  /// Draws in a unit square that is mapped onto a cube face: [origin] is the
  /// face's corner, [xAxis]/[yAxis] are its edge vectors.
  void _withFaceTransform(
      Canvas canvas, Offset origin, Offset xAxis, Offset yAxis, VoidCallback draw) {
    canvas.save();
    canvas.transform(Float64List.fromList([
      xAxis.dx, xAxis.dy, 0, 0, //
      yAxis.dx, yAxis.dy, 0, 0,
      0, 0, 1, 0,
      origin.dx, origin.dy, 0, 1,
    ]));
    draw();
    canvas.restore();
  }

  /// Padlock in unit-square coordinates. [keyhole] is the face colour showing
  /// through the keyhole; null means the caller wants a plain silhouette.
  void _lock(Canvas canvas, Paint paint, Color? keyhole) {
    final fill = Paint()
      ..color = paint.color
      ..blendMode = paint.blendMode;
    final stroke = Paint()
      ..color = paint.color
      ..blendMode = paint.blendMode
      ..style = PaintingStyle.stroke
      ..strokeWidth = .075
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(
      Path()
        ..moveTo(.365, .47)
        ..lineTo(.365, .35)
        ..arcToPoint(const Offset(.635, .35), radius: const Radius.circular(.135))
        ..lineTo(.635, .47),
      stroke,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTRB(.27, .45, .73, .81), const Radius.circular(.07)),
      fill,
    );
    if (keyhole != null) {
      final hole = Paint()..color = keyhole;
      canvas.drawCircle(const Offset(.5, .59), .048, hole);
      canvas.drawPath(
        Path()
          ..moveTo(.482, .6)
          ..lineTo(.518, .6)
          ..lineTo(.53, .71)
          ..lineTo(.47, .71)
          ..close(),
        hole,
      );
    }
  }

  @override
  bool shouldRepaint(LogoPainter old) =>
      old.extent != extent || old.glow != glow || old.monochrome != monochrome;
}

/// Backdrop for the launcher icon: near-black with a violet bloom.
class LogoBackgroundPainter extends CustomPainter {
  const LogoBackgroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = AppColors.bg);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, 0.15),
          radius: 0.75,
          colors: [
            AppColors.violet.withValues(alpha: .38),
            AppColors.violet.withValues(alpha: 0),
          ],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(LogoBackgroundPainter old) => false;
}
