import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/installed_app.dart';
import '../state/providers.dart';
import '../theme/tokens.dart';
import '../widgets/app_icon.dart';
import '../widgets/neo.dart';

/// Icon grid of installed apps. Pops with the chosen package names.
class AppPickerScreen extends ConsumerStatefulWidget {
  const AppPickerScreen({super.key, required this.initial});

  final Set<String> initial;

  @override
  ConsumerState<AppPickerScreen> createState() => _AppPickerScreenState();
}

class _AppPickerScreenState extends ConsumerState<AppPickerScreen> {
  late final Set<String> _selected = {...widget.initial};
  String _query = '';

  void _toggle(String pkg) => setState(() {
        if (!_selected.remove(pkg)) _selected.add(pkg);
      });

  @override
  Widget build(BuildContext context) {
    final appsAsync = ref.watch(installedAppsProvider);
    final insets = MediaQuery.paddingOf(context);

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Stack(
            children: [
              Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(20, insets.top + 12, 20, 0),
                    child: Row(children: [
                      NeoIconButton(
                        icon: LucideIcons.arrowLeft,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 16),
                      Text('Choose apps', style: AppText.heading),
                    ]),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: Row(children: [
                        const Icon(LucideIcons.search,
                            size: 20, color: AppColors.muted),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            onChanged: (v) => setState(() => _query = v),
                            style: AppText.body,
                            cursorColor: AppColors.violet,
                            decoration: InputDecoration(
                              hintText: 'Search apps',
                              hintStyle: AppText.bodyMuted,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              filled: false,
                              contentPadding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                      ]),
                    ),
                  ),
                  Expanded(
                    child: appsAsync.when(
                      loading: () => const Center(
                          child: CircularProgressIndicator(color: AppColors.violet)),
                      error: (e, _) => Center(
                          child: Text("Couldn't load apps\n$e",
                              textAlign: TextAlign.center, style: AppText.bodyMuted)),
                      data: (apps) => _grid(apps, insets.bottom),
                    ),
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
                      stops: const [0, 0.35],
                    ),
                  ),
                  padding: EdgeInsets.fromLTRB(20, 32, 20, 16 + insets.bottom),
                  child: NeoButton(
                    label: _selected.isEmpty
                        ? 'Done'
                        : 'Add ${_selected.length} ${_selected.length == 1 ? 'app' : 'apps'}',
                    icon: _selected.isEmpty ? null : LucideIcons.check,
                    onPressed: () => Navigator.of(context).pop(_selected),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _grid(List<InstalledApp> apps, double bottomInset) {
    final q = _query.trim().toLowerCase();
    final visible = q.isEmpty
        ? apps
        : apps.where((a) => a.label.toLowerCase().contains(q)).toList();

    if (visible.isEmpty) {
      return Center(child: Text('No app called "$_query"', style: AppText.bodyMuted));
    }

    return GridView.builder(
      padding: EdgeInsets.fromLTRB(12, 8, 12, 120 + bottomInset),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 6,
        childAspectRatio: 0.74,
      ),
      itemCount: visible.length,
      itemBuilder: (context, i) {
        final app = visible[i];
        return _AppTile(
          app: app,
          selected: _selected.contains(app.packageName),
          onTap: () => _toggle(app.packageName),
        );
      },
    );
  }
}

class _AppTile extends StatelessWidget {
  const _AppTile({required this.app, required this.selected, required this.onTap});

  final InstalledApp app;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          children: [
            const SizedBox(height: 6),
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: selected
                        ? AppColors.violet.withValues(alpha: 0.18)
                        : Colors.transparent,
                    border: Border.all(
                      color: selected ? AppColors.violet : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: AppIcon(app: app, size: 54),
                ),
                Positioned(
                  right: -4,
                  top: -4,
                  child: AnimatedScale(
                    scale: selected ? 1 : 0,
                    duration: const Duration(milliseconds: 380),
                    curve: Curves.elasticOut,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: AppColors.violet,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.bg, width: 2),
                      ),
                      child: const Icon(LucideIcons.check,
                          size: 12, color: AppColors.white),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              app.label,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: AppText.caption.copyWith(
                fontSize: 12,
                height: 1.15,
                color: selected ? AppColors.text : AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 250.ms);
  }
}
