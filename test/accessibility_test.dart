import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:med_reminder_offline/screens/widgets/dose_action_buttons.dart';

void main() {
  testWidgets('dose actions expose semantics and survive 1.3x text scale', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    addTearDown(semantics.dispose);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: DoseActionButtons(
                takeLabel: 'Taken',
                skipLabel: 'Skip',
                snoozeLabel: 'Snooze 10m',
                onTake: () {},
                onSkip: () {},
                onSnooze: () {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('Taken'), findsOneWidget);
    expect(find.bySemanticsLabel('Skip'), findsOneWidget);
    expect(find.bySemanticsLabel('Snooze 10m'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
