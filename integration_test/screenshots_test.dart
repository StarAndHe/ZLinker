// Store screenshot capture: pumps the real pages with seeded fake data and
// captures full-screen shots for App Store / Play listings.
//
// Run on a device/simulator:
//   flutter test integration_test/screenshots_test.dart -d <device> \
//       --screenshots build/screenshots
//
// The CI "Store screenshots" workflow (workflow_dispatch) runs this on an
// iPhone simulator and post-processes the PNGs into store-required sizes.
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

const _urlA =
    'https://zcode.z.ai/remote/v4?sid=abc&hash=xyz&t=123&mid=m1&name=Mac%20Studio&app_version=3.8.1';
const _urlB =
    'https://zcode.z.ai/remote/v4?sid=def&hash=uvw&t=124&mid=m2&name=ThinkPad&app_version=3.8.1';

final _now = DateTime.now().millisecondsSinceEpoch;

final _sessions = [
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

final _chatRows = [
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

Widget _wrap(Widget child, ThemeController theme) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: ThemeMode.dark,
      builder: (context, child) =>
          UiSettingsProvider(settings: UiSettings(), child: child!),
      home: child,
    );

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('capture store screenshots', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final theme = ThemeController();
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

    // 1. Device list
    await tester.pumpWidget(_wrap(
      DevicesPage(
        store: store,
        theme: theme,
        ui: UiSettings(),
        hub: DeviceSessionHub(nativeListEnabled: () => true),
        scheduled: ScheduledStore(),
      ),
      theme,
    ));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('01-devices');

    // 2. Native task list
    await tester.pumpWidget(_wrap(
      TaskListPage(
        store: store,
        hub: DeviceSessionHub(nativeListEnabled: () => true),
        device: deviceA,
        sessionOverride: session,
      ),
      theme,
    ));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('02-tasks');

    // 3. Conversation
    await tester.pumpWidget(_wrap(
      ChatPage(
        gateway: session,
        sessionId: 'sess_shot_1',
        title: 'ZLinker 商店页文案与截图',
      ),
      theme,
    ));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('03-chat');
  });
}
