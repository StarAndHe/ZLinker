import 'dart:async';

import '../notifications/notification_service.dart';
import '../notifications/notify_rules.dart';
import '../ui/ui_settings.dart';
import 'device_session.dart';

/// Bridges device sessions to local notifications:
/// - task events ride the live sessions-index stream (no extra RPC),
/// - off-peak results poll every 60s,
/// - automation runs poll every 120s,
/// all gated by the notification switches in settings. Errors are always
/// silent — notifications are an enhancement, never a failure surface.
class NotificationHub {
  final NotificationService service;
  final UiSettings ui;

  /// Resolves a device label for notification bodies.
  final String Function(String deviceId) deviceLabelOf;

  NotificationHub({
    required this.service,
    required this.ui,
    required this.deviceLabelOf,
  });

  static const offPeakPollInterval = Duration(seconds: 60);
  static const automationPollInterval = Duration(seconds: 120);

  final _tracked = <String, NotifiableSession>{};
  final _taskPhases = <String, Map<String, String>>{};
  final _offPeakStatuses = <String, Map<String, String>>{};
  final _autoLastRunAt = <String, Map<String, int>>{};
  /// 'device:session' keys already notified as waiting-for-decision; cleared
  /// once the session resolves (leaves the waiting state or loses its
  /// pending interaction).
  final _waitForDecision = <String>{};
  Timer? _offPeakTimer;
  Timer? _autoTimer;
  bool _disposed = false;

  String _tr(String key) => trLocale(ui.locale, key);

  bool get _master => ui.notificationsEnabled && service.isReady;

  /// Reconciles tracked sessions with the live hub sessions (main wires
  /// this to hub changes).
  void syncWith(Iterable<NotifiableSession> sessions) {
    if (_disposed) return;
    final seen = <String>{};
    for (final session in sessions) {
      seen.add(session.deviceId);
      if (!_tracked.containsKey(session.deviceId)) {
        _tracked[session.deviceId] = session;
        session.addListener(() => _onSessionChanged(session));
        // Baseline the task phases so pre-existing running tasks don't
        // fire completion notifications on the first tick.
        _snapshotPhases(session);
      }
    }
    for (final id in _tracked.keys.toList()) {
      if (!seen.contains(id)) {
        _tracked.remove(id);
        _taskPhases.remove(id);
        _offPeakStatuses.remove(id);
        _autoLastRunAt.remove(id);
        _waitForDecision.removeWhere((k) => k.startsWith('$id:'));
      }
    }
  }

  void start() {
    _offPeakTimer?.cancel();
    _autoTimer?.cancel();
    _offPeakTimer =
        Timer.periodic(offPeakPollInterval, (_) => pollOffPeakNow());
    _autoTimer =
        Timer.periodic(automationPollInterval, (_) => pollAutomationsNow());
  }

  void _snapshotPhases(NotifiableSession session) {
    final entries = session.allSessions;
    if (entries.isEmpty) return;
    _taskPhases[session.deviceId] = {
      for (final e in entries) e.sessionId: e.phase,
    };
  }

  void _onSessionChanged(NotifiableSession session) {
    if (_disposed) return;
    // NOTIFY_TASK: wait-for-decision tasks are now surfaced. A session whose
    // pendingInteraction is present while the phase is waiting (or running
    // with a pending interaction) is a "needs your decision" event. We use
    // the phase transitions for completion and a separate latched check for
    // the pending-interaction state below.
    final entries = session.allSessions;
    if (entries.isEmpty) return;
    final prev = _taskPhases.putIfAbsent(session.deviceId, () => {});
    final events = taskCompletionEvents(
      previousPhases: prev,
      sessions: [
        for (final e in entries)
          (sessionId: e.sessionId, title: e.title, phase: e.phase),
      ],
    );
    // Track phases even while silenced so re-enabling doesn't replay
    // history.
    _snapshotPhases(session);
    if (!_master || !ui.notifyTasksEnabled) return;
    for (final e in events) {
      final title = switch (e.phase) {
        'error' => _tr('notify.task.failed'),
        'completedInterrupted' => _tr('notify.task.interrupted'),
        _ => _tr('notify.task.done'),
      };
      unawaited(service.show(
        NotifyChannel.tasks,
        NotificationService.stableId('${session.deviceId}:${e.sessionId}'),
        title,
        e.title,
        {
          'type': 'task',
          'deviceId': session.deviceId,
          'sessionId': e.sessionId,
          'title': e.title,
        },
      ));
    }
    // Waiting-for-decision: a session that is `waiting` (or still `running`
    // while carrying a pendingInteraction) needs the user. Notify once per
    // sessionId via the latched set, cleared when the interaction resolves.
    for (final e in entries) {
      if (e.phase != 'waiting' && e.pendingInteraction == null) continue;
      final key = '${session.deviceId}:${e.sessionId}';
      if (_waitForDecision.contains(key)) continue;
      _waitForDecision.add(key);
      final title = e.pendingInteraction != null
          ? _tr('notify.task.waiting')
          : _tr('notify.task.waiting');
      unawaited(service.show(
        NotifyChannel.tasks,
        NotificationService.stableId('$key:wait'),
        title,
        e.title,
        {
          'type': 'task-waiting',
          'deviceId': session.deviceId,
          'sessionId': e.sessionId,
          'title': e.title,
        },
      ));
    }
    // Clear resolved latches (no longer waiting; no pending interaction).
    for (final key in _waitForDecision.toList()) {
      // key = device:session — find the entry again.
      final parts = key.split(':');
      if (parts.length != 2) {
        _waitForDecision.remove(key);
        continue;
      }
      final id = parts[1];
      final e = entries.where((x) => x.sessionId == id).firstOrNull;
      if (e == null || (e.phase != 'waiting' && e.pendingInteraction == null)) {
        _waitForDecision.remove(key);
      }
    }
  }

