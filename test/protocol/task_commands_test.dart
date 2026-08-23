import 'package:flutter_test/flutter_test.dart';

import 'package:zremote/protocol/channel_client.dart';
import 'package:zremote/protocol/task_commands.dart';

void main() {
  test('remembers the first accepted candidate and reuses it', () async {
    final calls = <(String, List<Object?>)>[];
    final port = TaskCommandsPort(
      (method, args) async {
        calls.add((method, args));
        if (method == 'renameTask') return {'ok': true};
        throw ChannelRpcError('no such method: $method', null);
      },
      scope: () => {'workspacePath': '/repo'},
    );

    final res = await port.rename('s1', '新标题');
    expect(res, {'ok': true});
    // only the first candidate was tried
    expect(calls.map((c) => c.$1).toList(), ['renameTask']);
    // payload merges scope + taskId + fields
    expect(calls.single.$2.single, {
      'workspacePath': '/repo',
      'taskId': 's1',
      'title': '新标题',
    });

    calls.clear();
    await port.rename('s1', 'again');
    expect(calls.map((c) => c.$1).toList(), ['renameTask']);
  });

  test('Session-named candidates key the id as sessionId', () async {
    final port = TaskCommandsPort(
      (method, args) async {
        if (method == 'renameSession') return null;
        throw ChannelRpcError('unknown method $method', null);
      },
    );
    await port.rename('s1', 't');
    // verified via the resolved-method behavior below (no throw) — arg
    // shape asserted through the sibling test above.
  });

  test('arg shape: *Session* methods carry sessionId, others taskId',
      () async {
    Map? seen;
    final port = TaskCommandsPort(
      (method, args) async {
        if (method == 'renameSession' || method == 'pinTask') {
          seen = (args.single as Map).cast<String, Object?>();
          return null;
        }
        throw ChannelRpcError('method not found: $method', null);
      },
    );
    await port.rename('s1', 't');
    expect(seen!['sessionId'], 's1');
    expect(seen!.containsKey('taskId'), isFalse);

    await port.setPinned('s1', true);
    expect(seen!['taskId'], 's1');
    expect(seen!['pinned'], true);
  });

  test('every candidate missing → first error rethrown', () async {
    final port = TaskCommandsPort(
      (method, args) async =>
          throw ChannelRpcError('no such method: $method', null),
    );
    expect(
      () => port.setArchived('s1', true),
      throwsA(isA<ChannelRpcError>()),
    );
  });

  test('validation errors do not advance to the next candidate', () async {
    final tried = <String>[];
    final port = TaskCommandsPort(
      (method, args) async {
        tried.add(method);
        throw ChannelRpcError('validation failed: title required', null);
      },
    );
    expect(
      () => port.rename('s1', 'x'),
      throwsA(isA<ChannelRpcError>()),
    );
    expect(tried, hasLength(1));
  });
}
