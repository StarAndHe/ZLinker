import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zremote/state/device_session.dart';
import 'package:zremote/state/device_store.dart';
import 'package:zremote/ui/chat/chat_page.dart';
import 'package:zremote/ui/task_list_page.dart';
import 'package:zremote/ui/theme.dart';
import 'package:zremote/ui/ui_settings.dart';

import '../test/helpers/fake_device_session.dart';
import '../test/ui/chat_page_test.dart' show FakeChatGateway;

const _shot = String.fromEnvironment('SHOT', defaultValue: '');

const _demoChatRows = [
  {
    'rowId': 1,
    'kind': 'userInput',
    'text': '帮我检查登录页面的表单校验',
  },
  {
    'rowId': 2,
    'kind': 'assistantText',
    'text': '已更新 **login.dart**，补全邮箱格式校验与错误提示。',
  },
  {
    'rowId': 3,
    'kind': 'turnHeader',
    'state': 'completedSuccess',
    'activeMs': 42000,
    'fileChanges': {'files': 1, 'additions': 18, 'deletions': 4},
  },
];

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final shot = _shot.isNotEmpty
      ? _shot
      : (Uri.base.queryParameters['shot'] ?? 'list');
  runApp(ScreenshotApp(mode: shot));
}

class ScreenshotApp extends StatefulWidget {
  final String mode;
  const ScreenshotApp({super.key, required this.mode});

  @override
  State<ScreenshotApp> createState() => _ScreenshotAppState();
}

class _ScreenshotAppState extends State<ScreenshotApp> {
  DeviceStore? _store;
  Device? _device;
  FakeDeviceSession? _session;
  bool _readySent = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    SharedPreferences.setMockInitialValues({});
    final store = DeviceStore();
    await store.load();
    await store.addUrl(
      'https://zcode.z.ai/remote/v4?sid=demo&hash=xyz&t=123&mid=m1&name=DemoDesk&app_version=3.8.1',
    );
    final device = store.devices.single;
    final session = FakeDeviceSession(
      deviceId: device.id,
      params: device.params!,
      entries: [
        {
          'sessionId': 's1',
          'title': '修复登录流程',
          'phase': 'running',
          'lastActivityAt': DateTime.now().millisecondsSinceEpoch,
        },
        {
          'sessionId': 's2',
          'title': '写周报',
          'phase': 'completedSuccess',
          'lastActivityAt': DateTime.now().millisecondsSinceEpoch - 60000,
        },
      ],
      workspaces: [
        {'workspacePath': '/repo/zremote', 'workspaceIdentity': 'zremote-id'},
      ],
      chatRows: _demoChatRows,
    );
    if (mounted) {
      setState(() {
        _store = store;
        _device = device;
        _session = session;
      });
      _scheduleReady();
    }
  }

  void _scheduleReady() {
    if (_readySent || widget.mode == 'chat') return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_readySent) return;
      if (widget.mode == 'dual') {
        // Embedded pane chat: subscribe + snapshot need an extra beat on web.
        await Future<void>.delayed(const Duration(milliseconds: 1200));
      }
      if (!mounted || _readySent) return;
      _readySent = true;
      _markReady(widget.mode);
    });
  }

  Size get _viewport => switch (widget.mode) {
        'dual' => const Size(1280, 900),
        _ => const Size(390, 844),
      };

  Widget _body() {
    final store = _store!;
    final device = _device!;
    final session = _session!;
    final hub = DeviceSessionHub(nativeListEnabled: () => false);

    return switch (widget.mode) {
      'chat' => _ChatShot(session: session),
      'dual' => TaskListPage(
          store: store,
          hub: hub,
          device: device,
          sessionOverride: session,
          initialPaneSessionId: 's1',
          initialPaneTitle: '修复登录流程',
        ),
      _ => TaskListPage(
          store: store,
          hub: hub,
          device: device,
          sessionOverride: session,
        ),
    };
  }

  void _markReady(String mode) {
    web.document.title = 'zremote-ready-$mode';
  }

  @override
  Widget build(BuildContext context) {
    if (_store == null) {
      return MaterialApp(
        theme: buildDarkTheme(),
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildDarkTheme(),
      darkTheme: buildDarkTheme(),
      builder: (context, child) =>
          UiSettingsProvider(settings: UiSettings(), child: child!),
      home: Scaffold(
        backgroundColor: buildDarkTheme().scaffoldBackgroundColor,
        body: Center(
          child: SizedBox(
            width: _viewport.width,
            height: _viewport.height,
            child: _body(),
          ),
        ),
      ),
    );
  }
}

class _ChatShot extends StatefulWidget {
  final FakeDeviceSession session;
  const _ChatShot({required this.session});

  @override
  State<_ChatShot> createState() => _ChatShotState();
}

class _ChatShotState extends State<_ChatShot> {
  late final FakeChatGateway _gateway;

  @override
  void initState() {
    super.initState();
    _gateway = FakeChatGateway();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _gateway.feedSnapshot(_demoChatRows);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        web.document.title = 'zremote-ready-chat';
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return ChatPage(
      gateway: _gateway,
      sessionId: 's1',
      title: '修复登录流程',
      workspaceLabel: 'zremote',
    );
  }
}
