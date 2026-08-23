import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:zremote/ui/chat/markdown_view.dart';
import 'package:zremote/ui/theme.dart';
import 'package:zremote/ui/ui_settings.dart';

Widget wrap(Widget child) => MaterialApp(
      theme: buildDarkTheme(),
      darkTheme: buildDarkTheme(),
      builder: (context, child) =>
          UiSettingsProvider(settings: UiSettings(), child: child!),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders paragraphs and inline code', (tester) async {
    await tester.pumpWidget(wrap(const ZRemoteMarkdown(
        'Hello **world**, see `doThing()` for details.')));
    expect(find.textContaining('Hello'), findsOneWidget);
    expect(find.textContaining('doThing()'), findsOneWidget);
  });

  testWidgets('fenced code block gets language header + copy button',
      (tester) async {
    await tester.pumpWidget(wrap(const ZRemoteMarkdown(
        '```dart\nvoid main() {}\n```')));
    await tester.pumpAndSettle();
    expect(find.text('dart'), findsOneWidget);
    expect(find.byIcon(Icons.copy_outlined), findsOneWidget);

    await tester.tap(find.byIcon(Icons.copy_outlined));
    await tester.pumpAndSettle();
    expect(find.text('已复制'), findsOneWidget);
  });

  testWidgets('unordered list renders', (tester) async {
    await tester.pumpWidget(wrap(const ZRemoteMarkdown('- one\n- two')));
    expect(find.text('one'), findsOneWidget);
    expect(find.text('two'), findsOneWidget);
  });
}
