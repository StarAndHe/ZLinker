import 'dart:async';

import 'package:flutter/material.dart';

import 'notifications/notification_service.dart';
import 'state/device_session.dart';
import 'state/device_store.dart';
import 'state/notification_hub.dart';
import 'state/scheduled_store.dart';
import 'ui/devices_page.dart';
import 'ui/remote_page.dart';
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
  final NotificationService _notifications = NotificationService();
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  late final DeviceSessionHub _hub = DeviceSessionHub(
    nativeListEnabled: () => _ui.nativeListEnabled,
  );
  late final MessageScheduler _scheduler = MessageScheduler(
    store: _scheduled,
    devices: _store,
    hub: _hub,
  );
  late final NotificationHub _notifyHub = NotificationHub(
    service: _notifications,
    ui: _ui,
    deviceLabelOf: (id) =>
        _store.devices.where((d) => d.id == id).firstOrNull?.label ?? id,
  );

  @override
  void initState() {
    super.initState();
    _theme.load();
    _ui.load();
    _scheduled.load();
    // Fire due scheduled messages while the app is alive.
    _scheduler.start();
    // Local notifications: task events ride the sessions stream; off-peak
    // and automation results poll. Tapping deep-links to the conversation.
    _notifications.onTap = _handleNotificationTap;
    unawaited(_notifications.init());
    _hub.addListener(_syncNotifyHub);
    _syncNotifyHub();
    _notifyHub.start();
  }

  void _syncNotifyHub() {
    if (mounted) _notifyHub.syncWith(_hub.activeSessions);
  }

  /// Notification tap → the producing conversation: suspend the native
  /// connection, open the WebView deep-linked to the session, resume after.
  Future<void> _handleNotificationTap(Map<String, dynamic> payload) async {
    final deviceId = payload['deviceId'] as String?;
    if (deviceId == null) return;
    final device = _store.devices.where((d) => d.id == deviceId).firstOrNull;
    if (device == null) return;
    final sessionId = payload['sessionId'] as String?;
    final title = payload['title'] as String?;
    await _store.touch(device.id);
    await _hub.suspend(device.id);
    if (!mounted) return;
    final context = _navigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => RemotePage(
        device: device,
        targetSessionId: sessionId,
        targetTitle: title,
      ),
    ));
    _hub.scheduleResume(device);
  }

  @override
  void dispose() {
    _notifyHub.dispose();
    _hub.removeListener(_syncNotifyHub);
    _scheduler.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_theme, _ui]),
      builder: (context, _) {
        return MaterialApp(
          navigatorKey: _navigatorKey,
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
