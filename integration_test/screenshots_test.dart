// Store screenshot capture: pumps the real pages with seeded fake data and
// captures full-screen shots for App Store / Play listings.
//
// Run on a device/simulator via flutter drive (writes PNGs through the
// test_driver/integration_test.dart onScreenshot callback):
//
//   ZLINKER_SHOT_DIR=docs/screenshots flutter drive \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/screenshots_test.dart -d <device> \
//     --dart-define=SHOT_LOCALE=en-US
//
// SHOT_LOCALE picks the app UI language AND the seeded data language
// (zh-CN default, en-US for the English set); each capture is suffixed
// -zh / -en. Resize to store sizes afterwards (see docs/store/SCREENSHOTS.md).
import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zlinker/state/device_session.dart';
import 'package:zlinker/state/device_store.dart';
import 'package:zlinker/state/scheduled_store.dart';
import 'package:zlinker/ui/chat/chat_page.dart';
import 'package:zlinker/ui/devices_page.dart';
import 'package:zlinker/ui/task_list_page.dart';
import 'package:zlinker/ui/theme.dart';
import 'package:zlinker/ui/ui_settings.dart';

import '../test/helpers/fake_device_session.dart';

const _shotLocale = String.fromEnvironment('SHOT_LOCALE', defaultValue: 'zh-CN');
final _isEn = _shotLocale.startsWith('en');
final _suffix = _isEn ? '-en' : '-zh';

const _urlA =
    'https://zcode.z.ai/remote/v4?sid=abc&hash=xyz&t=123&mid=m1&name=Mac%20Studio&app_version=3.8.1';
const _urlB =
    'https://zcode.z.ai/remote/v4?sid=def&hash=uvw&t=124&mid=m2&name=ThinkPad&app_version=3.8.1';

final _now = DateTime.now().millisecondsSinceEpoch;

final _sessions = _isEn
    ? [
        {
          'sessionId': 'sess_shot_1',
          'title': 'ZLinker store copy & screenshots',
          'phase': 'running',
          'lastAssistantPreview':
              'Screenshot tests passed — generating bilingual store assets…',
          'lastActivityAt': _now - 1000 * 62,
          'pinned': true,
        },
        {
          'sessionId': 'sess_shot_2',
          'title': 'Deep dive: GitHub description generation',
          'phase': 'completed',
          'lastAssistantPreview':
              'Full analysis delivered, three conclusions.',
          'lastActivityAt': _now - 1000 * 60 * 41,
        },
        {
          'sessionId': 'sess_shot_3',
          'title': 'Off-peak: daily build patrol report',
          'phase': 'queued',
          'lastAssistantPreview': 'Queued · runs at the next 02:00 idle window',
          'lastActivityAt': _now - 1000 * 60 * 60 * 5,
        },
      ]
    : [
        {
          'sessionId': 'sess_shot_1',
          'title': 'ZLinker 商店页文案与截图',
          'phase': 'running',
          'lastAssistantPreview': '截图测试已通过，正在生成双语言商店素材…',
          'lastActivityAt': _now - 1000 * 62,
          'pinned': true,
        },
        {
          'sessionId': 'sess_shot_2',
          'title': '深度解析 GitHub 描述生成',
          'phase': 'completed',
          'lastAssistantPreview': '完整分析已输出，共三个结论。',
          'lastActivityAt': _now - 1000 * 60 * 41,
        },
        {
          'sessionId': 'sess_shot_3',
          'title': '闲时任务：每日构建巡检报告',
          'phase': 'queued',
          'lastAssistantPreview': '排队中 · 预计 02:00 空闲窗口执行',
          'lastActivityAt': _now - 1000 * 60 * 60 * 5,
        },
      ];

final _workspaces = [
  {'workspacePath': '/Users/dev/ZLinker', 'workspaceIdentity': 'ZLinker'},
];

final _chatTitle =
    _isEn ? 'ZLinker store copy & screenshots' : 'ZLinker 商店页文案与截图';

