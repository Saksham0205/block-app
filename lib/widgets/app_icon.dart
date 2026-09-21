import 'package:material_ui/material_ui.dart';

import '../models/installed_app.dart';
import '../theme/tokens.dart';

/// Launcher icon for an app, or a letter tile when there isn't one.
class AppIcon extends StatelessWidget {
  const AppIcon({super.key, required this.app, this.size = 40});

  final InstalledApp? app;
  final double size;

  @override
  Widget build(BuildContext context) {
    final icon = app?.icon;
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.28),
      child: SizedBox.square(
        dimension: size,
        child: icon != null
            ? Image.memory(icon, fit: BoxFit.cover, gaplessPlayback: true)
            : ColoredBox(
                color: AppColors.surfaceHigh,
                child: Center(
                  child: Text(
                    (app?.label.isNotEmpty ?? false)
                        ? app!.label[0].toUpperCase()
                        : '?',
                    style: AppText.subheading.copyWith(
                      fontSize: size * 0.45,
                      color: AppColors.violet,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
