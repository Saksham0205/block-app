import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/block_rule.dart';
import '../state/providers.dart';
import '../theme/tokens.dart';
import '../utils/url_utils.dart';
import '../widgets/app_icon.dart';
import '../widgets/neo.dart';
import '../widgets/rule_card.dart' show splitTime, dayLetters;
import '../widgets/time_wheel_sheet.dart';
import 'app_picker_screen.dart';

const _dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

class RuleEditorScreen extends ConsumerStatefulWidget {
  const RuleEditorScreen({super.key, this.rule});

  /// Null when creating a new rule.
  final BlockRule? rule;

  @override
  ConsumerState<RuleEditorScreen> createState() => _RuleEditorScreenState();
}

class _RuleEditorScreenState extends ConsumerState<RuleEditorScreen> {
  late final TextEditingController _name;
  final _urlController = TextEditingController();

  late List<String> _apps;
  late List<String> _domains;
  late Set<int> _days;
  late int _start;
  late int _end;

  String? _urlError;
  String? _formError;

  bool get _isNew => widget.rule == null;

  @override
  void initState() {
    super.initState();
    final r = widget.rule;
    _name = TextEditingController(text: r?.name ?? '');
    _apps = [...?r?.apps];
    _domains = [...?r?.domains];
    _days = r == null ? {1, 2, 3, 4, 5, 6, 7} : {...r.days};
    _start = r?.startMinute ?? 9 * 60;
    _end = r?.endMinute ?? 17 * 60;
  }

  @override
  void dispose() {
    _name.dispose();
    _urlController.dispose();
    super.dispose();
  }

  void _addDomainsFrom(String text) {
    final parsed = parseDomains(text);
    if (parsed.isEmpty) {
      HapticFeedback.vibrate();
      setState(() => _urlError = "That doesn't look like a website. Try youtube.com");
      return;
    }
    setState(() {
      _urlError = null;
      _formError = null;
      for (final d in parsed) {
        if (!_domains.contains(d)) _domains.add(d);
      }
      _urlController.clear();
    });
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text ?? '';
    if (text.trim().isEmpty) return;
    _addDomainsFrom(text);
  }

  Future<void> _pickApps() async {
    final result = await pushRise<Set<String>>(
      context,
      AppPickerScreen(initial: _apps.toSet()),
    );
    if (result != null) {
      setState(() {
        _apps = result.toList();
        _formError = null;
      });
    }
  }

  Future<void> _pickTime({required bool start}) async {
    final picked = await showTimeWheel(
      context,
      title: start ? 'Block starts at' : 'Block ends at',
      initialMinute: start ? _start : _end,
    );
    if (picked == null) return;
    setState(() => start ? _start = picked : _end = picked);
  }

