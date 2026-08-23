import 'method_probe.dart';

/// Task-level metadata commands (置顶 / 重命名 / 归档 / 标记未读) for the
/// task list and the chat page's "更多" menu.
///
/// Method-name status (2026-08): **NOT yet live-confirmed.** None of the
/// candidates below has been probed against a live desktop — unlike
/// `zcode-agent.listAllAutomations` (confirmed) these are best-effort names
/// following the `zcode-task` channel's naming convention
/// (`prepareWorkspace`, `getTaskTokenUsage`). Every operation runs through
/// [MethodProbe]: candidates are tried in order, only "no such method"
/// style rejections advance, and the first accepted method is remembered.
/// If the desktop rejects every candidate the first error is rethrown so
/// the UI can surface the real reason instead of silently no-oping.
///
/// Arg shape per method: the `zcode-task` channel takes one object merging
/// the workspace scope plus the task id. The id key follows the candidate's
/// own naming (`*Session*` → `sessionId`, otherwise `taskId`).
class TaskCommandsPort {
  /// Binds one RPC: the channel is fixed by the port owner, method/args vary.
  final Future<dynamic> Function(String method, List<Object?> args) call;

  /// Workspace scope (workspacePath/identity) merged into every payload.
  final Map<String, dynamic> Function() scopeOf;

  TaskCommandsPort(this.call, {Map<String, dynamic> Function()? scope})
      : scopeOf = scope ?? (() => const {});

  late final MethodProbe _probe = MethodProbe(call);

  static const _renameMethods = [
    'renameTask',
    'renameSession',
    'updateTaskTitle',
    'updateSessionTitle',
    'setSessionTitle',
  ];
  static const _pinMethods = [
    'pinTask',
    'pinSession',
    'setTaskPinned',
  ];
  static const _archiveMethods = [
    'archiveTask',
    'archiveSession',
    'setTaskArchived',
  ];
  static const _unreadMethods = [
    'markTaskUnread',
    'markSessionUnread',
    'setTaskUnread',
  ];

  Map<String, dynamic> _payload(String method, String taskId) => {
        ...scopeOf(),
        if (method.toLowerCase().contains('session'))
          'sessionId': taskId
        else
          'taskId': taskId,
      };

  Future<dynamic> _run(
    String op,
    List<String> methods,
    String taskId,
    Map<String, dynamic> fields,
  ) =>
      _probe.run(op, methods,
          argsOf: (method) => <Object?>[
                {..._payload(method, taskId), ...fields},
              ]);

  /// Renames a task (chat page "更多 → 重命名").
  Future<dynamic> rename(String taskId, String title) =>
      _run('rename', _renameMethods, taskId, {'title': title});

  /// Pins / unpins a task (置顶).
  Future<dynamic> setPinned(String taskId, bool pinned) =>
      _run('pin', _pinMethods, taskId, {'pinned': pinned});

  /// Archives / restores a task (归档).
  Future<dynamic> setArchived(String taskId, bool archived) =>
      _run('archive', _archiveMethods, taskId, {'archived': archived});

  /// Marks a task unread (标记未读).
  Future<dynamic> setUnread(String taskId, bool unread) =>
      _run('unread', _unreadMethods, taskId, {'unread': unread});
}
