import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zlinker/protocol/channel_client.dart';
import 'package:zlinker/protocol/off_peak.dart';
import 'package:zlinker/state/device_session.dart';
import 'package:zlinker/state/device_store.dart';
import 'package:zlinker/ui/off_peak_page.dart';
import 'package:zlinker/ui/theme.dart';
import 'package:zlinker/ui/ui_settings.dart';

/// Fake off-peak device link answering from a local table.
class FakeOffPeakHost implements OffPeakHost {
  @override
  DeviceStatus status;

  final List<Map<String, dynamic>> tasks;
  final Map<String, dynamic> statusInfo;
  final List<(String, List<Object?>)> calls = [];
  Object Function(String method, List<Object?> args)? failWith;

  FakeOffPeakHost(
    this.status, {
    this.tasks = const [],
    this.statusInfo = const {},
  });

  @override
  Map<String, dynamic> offPeakScope = const {
    'workspacePath': '/repo',
    'workspaceIdentity': 'repo-id',
  };

  @override
  late final OffPeakPort offPeak = OffPeakPort(_call);

  Future<dynamic> _call(String method, List<Object?> args) async {
    final fail = failWith;
    if (fail != null) {
      throw fail(method, args);
    }
    calls.add((method, args));
    if (method.contains('list') || method.contains('List')) return tasks;
    if (method.startsWith('get') || method == 'status') return statusInfo;
    return null;
  }
}

Widget wrap(Widget child) => MaterialApp(
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      builder: (context, child) =>
          UiSettingsProvider(settings: UiSettings(), child: child!),
      home: child,
    );

