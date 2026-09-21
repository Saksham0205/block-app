import 'dart:math' as math;

import 'package:flutter_animate/flutter_animate.dart';
import 'package:material_ui/material_ui.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../state/status.dart';
import '../theme/tokens.dart';
import 'neo.dart';

/// The one loud element on the home screen: what is locked right now, and
/// for how long. Everything else stays quiet around it.
class StatusHero extends StatelessWidget {
  const StatusHero({
    super.key,
    required this.status,
    required this.now,
    required this.hasRules,
  });

  final BlockStatus status;
  final DateTime now;
  final bool hasRules;

  @override
  Widget build(BuildContext context) {
    final live = status.isLive;
    final accent = live ? AppColors.coral : AppColors.violet;

    return NeoSurface(
      color: live ? const Color(0xFF1E1114) : AppColors.surface,
      borderColor: live ? AppColors.coral.withValues(alpha: 0.55) : AppColors.line,
      depth: 6,
      padding: const EdgeInsets.fromLTRB(22, 22, 18, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: live ? _liveHeadline(context) : _idleHeadline(context),
              ),
              const SizedBox(width: 12),
              _Ring(
                progress: live ? status.progress : 0,
                color: accent,
                live: live,
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (live) _liveFooter(context) else _idleFooter(context),
        ],
      ),
    );
  }

  Widget _liveHeadline(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const PulseDot(),
          const SizedBox(width: 6),
          Text('Locked right now', style: AppText.caption.copyWith(color: AppColors.coral)),
        ]),
        const SizedBox(height: 8),
        TweenAnimationBuilder<double>(
          tween: Tween(end: status.lockedCount.toDouble()),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutExpo,
          builder: (_, value, _) =>
              Text(value.round().toString(), style: AppText.display),
        ),
        Text(
          status.lockedCount == 1 ? 'app or site off-limits' : 'apps and sites off-limits',
          style: AppText.bodyMuted,
        ),
      ],
    );
  }

  Widget _idleHeadline(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 6),
        Text(hasRules ? 'All clear' : 'Own your screen time',
            style: AppText.title.copyWith(fontSize: hasRules ? 40 : 30)),
        const SizedBox(height: 6),
        Text(
          hasRules
              ? 'Nothing is blocked at the moment.'
              : 'Lock distracting apps and sites for the hours you choose.',
          style: AppText.bodyMuted,
        ),
      ],
    );
  }

  Widget _liveFooter(BuildContext context) {
    final left = status.unlockAt!.difference(now);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: SizedBox(
            height: 5,
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: status.progress),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 5,
                backgroundColor: AppColors.white.withValues(alpha: 0.08),
                valueColor: const AlwaysStoppedAnimation(AppColors.coral),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text.rich(TextSpan(children: [
          TextSpan(text: 'Unlocks in ', style: AppText.bodyMuted),
          TextSpan(
              text: formatSpan(left),
              style: AppText.subheading.copyWith(color: AppColors.text)),
        ])),
      ],
    );
  }

  Widget _idleFooter(BuildContext context) {
    final next = status.next;
    if (next == null) return const SizedBox.shrink();
    final until = status.nextStart!.difference(now);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(children: [
        const Icon(LucideIcons.timer, size: 20, color: AppColors.violet),
        const SizedBox(width: 10),
        Expanded(
          child: Text.rich(
            TextSpan(children: [
              TextSpan(text: next.name, style: AppText.subheading.copyWith(fontSize: 15)),
              TextSpan(text: '  starts in ${formatSpan(until)}', style: AppText.bodyMuted.copyWith(fontSize: 14)),
            ]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ]),
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({required this.progress, required this.color, required this.live});

  final double progress;
  final Color color;
  final bool live;

  @override
  Widget build(BuildContext context) {
    Widget ring = SizedBox.square(
      dimension: 92,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: progress),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (_, value, child) => CustomPaint(
          painter: _RingPainter(value, color),
          child: child,
        ),
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            switchInCurve: Curves.easeOutBack,
            transitionBuilder: (child, anim) =>
                ScaleTransition(scale: anim, child: FadeTransition(opacity: anim, child: child)),
            child: Icon(
              live ? LucideIcons.lockKeyhole : LucideIcons.shieldCheck,
              key: ValueKey(live),
              size: 34,
              color: color,
            ),
          ),
        ),
      ),
    );

    if (live) {
      ring = ring
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scale(
            begin: const Offset(1, 1),
            end: const Offset(1.04, 1.04),
            duration: 1600.ms,
            curve: Curves.easeInOut,
          );
    }
    return ring;
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.progress, this.color);

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 7.0;
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2);

    canvas.drawArc(
      arcRect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = AppColors.white.withValues(alpha: 0.07),
    );

    if (progress <= 0) return;
    canvas.drawArc(
      arcRect,
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.butt
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}
