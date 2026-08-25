import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String mainSource;
  late String homeSource;

  setUpAll(() {
    mainSource = File('lib/main.dart').readAsStringSync();
    homeSource = File('lib/screens/home_screen.dart').readAsStringSync();
  });

  test('BesyuApp owns foreground reminder system refresh', () {
    expect(mainSource, contains('with WidgetsBindingObserver'));
    expect(mainSource, contains('AppLifecycleState.resumed'));
    expect(mainSource, contains('_systemReminderTriggers.onResume()'));
  });

  test('Home keeps cold-launch repair without owning resume lifecycle', () {
    expect(homeSource, contains('addPostFrameCallback'));
    expect(homeSource, isNot(contains('with WidgetsBindingObserver')));
    expect(homeSource, isNot(contains('didChangeAppLifecycleState')));
    expect(homeSource, isNot(contains('AppLifecycleState.resumed')));
  });
}
