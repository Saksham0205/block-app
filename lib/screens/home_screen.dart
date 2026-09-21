import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/block_rule.dart';
import '../services/native_bridge.dart';
import '../state/providers.dart';
import '../state/status.dart';
import '../theme/tokens.dart';
import '../widgets/logo_mark.dart';
import '../widgets/neo.dart';
import '../widgets/rule_card.dart';
import '../widgets/status_hero.dart';
import 'rule_editor_screen.dart';

/// Ticks every 15 s so the countdown and "Live" states stay honest.
final _clockProvider = StreamProvider<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream.periodic(const Duration(seconds: 15), (_) => DateTime.now());
});

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  final _confetti = ConfettiController(duration: const Duration(milliseconds: 900));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _confetti.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The user comes back from system settings after enabling the service.
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(serviceEnabledProvider);
    }
  }

  Future<void> _openEditor([BlockRule? rule]) async {
    final saved = await pushRise<bool>(context, RuleEditorScreen(rule: rule));
    if (saved == true && mounted) {
      HapticFeedback.heavyImpact();
      _confetti.play();
    }
  }

  Future<void> _delete(BlockRule rule) async {
    final notifier = ref.read(rulesProvider.notifier);
    HapticFeedback.mediumImpact();
    await notifier.remove(rule.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text('Deleted "${rule.name}"'),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => notifier.upsert(rule),
        ),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final rulesAsync = ref.watch(rulesProvider);
    final now = ref.watch(_clockProvider).value ?? DateTime.now();
    final apps = ref.watch(installedAppsProvider).value ?? const [];
    final appsByPackage = {for (final a in apps) a.packageName: a};
    final rules = rulesAsync.value ?? const <BlockRule>[];
    final status = summarize(rules, now);
    final topInset = MediaQuery.paddingOf(context).top;

    return Scaffold(
      body: Stack(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(20, topInset + 20, 20, 0),
                    sliver: SliverList.list(children: [
                      Row(children: [
                        const LogoMark(size: 46)
                            .animate()
                            .scale(
                                begin: const Offset(0.4, 0.4),
                                duration: 700.ms,
                                curve: Curves.elasticOut)
                            .fadeIn(duration: 200.ms),
                        const SizedBox(width: 12),
                        Text('Block', style: AppText.title),
                      ]),
                      const SizedBox(height: 20),
                      const _ServiceBanner(),
                      StatusHero(status: status, now: now, hasRules: rules.isNotEmpty)
                          .animate()
                          .fadeIn(duration: 500.ms)
                          .slideY(begin: 0.08, curve: Curves.easeOutCubic, duration: 600.ms),
                    ]),
                  ),
                  if (rulesAsync.isLoading && rules.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: CircularProgressIndicator(color: AppColors.violet)),
                    )
                  else if (rules.isEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 28, 20, 140),
                      sliver: SliverToBoxAdapter(child: const _EmptyHint()),
                    )
                  else ...[
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 32, 20, 14),
                      sliver: SliverToBoxAdapter(
                        child: Row(children: [
                          Text('Your blocks', style: AppText.heading),
                          const SizedBox(width: 8),
                          Text('${rules.length}', style: AppText.heading.copyWith(color: AppColors.muted)),
                        ]),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 140),
                      sliver: SliverList.separated(
                        itemCount: rules.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 14),
                        itemBuilder: (context, i) {
                          final rule = rules[i];
                          return Dismissible(
                            key: ValueKey(rule.id),
                            direction: DismissDirection.endToStart,
                            onDismissed: (_) => _delete(rule),
                            background: const _SwipeDeleteBackground(),
                            child: RuleCard(
                              rule: rule,
                              appsByPackage: appsByPackage,
                              activeNow: rule.isActiveAt(now),
                              onTap: () => _openEditor(rule),
                              onToggle: (v) => ref
                                  .read(rulesProvider.notifier)
                                  .toggle(rule.id, v),
                            ),
                          )
                              .animate(delay: (140 + 90 * math.min(i, 5)).ms)
                              .fadeIn(duration: 450.ms)
                              .slideY(begin: 0.12, curve: Curves.easeOutCubic, duration: 550.ms);
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Bottom call to action, fading the list out underneath it.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              ignoring: false,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppColors.bg.withValues(alpha: 0), AppColors.bg],
                    stops: const [0, 0.35],
                  ),
                ),
                padding: EdgeInsets.fromLTRB(
                    20, 36, 20, 16 + MediaQuery.paddingOf(context).bottom),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: NeoButton(
                      label: rules.isEmpty ? 'Create your first block' : 'New block',
                      icon: LucideIcons.plus,
                      onPressed: _openEditor,
                    ),
                  ),
                ),
              ),
            ),
          ),

          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirectionality: BlastDirectionality.explosive,
              emissionFrequency: 0.0,
              numberOfParticles: 28,
              maxBlastForce: 22,
              minBlastForce: 8,
              gravity: 0.22,
              shouldLoop: false,
              colors: const [
                AppColors.violet,
                AppColors.coral,
                AppColors.white,
                Color(0xFFFFD84A),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SwipeDeleteBackground extends StatelessWidget {
  const _SwipeDeleteBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 28),
      margin: const EdgeInsets.only(right: 4, bottom: 4),
      color: AppColors.coral.withValues(alpha: 0.16),
      child: const Icon(LucideIcons.trash2, color: AppColors.coral, size: 26),
    );
  }
}

/// Prompts for the accessibility permission that the blocker needs.
class _ServiceBanner extends ConsumerWidget {
  const _ServiceBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(serviceEnabledProvider).value ?? true;
    if (enabled) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: NeoSurface(
        color: const Color(0xFF2A1A08),
        borderColor: const Color(0xFFFFB020).withValues(alpha: 0.5),
        depth: 4,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(LucideIcons.triangleAlert, color: Color(0xFFFFB020), size: 22),
              const SizedBox(width: 10),
              Text('Blocking is switched off', style: AppText.subheading),
            ]),
            const SizedBox(height: 8),
            Text(
              'Turn on the Block accessibility service so it can tell when a '
              'blocked app or site is opened. Nothing on screen is stored or sent.',
              style: AppText.bodyMuted.copyWith(fontSize: 14),
            ),
            const SizedBox(height: 14),
            Row(children: [
              NeoButton(
                label: 'Turn on',
                compact: true,
                expand: false,
                color: const Color(0xFFFFB020),
                onPressed: NativeBridge.instance.openAccessibilitySettings,
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: NativeBridge.instance.openAppInfo,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text("Can't switch it on?",
                      style: AppText.caption.copyWith(color: AppColors.text)),
                ),
              ),
            ]),
          ],
        ),
      ).animate().fadeIn(duration: 300.ms).shake(hz: 3, duration: 500.ms, delay: 400.ms),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint();

  @override
  Widget build(BuildContext context) {
    Widget step(IconData icon, String title, String body) => Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, size: 22, color: AppColors.violet),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: AppText.subheading),
                const SizedBox(height: 2),
                Text(body, style: AppText.bodyMuted.copyWith(fontSize: 14)),
              ]),
            ),
          ]),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('How it works', style: AppText.heading),
        const SizedBox(height: 18),
        step(LucideIcons.layoutGrid, 'Pick what to block',
            'Choose installed apps, or paste any website link.'),
        step(LucideIcons.clock, 'Set the hours',
            'A daily slot, on the days you choose. Overnight works too.'),
        step(LucideIcons.lockKeyhole, 'Stay out of it',
            'When the slot begins, they are covered until it ends.'),
      ],
    ).animate(delay: 300.ms).fadeIn(duration: 500.ms);
  }
}