Future<(DeviceStore, DeviceSessionHub)> setupDevice() async {
  SharedPreferences.setMockInitialValues({});
  final store = DeviceStore();
  await store.load();
  await store.addUrl(
      'https://zcode.z.ai/remote/v4?sid=abc&hash=xyz&t=123&mid=m1&name=songsong&app_version=3.8.1');
  return (store, DeviceSessionHub(nativeListEnabled: () => false));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows tasks with queue badge and view-result button',
      (WidgetTester tester) async {
    final (store, hub) = await setupDevice();
    final host = FakeOffPeakHost(DeviceStatus.connected, tasks: [
      {
        'offPeakTaskId': 't1',
        'title': 'CI 报告',
        'prompt': '分析 CI',
        'status': 'queued',
        'queuePosition': 2,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      },
      {
        'offPeakTaskId': 't2',
        'title': '文档检查',
        'prompt': '检查文档',
        'status': 'completed',
        'sessionId': 's-9',
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'startedAt': DateTime.now().millisecondsSinceEpoch - 600000,
        'finishedAt': DateTime.now().millisecondsSinceEpoch,
      },
    ]);

    await tester.pumpWidget(wrap(OffPeakPage(
      store: store,
      hub: hub,
      device: store.devices.first,
      hostOverride: host,
    )));
    await tester.pumpAndSettle();

    expect(find.text('CI 报告'), findsOneWidget);
    expect(find.text('#2'), findsOneWidget); // 排队位置徽标
    expect(find.text('排队中'), findsOneWidget);
    expect(find.text('文档检查'), findsOneWidget);
    expect(find.text('已完成'), findsOneWidget);
    expect(find.text('查看结果'), findsOneWidget);
    expect(find.textContaining('用时 10 分钟'), findsOneWidget);
  });

  testWidgets('quota header shows remaining + earliest window',
      (WidgetTester tester) async {
    final (store, hub) = await setupDevice();
    final host = FakeOffPeakHost(DeviceStatus.connected, statusInfo: {
      'available': true,
      'quotaRemainingMinutes': 300,
      'earliestAvailableAt':
          DateTime.now().add(const Duration(hours: 2)).millisecondsSinceEpoch,
    });

    await tester.pumpWidget(wrap(OffPeakPage(
      store: store,
      hub: hub,
      device: store.devices.first,
      hostOverride: host,
    )));
    await tester.pumpAndSettle();

    expect(find.textContaining('剩余额度'), findsOneWidget);
    expect(find.textContaining('5.0 小时'), findsOneWidget);
    expect(find.textContaining('最早可用'), findsOneWidget);
  });

  testWidgets('codingPlanOnly state shows the official error copy',
      (WidgetTester tester) async {
    final (store, hub) = await setupDevice();
    final host = FakeOffPeakHost(DeviceStatus.connected, statusInfo: {
      'available': false,
      'reason': 'codingPlanOnly',
    });

    await tester.pumpWidget(wrap(OffPeakPage(
      store: store,
      hub: hub,
      device: store.devices.first,
      hostOverride: host,
    )));
    await tester.pumpAndSettle();

    expect(find.text('闲时任务仅 Coding Plan 订阅可用'), findsOneWidget);
  });

  testWidgets('submit sheet prefills from a template and submits the wire shape',
      (WidgetTester tester) async {
    final (store, hub) = await setupDevice();
    final host = FakeOffPeakHost(DeviceStatus.connected);

    await tester.pumpWidget(wrap(OffPeakPage(
      store: store,
      hub: hub,
      device: store.devices.first,
      hostOverride: host,
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.text('新建闲时任务'));
    await tester.pumpAndSettle();

    // Template chip prefills title + prompt.
    await tester.tap(find.text('CI flaky 报告'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, '分析最近的 CI 失败，找出 flaky 测试并输出报告'),
        findsOneWidget);

    await tester.tap(find.text('提交'));
    await tester.pumpAndSettle();

    final submit = host.calls
        .where((c) => c.$1 == 'run' || c.$1 == 'submit')
        .toList();
    expect(submit, hasLength(1));
    final wire = submit.single.$2.single as Map<String, dynamic>;
    expect(wire['prompt'], '分析最近的 CI 失败，找出 flaky 测试并输出报告');
    expect(wire['workspacePath'], '/repo');
    expect(wire['workspaceIdentity'], 'repo-id');
    expect(wire['permissionMode'], 'build');
    expect(wire['offPeakTaskId'], isNotEmpty);
  });

  testWidgets('quota failure on submit shows the official error copy',
      (WidgetTester tester) async {
    final (store, hub) = await setupDevice();
    final host = FakeOffPeakHost(DeviceStatus.connected);
    host.failWith = (m, _) =>
        ChannelRpcError('monthly off-peak quota exceeded', null);

    await tester.pumpWidget(wrap(OffPeakPage(
      store: store,
      hub: hub,
      device: store.devices.first,
      hostOverride: host,
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.text('新建闲时任务'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, '指令'), '跑一次分析');
    await tester.tap(find.text('提交'));
    await tester.pumpAndSettle();

    expect(find.text('本月闲时额度已用尽'), findsOneWidget);
    // Sheet stays open for correction / cancel (FAB + sheet title both say
    // 新建闲时任务).
    expect(find.text('新建闲时任务'), findsNWidgets(2));
  });

  testWidgets('pause and cancel route through the port',
      (WidgetTester tester) async {
    final (store, hub) = await setupDevice();
    final host = FakeOffPeakHost(DeviceStatus.connected, tasks: [
      {
        'offPeakTaskId': 't1',
        'title': '排队任务',
        'prompt': 'p',
        'status': 'queued',
        'queuePosition': 1,
      },
    ]);

    await tester.pumpWidget(wrap(OffPeakPage(
      store: store,
      hub: hub,
      device: store.devices.first,
      hostOverride: host,
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消任务'));
    await tester.pumpAndSettle();

    final cancel = host.calls.where((c) => c.$1 == 'cancel').toList();
    expect(cancel, hasLength(1));
    expect(cancel.single.$2, [
      {'offPeakTaskId': 't1'}
    ]);
  });
}
