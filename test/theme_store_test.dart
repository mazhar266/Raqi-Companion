import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raqi_companion/screens/settings_screen.dart';
import 'package:raqi_companion/theme_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('defaults to system when nothing has been stored', () async {
    SharedPreferences.setMockInitialValues({});
    final store = ThemeStore();
    expect(store.loaded, isFalse);

    await store.load();

    expect(store.mode, ThemeMode.system);
    expect(store.loaded, isTrue);
  });

  test('restores a previously chosen mode', () async {
    SharedPreferences.setMockInitialValues({'themeMode': 'dark'});
    final store = ThemeStore();

    await store.load();

    expect(store.mode, ThemeMode.dark);
  });

  test('falls back to system for an unrecognised stored value', () async {
    SharedPreferences.setMockInitialValues({'themeMode': 'sepia'});
    final store = ThemeStore();

    await store.load();

    expect(store.mode, ThemeMode.system);
  });

  test('setMode persists the choice and notifies listeners', () async {
    SharedPreferences.setMockInitialValues({});
    final store = ThemeStore();
    await store.load();
    var notifications = 0;
    store.addListener(() => notifications++);

    await store.setMode(ThemeMode.light);

    expect(store.mode, ThemeMode.light);
    expect(notifications, 1);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('themeMode'), 'light');
  });

  test('setMode to the current mode is a no-op', () async {
    SharedPreferences.setMockInitialValues({});
    final store = ThemeStore();
    await store.load();
    var notifications = 0;
    store.addListener(() => notifications++);

    await store.setMode(ThemeMode.system);

    expect(notifications, 0);
  });

  test('going back to system clears the override', () async {
    SharedPreferences.setMockInitialValues({'themeMode': 'dark'});
    final store = ThemeStore();
    await store.load();

    await store.setMode(ThemeMode.system);

    expect(store.mode, ThemeMode.system);
    final reloaded = ThemeStore();
    await reloaded.load();
    expect(reloaded.mode, ThemeMode.system);
  });

  testWidgets('settings offers all three modes and applies a choice',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = ThemeStore();
    await store.load();

    await tester.pumpWidget(MaterialApp(home: SettingsScreen(themeStore: store)));
    await tester.pumpAndSettle();

    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
    expect(find.text('System'), findsOneWidget);

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    expect(store.mode, ThemeMode.dark);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('themeMode'), 'dark');
  });
}
