import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';
import 'neo.dart';

/// Bottom sheet with three snapping wheels (hour, minute, AM/PM).
/// Resolves to minutes since midnight, or null if dismissed.
Future<int?> showTimeWheel(
  BuildContext context, {
  required String title,
  required int initialMinute,
}) {
  return showModalBottomSheet<int>(
    context: context,
    backgroundColor: AppColors.surface,
    barrierColor: Colors.black.withValues(alpha: 0.7),
    showDragHandle: false,
    builder: (_) => _TimeWheelSheet(title: title, initialMinute: initialMinute),
  );
}

class _TimeWheelSheet extends StatefulWidget {
  const _TimeWheelSheet({required this.title, required this.initialMinute});

  final String title;
  final int initialMinute;

  @override
  State<_TimeWheelSheet> createState() => _TimeWheelSheetState();
}

class _TimeWheelSheetState extends State<_TimeWheelSheet> {
  static const _extent = 58.0;

  late int _hour; // index 0..11 → 1..12
  late int _minute; // 0..59
  late int _period; // 0 = AM, 1 = PM

  late final FixedExtentScrollController _hourCtrl;
  late final FixedExtentScrollController _minuteCtrl;
  late final FixedExtentScrollController _periodCtrl;

  @override
  void initState() {
    super.initState();
    final h24 = widget.initialMinute ~/ 60;
    _minute = widget.initialMinute % 60;
    _period = h24 >= 12 ? 1 : 0;
    final h12 = h24 % 12 == 0 ? 12 : h24 % 12;
    _hour = h12 - 1;
    _hourCtrl = FixedExtentScrollController(initialItem: _hour);
    _minuteCtrl = FixedExtentScrollController(initialItem: _minute);
    _periodCtrl = FixedExtentScrollController(initialItem: _period);
  }

  @override
  void dispose() {
    _hourCtrl.dispose();
    _minuteCtrl.dispose();
    _periodCtrl.dispose();
    super.dispose();
  }

  int get _result {
    final h12 = _hour + 1; // 1..12
    final h24 = (h12 % 12) + (_period == 1 ? 12 : 0);
    return h24 * 60 + _minute;
  }

  Widget _wheel({
    required FixedExtentScrollController controller,
    required List<String> labels,
    required int selected,
    required ValueChanged<int> onChanged,
    bool loop = true,
    double width = 84,
  }) {
    final children = [
      for (var i = 0; i < labels.length; i++)
        Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 160),
            style: i == selected
                ? AppText.numeral.copyWith(fontSize: 40)
                : AppText.numeral.copyWith(fontSize: 28, color: AppColors.muted.withValues(alpha: 0.6)),
            child: Text(labels[i]),
          ),
        ),
    ];
    return SizedBox(
      width: width,
      child: ListWheelScrollView.useDelegate(
        controller: controller,
        itemExtent: _extent,
        perspective: 0.004,
        diameterRatio: 1.9,
        physics: const FixedExtentScrollPhysics(),
        onSelectedItemChanged: (index) {
          HapticFeedback.selectionClick();
          onChanged(index % labels.length);
        },
        childDelegate: loop
            ? ListWheelChildLoopingListDelegate(children: children)
            : ListWheelChildListDelegate(children: children),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.line,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Text(widget.title, style: AppText.heading),
          const SizedBox(height: 16),
          SizedBox(
            height: _extent * 4,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // The lens the numbers snap into.
                IgnorePointer(
                  child: Container(
                    height: _extent,
                    decoration: BoxDecoration(
                      color: AppColors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.violet.withValues(alpha: 0.6), width: 1.5),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _wheel(
                      controller: _hourCtrl,
                      labels: [for (var h = 1; h <= 12; h++) '$h'],
                      selected: _hour,
                      onChanged: (v) => setState(() => _hour = v),
                    ),
                    Text(':', style: AppText.numeral.copyWith(fontSize: 34)),
                    _wheel(
                      controller: _minuteCtrl,
                      labels: [for (var m = 0; m < 60; m++) m.toString().padLeft(2, '0')],
                      selected: _minute,
                      onChanged: (v) => setState(() => _minute = v),
                    ),
                    const SizedBox(width: 8),
                    _wheel(
                      controller: _periodCtrl,
                      labels: const ['AM', 'PM'],
                      selected: _period,
                      onChanged: (v) => setState(() => _period = v),
                      loop: false,
                      width: 92,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          NeoButton(
            label: 'Set time',
            onPressed: () => Navigator.of(context).pop(_result),
          ),
        ],
      ),
    );
  }
}
