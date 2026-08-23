import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zremote/main.dart';
import 'package:zremote/state/device_session.dart';
import 'package:zremote/state/device_store.dart';
import 'package:zremote/state/scheduled_store.dart';
import 'package:zremote/ui/devices_page.dart';
import 'package:zremote/ui/theme.dart';
import 'package:zremote/ui/ui_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrap(DevicesPage page) => MaterialApp(
        theme: buildLightTheme(),
        darkTheme: buildDarkTheme(),
        builder: (context, child) =>
            UiSettingsProvider(settings: UiSettings(), child: child!),
        home: page,
      );

  testWidgets('DevicesPage shows empty state with no devices',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = DeviceStore();
    final theme = ThemeController();
    final ui = UiSettings();
    final hub = DeviceSessionHub(nativeListEnabled: () => ui.nativeListEnabled);
    await tester.pumpWidget(wrap(DevicesPage(
      store: store,
      theme: theme,
      ui: ui,
      hub: hub,
      scheduled: ScheduledStore(),
    )));
    await tester.pumpAndSettle();

    expect(find.text('ZRemote'), findsOneWidget);
    expect(find.text('还没有设备'), findsOneWidget);
    expect(find.text('添加设备'), findsOneWidget);
  });

  testWidgets('DevicesPage renders a device card',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = DeviceStore();
    await store.load();
    await store.addUrl(
        'https://zcode.z.ai/remote/v4?sid=abc&hash=xyz&t=123&mid=m1&name=songsong&app_version=3.8.1');

    final theme = ThemeController();
    final ui = UiSettings();
    final hub = DeviceSessionHub(nativeListEnabled: () => false);
    await tester.pumpWidget(wrap(DevicesPage(
      store: store,
      theme: theme,
      ui: ui,
      hub: hub,
      scheduled: ScheduledStore(),
    )));
    await tester.pumpAndSettle();

    expect(find.text('songsong'), findsOneWidget);
    expect(find.text('zcode.z.ai'), findsWidgets);
    // No native connection is attempted with the switch off.
    expect(find.text('离线'), findsOneWidget);
  });

  testWidgets('App boots', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const ZRemoteApp());
    await tester.pumpAndSettle();
    expect(find.text('ZRemote'), findsOneWidget);
  });
}