  Future<void> _save() async {
    // Anything left in the field counts as an intended entry.
    if (_urlController.text.trim().isNotEmpty) {
      _addDomainsFrom(_urlController.text);
      if (_urlError != null) return;
    }
    if (_apps.isEmpty && _domains.isEmpty) {
      HapticFeedback.vibrate();
      setState(() => _formError = 'Add at least one app or website to block.');
      return;
    }
    if (_days.isEmpty) {
      HapticFeedback.vibrate();
      setState(() => _formError = 'Choose at least one day.');
      return;
    }

    final rule = BlockRule(
      id: widget.rule?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: _name.text.trim().isEmpty ? 'Focus time' : _name.text.trim(),
      apps: _apps,
      domains: _domains,
      days: _days,
      startMinute: _start,
      endMinute: _end,
      enabled: widget.rule?.enabled ?? true,
    );
    await ref.read(rulesProvider.notifier).upsert(rule);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final apps = ref.watch(installedAppsProvider).value ?? const [];
    final byPackage = {for (final a in apps) a.packageName: a};
    final insets = MediaQuery.paddingOf(context);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Stack(
            children: [
              ListView(
                padding: EdgeInsets.fromLTRB(20, insets.top + 12, 20, 150 + insets.bottom),
                children: [
                  Row(children: [
                    NeoIconButton(
                      icon: LucideIcons.x,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ]),
                  const SizedBox(height: 22),
                  Text(_isNew ? 'New block' : 'Edit block', style: AppText.title),
                  const SizedBox(height: 18),
                  _nameField(),

                  _Section(
                    title: 'Apps',
                    hint: 'Choose from what is installed on this phone.',
                    child: _appsSection(byPackage),
                  ),
                  _Section(
                    title: 'Websites',
                    hint: 'Paste a link. The whole site is blocked, subdomains included.',
                    child: _websitesSection(),
                  ),
                  _Section(
                    title: 'Time slot',
                    child: _timeSection(context),
                  ),
                  _Section(
                    title: 'Repeat on',
                    hint: _daysSummary(),
                    child: _daysSection(),
                  ),
                ],
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [AppColors.bg.withValues(alpha: 0), AppColors.bg],
                      stops: const [0, 0.3],
                    ),
                  ),
                  padding: EdgeInsets.fromLTRB(20, 36, 20, 16 + insets.bottom),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_formError != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(children: [
                            const Icon(LucideIcons.circleAlert,
                                size: 18, color: AppColors.coral),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(_formError!,
                                  style: AppText.caption.copyWith(color: AppColors.coral)),
                            ),
                          ]).animate(key: ValueKey(_formError)).shakeX(hz: 4, amount: 4, duration: 350.ms),
                        ),
                      NeoButton(
                        label: _isNew ? 'Lock it in' : 'Save changes',
                        icon: LucideIcons.lockKeyhole,
                        onPressed: _save,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Name ─────────────────────────────────────────────────────────────
  Widget _nameField() {
    return TextField(
      controller: _name,
      textCapitalization: TextCapitalization.sentences,
      style: AppText.heading.copyWith(fontSize: 24),
      cursorColor: AppColors.violet,
      decoration: InputDecoration(
        hintText: 'Name this block',
        hintStyle: AppText.heading.copyWith(fontSize: 24, color: AppColors.muted.withValues(alpha: 0.5)),
        filled: false,
        border: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.line, width: 2)),
        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.line, width: 2)),
        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.violet, width: 2)),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }

  // ── Apps ─────────────────────────────────────────────────────────────
  Widget _appsSection(Map<String, dynamic> byPackage) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_apps.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final pkg in _apps)
                  _Tag(
                    key: ValueKey('app-$pkg'),
                    leading: AppIcon(app: byPackage[pkg], size: 24),
                    label: byPackage[pkg]?.label ?? pkg,
                    onRemove: () => setState(() => _apps.remove(pkg)),
                  ),
              ],
            ),
          ),
        NeoButton(
          label: _apps.isEmpty ? 'Choose apps' : 'Change apps',
          icon: LucideIcons.layoutGrid,
          color: AppColors.surfaceHigh,
          textColor: AppColors.text,
          compact: true,
          expand: false,
          onPressed: _pickApps,
        ),
      ],
    );
  }

  // ── Websites ─────────────────────────────────────────────────────────
  Widget _websitesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.only(left: 14, right: 4),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: _urlError != null ? AppColors.coral : AppColors.line,
              width: _urlError != null ? 1.5 : 1,
            ),
          ),
          child: Row(children: [
            const Icon(LucideIcons.globe, size: 20, color: AppColors.muted),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _urlController,
                keyboardType: TextInputType.url,
                autocorrect: false,
                textInputAction: TextInputAction.done,
                onSubmitted: _addDomainsFrom,
                onChanged: (_) {
                  if (_urlError != null) setState(() => _urlError = null);
                },
                style: AppText.body,
                cursorColor: AppColors.violet,
                decoration: InputDecoration(
                  hintText: 'Paste a link, e.g. youtube.com',
                  hintStyle: AppText.bodyMuted.copyWith(color: AppColors.muted.withValues(alpha: 0.6)),
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            _FieldAction(icon: LucideIcons.clipboardPaste, tooltip: 'Paste', onTap: _paste),
            _FieldAction(
              icon: LucideIcons.plus,
              tooltip: 'Add',
              filled: true,
              onTap: () => _addDomainsFrom(_urlController.text),
            ),
          ]),
        ),
        if (_urlError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_urlError!, style: AppText.caption.copyWith(color: AppColors.coral)),
          ),
        if (_domains.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final d in _domains)
                  _Tag(
                    key: ValueKey('site-$d'),
                    leading: const Icon(LucideIcons.globe, size: 18, color: AppColors.violet),
                    label: d,
                    onRemove: () => setState(() => _domains.remove(d)),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  // ── Time ─────────────────────────────────────────────────────────────
  Widget _timeSection(BuildContext context) {
    final allDay = _start == _end;
    final overnight = _end < _start;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: _TimeTile(label: 'From', minute: _start, onTap: () => _pickTime(start: true))),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Icon(LucideIcons.arrowRight, size: 20, color: AppColors.muted),
            ),
            Expanded(child: _TimeTile(label: 'Until', minute: _end, onTap: () => _pickTime(start: false))),
          ],
        ),
        const SizedBox(height: 10),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Text(
            allDay
                ? 'Blocked for the whole day.'
                : overnight
                    ? 'Runs overnight and ends the next morning.'
                    : 'Blocked between these two times.',
            key: ValueKey('$allDay$overnight'),
            style: AppText.caption,
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Pill(
              label: 'Work 9 to 5',
              selected: _start == 9 * 60 && _end == 17 * 60,
              onTap: () => setState(() {
                _start = 9 * 60;
                _end = 17 * 60;
              }),
            ),
            _Pill(
              label: 'Bedtime 10 PM to 6 AM',
              selected: _start == 22 * 60 && _end == 6 * 60,
              onTap: () => setState(() {
                _start = 22 * 60;
                _end = 6 * 60;
              }),
            ),
            _Pill(
              label: 'All day',
              selected: allDay,
              onTap: () => setState(() {
                _start = 0;
                _end = 0;
              }),
            ),
          ],
        ),
      ],
    );
  }

  // ── Days ─────────────────────────────────────────────────────────────
  String _daysSummary() {
    if (_days.length == 7) return 'Every day';
    if (_days.isEmpty) return 'No days selected';
    if (_days.length == 5 && !_days.contains(6) && !_days.contains(7)) return 'Weekdays';
    if (_days.length == 2 && _days.containsAll({6, 7})) return 'Weekends';
    final sorted = _days.toList()..sort();
    return sorted.map((d) => _dayNames[d - 1].substring(0, 3)).join(', ');
  }

  Widget _daysSection() {
    return Row(
      children: [
        for (var i = 0; i < 7; i++) ...[
          Expanded(
            child: _DayToggle(
              letter: dayLetters[i],
              selected: _days.contains(i + 1),
              label: _dayNames[i],
              onTap: () => setState(() {
                _formError = null;
                if (!_days.remove(i + 1)) _days.add(i + 1);
              }),
            ),
          ),
          if (i < 6) const SizedBox(width: 7),
        ],
      ],
    );
  }
}

