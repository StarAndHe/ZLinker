import 'package:flutter/material.dart';

import 'state/device_store.dart';
import 'state/device_session.dart';
import 'state/scheduled_store.dart';
import 'ui/devices_page.dart';
import 'ui/theme.dart';
import 'ui/ui_settings.dart';

void main() {
  runApp(const ZRemoteApp());
}

class ZRemoteApp extends StatefulWidget {
  const ZRemoteApp({super.key});

  @override
  State<ZRemoteApp> createState() => _ZRemoteAppState();
}

class _ZRemoteAppState extends State<ZRemoteApp> {
  final DeviceStore _store = DeviceStore();
  final ThemeController _theme = ThemeController();
  final UiSettings _ui = UiSettings();
  final ScheduledStore _scheduled = ScheduledStore();
  late final DeviceSessionHub _hub = DeviceSessionHub(
    nativeListEnabled: () => _ui.nativeListEnabled,
  );
  late final MessageScheduler _scheduler = MessageScheduler(
    store: _scheduled,
    devices: _store,
    hub: _hub,
  );

  @override
  void initState() {
    super.initState();
    _theme.load();
    _ui.load();
    _scheduled.load();
    // Fire due scheduled messages while the app is alive.
    _scheduler.start();
  }

  @override
  void dispose() {
    _scheduler.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_theme, _ui]),
      builder: (context, _) {
        return MaterialApp(
          title: 'ZRemote',
          debugShowCheckedModeBanner: false,
          theme: buildLightTheme(),
          darkTheme: buildDarkTheme(),
          themeMode: _theme.mode,
          // Wraps the whole navigator so dialogs/overlays see tr() too.
          builder: (context, child) =>
              UiSettingsProvider(settings: _ui, child: child!),
          home: DevicesPage(
            store: _store,
            theme: _theme,
            ui: _ui,
            hub: _hub,
            scheduled: _scheduled,
          ),
        );
      },
    );
  }
}
