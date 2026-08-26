import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zlinker/protocol/automation.dart';
import 'package:zlinker/state/device_session.dart';
import 'package:zlinker/state/device_store.dart';
import 'package:zlinker/state/scheduled_store.dart';
import 'package:zlinker/ui/automations_page.dart';
import 'package:zlinker/ui/scheduled_page.dart';
import 'package:zlinker/ui/theme.dart';
import 'package:zlinker/ui/ui_settings.dart';

/// Fake device link: connected host whose automation port answers locally.
class FakeAutomationHost implements AutomationHost {
  @override
  DeviceStatus status;

  final List<Map<String, dynamic>> items;
  final List<(String, List<Object?>)> calls = [];
  Object Function(String method, List<Object?> args)? failWith;

  FakeAutomationHost(this.status, [this.items = const []]);

  @override
  late final AutomationPort automation = AutomationPort(_call);

  Future<dynamic> _call(String method, List<Object?> args) async {
    final fail = failWith;
    if (fail != null) {
      throw fail(method, args);
    }
    calls.add((method, args));
    if (method.contains('list') || method.contains('List')) {
      return items;
    }
    return null;
  }
}

Widget wrap(Widget child) => MaterialApp(
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      builder: (context, child) =>
          UiSettingsProvider(settings: UiSettings(), child: child!),
      home: Scaffold(body: child),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('pane shows unavailable + fallback hint without a session',
      (WidgetTester tester) async {
    await tester.pumpWidget(
        wrap(const AutomationsPane(session: null)));
    await tester.pumpAndSettle();

    expect(find.text('设备定时任务不可用'), findsOneWidget);
    expect(find.textContaining('本地定时发送'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
  });

  testWidgets('pane lists items with trigger summaries and toggles',
      (WidgetTester tester) async {
    final host = FakeAutomationHost(DeviceStatus.connected, [
      {
        'automationId': 'a1',
        'title': '日报',
        'prompt': '写日报',
        'cronExpr': '0 9 * * *',
        'enabled': true,
      },
      {
        'automationId': 'a2',
        'title': '备份',
        'prompt': '备份数据库',
        'interval': 6,
        'intervalUnit': 'hour',
        'recurring': false,
        'maxRuns': 12,
      },
      {
        'automationId': 'a3',
        'title': '一次性',
        'prompt': '跑一次分析',
        'relativeDelayMinutes': 120,
      },
      {
        'automationId': 'a4',
        'title': '周会',
        'prompt': 'p',
        'cronExpr': '0 9 * * 3',
      },
      {
        'automationId': 'a5',
        'title': '月报',
        'prompt': 'p',
        'cronExpr': '30 10 5 * *',
      },
    ]);
    await tester.pumpWidget(wrap(AutomationsPane(session: host)));
    await tester.pumpAndSettle();

    expect(find.text('日报'), findsOneWidget);
    expect(find.text('每天 09:00'), findsOneWidget);
    expect(find.text('备份'), findsOneWidget);
    expect(find.text('每 6 小时 · 最多 12 次'), findsOneWidget);
    expect(find.text('一次性'), findsOneWidget);
    expect(find.text('一次性 · 2 小时后'), findsOneWidget);
    expect(find.text('每周三 09:00'), findsOneWidget);
    expect(find.text('每月 5 号 10:30'), findsOneWidget);
    expect(find.byType(Switch), findsNWidgets(5));
    // Items without an enabled field default to enabled.
    expect(find.text('运行中'), findsNWidgets(5));
  });

  testWidgets('create sheet submits a cron automation via the port',
      (WidgetTester tester) async {
    final host = FakeAutomationHost(DeviceStatus.connected);
    await tester.pumpWidget(wrap(AutomationsPane(session: host)));
    await tester.pumpAndSettle();

    // Empty state offers the add button.
    await tester.tap(find.text('创建定时任务'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextField, '任务标题').first, '站会总结');
    await tester.enterText(
        find.widgetWithText(TextField, '指令').first, '总结昨天的 git 提交');
    await tester.pump();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    // createAutomation reached the (fake) port with the form values.
    final create = host.calls
        .where((c) => c.$1 == 'createAutomation')
        .toList();
    expect(create, hasLength(1));
    expect(create.single.$2, [
      {
        'title': '站会总结',
        'prompt': '总结昨天的 git 提交',
        'cronExpr': '0 9 * * *',
      },
    ]);
  });

  testWidgets('create sheet switches to one-shot and validates delay',
      (WidgetTester tester) async {
    final host = FakeAutomationHost(DeviceStatus.connected);
    await tester.pumpWidget(wrap(AutomationsPane(session: host)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('创建定时任务'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextField, '任务标题').first, 't');
    await tester.enterText(
        find.widgetWithText(TextField, '指令').first, 'p');
    await tester.tap(find.text('一次性延迟'));
    await tester.pumpAndSettle();
    // 0 minutes must fail validation and keep the sheet open.
    await tester.enterText(find.widgetWithText(TextField, '延迟分钟数'), '0');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('延迟需在 1 分钟到 1 年之间'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, '延迟分钟数'), '30');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    final create = host.calls
        .where((c) => c.$1 == 'createAutomation')
        .toList();
    expect(create.single.$2, [
      {
        'title': 't',
        'prompt': 'p',
        'relativeDelayMinutes': 30,
        'recurring': false,
        'maxRuns': 1,
      },
    ]);
  });

  testWidgets('delete asks for confirmation before calling the port',
      (WidgetTester tester) async {
    final host = FakeAutomationHost(DeviceStatus.connected, [
      {'automationId': 'a1', 'title': '日报', 'prompt': 'p',
       'cronExpr': '0 9 * * *'},
    ]);
    await tester.pumpWidget(wrap(AutomationsPane(session: host)));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();

    expect(find.text('删除定时任务'), findsOneWidget);
    // Not deleted yet — cancel first.
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(
        host.calls.where((c) => c.$1.contains('elete')), isEmpty);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除').last);
    await tester.pumpAndSettle();

    expect(
        host.calls.where((c) => c.$1.contains('elete')), hasLength(1));
  });

  testWidgets('scheduled page shows both sections with no devices',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final devices = DeviceStore();
    await devices.load();
    final hub = DeviceSessionHub(nativeListEnabled: () => false);

    await tester.pumpWidget(MaterialApp(
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      builder: (context, child) =>
          UiSettingsProvider(settings: UiSettings(), child: child!),
      home: ScheduledPage(
        devices: devices,
        hub: hub,
        store: ScheduledStore(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('设备自动化'), findsOneWidget);
    expect(find.text('本地定时发送'), findsOneWidget);
    expect(find.text('请先添加可用设备'), findsOneWidget);
    expect(find.text('暂无定时消息'), findsOneWidget);
  });
}