// ───────────────────────── small building blocks ─────────────────────────

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.hint});

  final String title;
  final String? hint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 34),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppText.heading),
          if (hint != null) ...[
            const SizedBox(height: 4),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(hint!, key: ValueKey(hint), style: AppText.caption),
            ),
          ],
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({super.key, required this.leading, required this.label, required this.onRemove});

  final Widget leading;
  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 4, 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        leading,
        const SizedBox(width: 8),
        Flexible(
          child: Text(label,
              style: AppText.subheading.copyWith(fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ),
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onRemove();
          },
          behavior: HitTestBehavior.opaque,
          child: const Padding(
            padding: EdgeInsets.all(6),
            child: Icon(LucideIcons.x, size: 14, color: AppColors.muted),
          ),
        ),
      ]),
    ).animate().scale(begin: const Offset(0.85, 0.85), duration: 300.ms, curve: Curves.easeOutBack).fadeIn(duration: 200.ms);
  }
}

class _FieldAction extends StatelessWidget {
  const _FieldAction({required this.icon, required this.tooltip, required this.onTap, this.filled = false});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 44,
          height: 44,
          margin: const EdgeInsets.only(left: 2),
          decoration: BoxDecoration(
            color: filled ? AppColors.violet : Colors.transparent,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Icon(icon, size: 20, color: filled ? AppColors.white : AppColors.text),
        ),
      ),
    );
  }
}

class _TimeTile extends StatelessWidget {
  const _TimeTile({required this.label, required this.minute, required this.onTap});

  final String label;
  final int minute;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = splitTime(context, TimeOfDay(hour: minute ~/ 60, minute: minute % 60));
    return Pressable(
      onTap: onTap,
      child: NeoSurface(
        depth: 4,
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppText.caption),
            const SizedBox(height: 6),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween(begin: const Offset(0, 0.25), end: Offset.zero).animate(anim),
                  child: child,
                ),
              ),
              child: Text.rich(
                key: ValueKey(minute),
                TextSpan(children: [
                  TextSpan(text: t.time, style: AppText.numeral.copyWith(fontSize: 28)),
                  if (t.period.isNotEmpty)
                    TextSpan(text: ' ${t.period}', style: AppText.caption.copyWith(fontSize: 13)),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.violet.withValues(alpha: 0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: selected ? AppColors.violet : AppColors.line, width: 1.5),
        ),
        child: Text(
          label,
          style: AppText.caption.copyWith(
            color: selected ? AppColors.text : AppColors.muted,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _DayToggle extends StatelessWidget {
  const _DayToggle({required this.letter, required this.selected, required this.label, required this.onTap});

  final String letter;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      selected: selected,
      button: true,
      child: Pressable(
        onTap: onTap,
        child: AspectRatio(
          aspectRatio: 0.82,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? AppColors.violet : AppColors.surface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: selected ? AppColors.violet : AppColors.line, width: 1.5),
            ),
            child: AnimatedScale(
              scale: selected ? 1.12 : 1,
              duration: const Duration(milliseconds: 380),
              curve: Curves.elasticOut,
              child: Text(
                letter,
                style: AppText.subheading.copyWith(
                  color: selected ? AppColors.white : AppColors.muted,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
