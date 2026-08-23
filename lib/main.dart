import 'package:flutter/material.dart';

import 'state/device_store.dart';
import 'ui/devices_page.dart';
import 'ui/theme.dart';

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

  @override
  void initState() {
    super.initState();
    _theme.load();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _theme,
      builder: (context, _) {
        return MaterialApp(
          title: 'ZRemote',
          debugShowCheckedModeBanner: false,
          theme: buildLightTheme(),
          darkTheme: buildDarkTheme(),
          themeMode: _theme.mode,
          home: DevicesPage(store: _store, theme: _theme),
        );
      },
    );
  }
}
