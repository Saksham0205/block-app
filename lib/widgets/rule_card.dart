import 'package:material_ui/material_ui.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/block_rule.dart';
import '../models/installed_app.dart';
import '../theme/tokens.dart';
import 'app_icon.dart';
import 'neo.dart';

const dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

/// "10:00 PM" split into the numerals and the period, for big type.
({String time, String period}) splitTime(BuildContext context, TimeOfDay t) {
  final text = MaterialLocalizations.of(context).formatTimeOfDay(t);
  final match = RegExp(r'^(.*?)\s*([AaPp][Mm])$').firstMatch(text);
  if (match == null) return (time: text, period: '');
  return (time: match.group(1)!, period: match.group(2)!.toUpperCase());
}

class RuleCard extends StatelessWidget {
  const RuleCard({
    super.key,
    required this.rule,
    required this.appsByPackage,
    required this.activeNow,
    required this.onTap,
    required this.onToggle,
  });

  final BlockRule rule;
  final Map<String, InstalledApp> appsByPackage;
  final bool activeNow;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final dimmed = !rule.enabled;

    return Pressable(
      onTap: onTap,
      child: NeoSurface(
        color: activeNow ? const Color(0xFF1E1114) : AppColors.surface,
        borderColor:
            activeNow ? AppColors.coral.withValues(alpha: 0.55) : AppColors.line,
        depth: 4,
        padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 250),
          opacity: dimmed ? 0.45 : 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Row(children: [
                      Flexible(
                        child: Text(rule.name,
                            style: AppText.heading,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (activeNow) ...[
                        const SizedBox(width: 6),
                        const PulseDot(size: 7),
                        Text('Live',
                            style: AppText.caption
                                .copyWith(color: AppColors.coral)),
                      ],
                    ]),
                  ),
                  NeoToggle(value: rule.enabled, onChanged: onToggle),
                ],
              ),
              const SizedBox(height: 14),
              _TimeRange(rule: rule),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: _Targets(rule: rule, appsByPackage: appsByPackage)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  for (var i = 0; i < 7; i++) ...[
                    _DayBox(
                      letter: dayLetters[i],
                      selected: rule.days.contains(i + 1),
                    ),
                    if (i < 6) const SizedBox(width: 6),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimeRange extends StatelessWidget {
  const _TimeRange({required this.rule});

  final BlockRule rule;

  @override
  Widget build(BuildContext context) {
    if (rule.startMinute == rule.endMinute) {
      return Text('All day', style: AppText.numeral);
    }
    final s = splitTime(context, rule.start);
    final e = splitTime(context, rule.end);
    Widget time(({String time, String period}) t) => Text.rich(TextSpan(children: [
          TextSpan(text: t.time, style: AppText.numeral),
          if (t.period.isNotEmpty)
            TextSpan(
                text: ' ${t.period}',
                style: AppText.caption.copyWith(fontSize: 14)),
        ]));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        time(s),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10),
          child: Icon(LucideIcons.arrowRight, size: 18, color: AppColors.muted),
        ),
        time(e),
        if (rule.isOvernight) ...[
          const SizedBox(width: 8),
          Text('+1 day', style: AppText.caption.copyWith(color: AppColors.violet)),
        ],
      ],
    );
  }
}

class _Targets extends StatelessWidget {
  const _Targets({required this.rule, required this.appsByPackage});

  final BlockRule rule;
  final Map<String, InstalledApp> appsByPackage;

  @override
  Widget build(BuildContext context) {
    const maxIcons = 5;
    const size = 34.0;
    const overlap = 10.0;
    final shown = rule.apps.take(maxIcons).toList();
    final extra = rule.apps.length - shown.length;

    return Row(
      children: [
        if (shown.isNotEmpty)
          SizedBox(
            height: size,
            width: size + (shown.length - 1) * (size - overlap),
            child: Stack(
              children: [
                for (var i = 0; i < shown.length; i++)
                  Positioned(
                    left: i * (size - overlap),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(size * 0.32),
                        border: Border.all(color: AppColors.surface, width: 2),
                      ),
                      child: AppIcon(app: appsByPackage[shown[i]], size: size - 4),
                    ),
                  ),
              ],
            ),
          ),
        if (extra > 0) ...[
          const SizedBox(width: 8),
          Text('+$extra', style: AppText.caption),
        ],
        if (rule.domains.isNotEmpty) ...[
          if (shown.isNotEmpty) const SizedBox(width: 12),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(LucideIcons.globe, size: 15, color: AppColors.muted),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    rule.domains.length == 1
                        ? rule.domains.first
                        : '${rule.domains.first} +${rule.domains.length - 1}',
                    style: AppText.caption.copyWith(color: AppColors.text),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ]),
            ),
          ),
        ],
      ],
    );
  }
}

class _DayBox extends StatelessWidget {
  const _DayBox({required this.letter, required this.selected});

  final String letter;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? AppColors.violet.withValues(alpha: 0.16) : Colors.transparent,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
            color: selected ? AppColors.violet.withValues(alpha: 0.7) : AppColors.line),
      ),
      child: Text(
        letter,
        style: AppText.caption.copyWith(
          color: selected ? AppColors.text : AppColors.muted.withValues(alpha: 0.6),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
