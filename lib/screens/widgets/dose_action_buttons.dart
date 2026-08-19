import 'package:flutter/material.dart';

class DoseActionButtons extends StatelessWidget {
  const DoseActionButtons({
    super.key,
    required this.takeLabel,
    required this.skipLabel,
    required this.snoozeLabel,
    required this.onTake,
    required this.onSkip,
    required this.onSnooze,
  });

  final String takeLabel;
  final String skipLabel;
  final String snoozeLabel;
  final VoidCallback onTake;
  final VoidCallback onSkip;
  final VoidCallback onSnooze;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      runSpacing: 4,
      children: <Widget>[
        Semantics(
          button: true,
          label: snoozeLabel,
          excludeSemantics: true,
          child: IconButton(
            onPressed: onSnooze,
            icon: const Icon(Icons.snooze),
            tooltip: snoozeLabel,
          ),
        ),
        Semantics(
          button: true,
          label: skipLabel,
          excludeSemantics: true,
          child: IconButton(
            onPressed: onSkip,
            icon: const Icon(Icons.close),
            tooltip: skipLabel,
          ),
        ),
        Semantics(
          button: true,
          label: takeLabel,
          excludeSemantics: true,
          child: FilledButton(onPressed: onTake, child: Text(takeLabel)),
        ),
      ],
    );
  }
}