  /// Polls off-peak tasks of every connected session (public so tests and
  /// manual refreshes can drive it).
  Future<void> pollOffPeakNow() async {
    if (_disposed || !_master || !ui.notifyOffPeakEnabled) return;
    for (final session in _tracked.values.toList()) {
      if (session.status != DeviceStatus.connected) continue;
      await _pollOffPeak(session);
      if (_disposed) return;
    }
  }

  Future<void> _pollOffPeak(NotifiableSession session) async {
    try {
      final tasks = await session.offPeak.list();
      if (_disposed) return;
      final prev = _offPeakStatuses.putIfAbsent(session.deviceId, () => {});
      final events = offPeakEvents(previousStatuses: prev, tasks: tasks);
      _offPeakStatuses[session.deviceId] = {
        for (final t in tasks) t.id: t.status,
      };
      if (!_master || !ui.notifyOffPeakEnabled) return;
      for (final e in events) {
        final title =
            e.failed ? _tr('notify.offPeak.failed') : _tr('notify.offPeak.done');
        final body = e.task.title.isEmpty ? e.task.prompt : e.task.title;
        unawaited(service.show(
          NotifyChannel.offPeak,
          NotificationService.stableId(
              '${session.deviceId}:offpeak:${e.task.id}'),
          title,
          body,
          {
            'type': 'offPeak',
            'deviceId': session.deviceId,
            'sessionId': e.task.sessionId ?? e.task.conversationId,
            'title': body,
          },
        ));
      }
    } catch (_) {
      // Offline desktops / absent channels are expected on every poll.
    }
  }

  /// Polls automation runs of every connected session.
  Future<void> pollAutomationsNow() async {
    if (_disposed || !_master || !ui.notifyAutoEnabled) return;
    for (final session in _tracked.values.toList()) {
      if (session.status != DeviceStatus.connected) continue;
      await _pollAutomations(session);
      if (_disposed) return;
    }
  }

  Future<void> _pollAutomations(NotifiableSession session) async {
    try {
      final items = await session.automation.list();
      if (_disposed) return;
      final prev = _autoLastRunAt.putIfAbsent(session.deviceId, () => {});
      final events = automationRunEvents(
          previousLastRunAt: prev, items: items);
      _autoLastRunAt[session.deviceId] = {
        for (final item in items)
          if (item.lastRunAt != null) item.id: item.lastRunAt!,
      };
      if (!_master || !ui.notifyAutoEnabled) return;
      for (final e in events) {
        final title =
            e.failed ? _tr('notify.auto.failed') : _tr('notify.auto.done');
        final body = e.item.title.isEmpty ? e.item.id : e.item.title;
        unawaited(service.show(
          NotifyChannel.automations,
          NotificationService.stableId(
              '${session.deviceId}:auto:${e.item.id}:${e.item.lastRunAt}'),
          title,
          body,
          {
            'type': 'auto',
            'deviceId': session.deviceId,
            'sessionId': e.item.targetTaskId,
            'title': body,
          },
        ));
      }
    } catch (_) {
      // Older desktops without the automation port land here every poll.
    }
  }

  void dispose() {
    _disposed = true;
    _offPeakTimer?.cancel();
    _autoTimer?.cancel();
    _tracked.clear();
    _taskPhases.clear();
    _offPeakStatuses.clear();
    _autoLastRunAt.clear();
  }
}
