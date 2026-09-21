import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:material_ui/material_ui.dart';
import 'package:neopop/neopop.dart';

import '../theme/tokens.dart';

/// Chunky 3D button from CRED's NeoPOP kit. Presses down into its own shadow.
class NeoButton extends StatelessWidget {
  const NeoButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color = AppColors.white,
    this.textColor = AppColors.bg,
    this.expand = true,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color color;
  final Color textColor;
  final bool expand;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    // bottomRight = the classic NeoPOP look: a hard edge under and beside the
    // face. Left/top edges stay invisible so the button reads as sitting up.
    const clear = Color(0x00000000);
    final button = NeoPopButton(
      color: color,
      buttonPosition: Position.bottomRight,
      parentColor: AppColors.bg,
      grandparentColor: AppColors.bg,
      leftShadowColor: clear,
      topShadowColor: clear,
      depth: compact ? 3 : 5,
      onTapDown: () => HapticFeedback.selectionClick(),
      onTapUp: onPressed == null
          ? null
          : () {
              HapticFeedback.lightImpact();
              onPressed!();
            },
      child: Padding(
        padding: EdgeInsets.symmetric(
            horizontal: compact ? 18 : 24, vertical: compact ? 12 : 19),
        child: Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: compact ? 18 : 22, color: textColor),
              const SizedBox(width: 10),
            ],
            Text(
              label,
              style: AppText.button.copyWith(
                color: textColor,
                fontSize: compact ? 14 : 17,
              ),
            ),
          ],
        ),
      ),
    );

    return button;
  }
}

/// NeoPOP card: a flat face with a hard, thick edge on the right and bottom.
class NeoSurface extends StatelessWidget {
  const NeoSurface({
    super.key,
    required this.child,
    this.color = AppColors.surface,
    this.borderColor = AppColors.line,
    this.depth = 4,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final Color color;
  final Color? borderColor;
  final double depth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(right: depth, bottom: depth),
      child: NeoPopCard(
        color: color,
        depth: depth,
        borderColor: borderColor,
        child: SizedBox(
          width: double.infinity,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Wraps anything tappable with a quick squash + haptic, the way CRED's
/// cards respond under the thumb.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        HapticFeedback.selectionClick();
        _set(true);
      },
      onTapCancel: () => _set(false),
      onTapUp: (_) => _set(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.97 : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Square outlined icon button used for back / close.
class NeoIconButton extends StatelessWidget {
  const NeoIconButton({super.key, required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.line),
        ),
        child: Icon(icon, size: 22, color: AppColors.text),
      ),
    );
  }
}

/// Chunky on/off switch. The thumb springs across, the track floods violet.
class NeoToggle extends StatelessWidget {
  const NeoToggle({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.mediumImpact();
          onChanged(!value);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          width: 56,
          height: 32,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: value ? AppColors.violet : AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
                color: value ? AppColors.violet : AppColors.line, width: 1.5),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 380),
            curve: Curves.elasticOut,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 24,
              decoration: BoxDecoration(
                color: value ? AppColors.white : AppColors.muted,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A dot that breathes, used to say "this is live".
class PulseDot extends StatelessWidget {
  const PulseDot({super.key, this.color = AppColors.coral, this.size = 8});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size * 2.6,
      child: Center(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ).animate(onPlay: (c) => c.repeat()).custom(
              duration: 1400.ms,
              builder: (context, t, child) => Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: size + size * 1.6 * t,
                    height: size + size * 1.6 * t,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withValues(alpha: 0.45 * (1 - t)),
                    ),
                  ),
                  child,
                ],
              ),
            ),
      ),
    );
  }
}

/// Google Pay–style route: the page rises from the bottom while fading in,
/// and sinks back on dismiss.
Future<T?> pushRise<T>(BuildContext context, Widget page) {
  return Navigator.of(context).push<T>(
    PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 420),
      reverseTransitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, _, _) => page,
      transitionsBuilder: (_, animation, secondary, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutQuart,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.06), end: Offset.zero)
                .animate(curved),
            child: child,
          ),
        );
      },
    ),
  );
}