final _chatRows = _isEn
    ? [
        {'rowId': 1, 'kind': 'userInput', 'text': 'Regroup the task list by pinned section'},
        {
          'rowId': 2,
          'kind': 'assistantText',
          'text': 'Done:\n\n- **Pinned** group now leads the list\n- Each group sorted by latest activity\n- Running tasks show a live status dot',
        },
        {
          'rowId': 3,
          'kind': 'turnHeader',
          'state': 'completedSuccess',
          'activeMs': 48000,
          'fileChanges': {'files': 2, 'additions': 64, 'deletions': 11},
        },
      ]
    : [
        {'rowId': 1, 'kind': 'userInput', 'text': '帮我把任务列表按置顶分组重排'},
        {
          'rowId': 2,
          'kind': 'assistantText',
          'text': '已完成重排：\n\n- **已置顶** 分组现在排在最前\n- 每组内按最近活动时间排序\n- 运行中的任务带实时状态点',
        },
        {
          'rowId': 3,
          'kind': 'turnHeader',
          'state': 'completedSuccess',
          'activeMs': 48000,
          'fileChanges': {'files': 2, 'additions': 64, 'deletions': 11},
        },
      ];

Widget _wrap(Widget child, ThemeController theme, UiSettings ui) =>
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: ThemeMode.dark,
      builder: (context, child) => UiSettingsProvider(settings: ui, child: child!),
      home: child,
    );

/// Hub that answers from injected fakes and never opens a real relay —
/// otherwise DeviceSessionHub connects to the seeded (bogus) URLs and its
/// retry loop keeps scheduling frames forever.
class _ShotHub extends DeviceSessionHub {
  final Map<String, DeviceSession> fakes;
  _ShotHub(this.fakes) : super(nativeListEnabled: () => true);

  @override
  void syncWith(List<Device> devices) {}
  @override
  DeviceSession? ensure(Device device) => fakes[device.id];
  @override
  DeviceSession? sessionOf(String deviceId) => fakes[deviceId];
  @override
  Future<void> suspend(String deviceId) async {}
  @override
  void scheduleResume(Device device) {}
  @override
  Future<void> disconnectAll() async {}
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('capture store screenshots', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final theme = ThemeController();
    final ui = UiSettings()..locale = _shotLocale;
    final store = DeviceStore();
    await store.load();
    await store.addUrl(_urlA);
    await store.addUrl(_urlB);
    final deviceA = store.devices.first;

    final session = FakeDeviceSession(
      deviceId: deviceA.id,
      params: deviceA.params!,
      entries: _sessions,
      workspaces: _workspaces,
      chatRows: _chatRows,
    );
    final sessionB = FakeDeviceSession(
      deviceId: store.devices[1].id,
      params: store.devices[1].params!,
      entries: _sessions,
    );
    final hub = _ShotHub({
      deviceA.id: session,
      store.devices[1].id: sessionB,
    });

    // 1. Device list
    await tester.pumpWidget(_wrap(
      DevicesPage(
        store: store,
        theme: theme,
        ui: ui,
        hub: hub,
        scheduled: ScheduledStore(),
      ),
      theme,
      ui,
    ));
    await tester.pumpAndSettle();

    // Android renders Flutter into an external surface; convert it to an
    // image so takeScreenshot can read pixels (required before the 1st shot).
    await binding.convertFlutterSurfaceToImage();
    await tester.pump(const Duration(milliseconds: 300));
    await binding.takeScreenshot('01-devices$_suffix');

    // 2. Native task list. In image-surface mode the rasterizer keeps
    // scheduling frames, so pumpAndSettle never returns — pump real time
    // instead and let implicit transitions finish.
    await tester.pumpWidget(_wrap(
      TaskListPage(
        store: store,
        hub: hub,
        device: deviceA,
        sessionOverride: session,
      ),
      theme,
      ui,
    ));
    await tester.pump(const Duration(milliseconds: 1500));
    await binding.takeScreenshot('02-tasks$_suffix');

    // 3. Conversation
    await tester.pumpWidget(_wrap(
      ChatPage(
        gateway: session,
        sessionId: 'sess_shot_1',
        title: _chatTitle,
      ),
      theme,
      ui,
    ));
    await tester.pump(const Duration(milliseconds: 1500));
    await binding.takeScreenshot('03-chat$_suffix');

    // 4. Tablet dual-pane (runs only when the device surface is ≥768dp wide,
    // i.e. the emulator has been switched to a tablet profile):
    // TaskListPage's desktop layout with a task pre-opened in the right pane.
    if (MediaQuery.of(tester.element(find.byType(Scaffold))).size.width >=
        768) {
      await tester.pumpWidget(_wrap(
        TaskListPage(
          store: store,
          hub: hub,
          device: deviceA,
          theme: theme,
          sessionOverride: session,
          initialPaneSessionId: 'sess_shot_1',
          initialPaneTitle: _chatTitle,
        ),
        theme,
        ui,
      ));
      await tester.pump(const Duration(milliseconds: 1500));
      await binding.takeScreenshot('04-dualpane$_suffix');
    }
  });
}
