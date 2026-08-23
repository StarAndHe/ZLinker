import 'dart:async';

import 'package:flutter/foundation.dart';

import '../protocol/connection_params.dart';
import '../protocol/conversation.dart';
import '../protocol/relay_client.dart';
import '../protocol/remote_client.dart';
import 'device_store.dart';

/// Mirrors `HC()` in the web client:
/// key = workspaceIdentity?.trim() || workspacePath.
String? workspaceKeyOf(Map<String, dynamic> w) {
  final identity = w['workspaceIdentity'];
  if (identity is String && identity.trim().isNotEmpty) {
    return identity.trim();
  }
  final path = w['workspacePath'];
  if (path is String && path.isNotEmpty) return path;
  for (final key in const ['workspaceKey', 'key', 'id']) {
    final v = w[key];
    if (v is String && v.isNotEmpty) return v;
  }
  return null;
}

String workspaceTitle(Map<String, dynamic> w) {
  final label = w['label'] as String?;
  if (label != null && label.isNotEmpty) return label;
  final path = w['workspacePath'] as String?;
  if (path != null && path.isNotEmpty) {
    final parts = path.split(RegExp(r'[\\/]'));
    return parts.lastWhere((p) => p.isNotEmpty, orElse: () => path);
  }
  final identity = w['workspaceIdentity'] as String?;
  if (identity != null && identity.isNotEmpty) return identity;
  return workspaceKeyOf(w) ?? '?';
}

enum DeviceStatus { disconnected, connecting, connected, error }

/// One native protocol connection to one device. Owns the full stack
/// (relay → bridge → conversation → sessions-index) and exposes just what
/// the native UI needs: online status, the live task list and task
/// commands.
///
/// Lifecycle notes (verified against the live server):
/// - A device (same sid) allows exactly ONE terminal connection. Before
///   handing the device over to the WebView, [suspend] must close this
///   connection cleanly, otherwise the WebView auth kicks us (or vice
///   versa).
/// - Being KICKED by another terminal is terminal for this session: no
///   auto-reconnect (the relay already suppresses it).
class DeviceSession extends ChangeNotifier {
  final String deviceId;
  final RemoteConnectionParams params;

  DeviceSession({required this.deviceId, required this.params});

  RemoteClient? _client;
  BridgeSession? _bridge;
  ConversationTransport? _conversation;
  SessionsIndexSubscription? _sessionsSub;
  StreamSubscription? _failureSub;
  Timer? _retryTimer;
  int _retryAttempts = 0;
  bool _disposed = false;
  bool _connecting = false;
  bool _kicked = false;
  String? _error;

  DeviceStatus _status = DeviceStatus.disconnected;
  List<Map<String, dynamic>> _workspaces = [];
  Map<String, dynamic>? _activeWorkspace;

  DeviceStatus get status => _status;
  bool get kicked => _kicked;
  String? get error => _error;

  /// Workspaces reported by bootstrap (raw maps).
  List<Map<String, dynamic>> get workspaces => _workspaces;
  Map<String, dynamic>? get activeWorkspace => _activeWorkspace;

  /// Live sessions-index state of the active workspace, if subscribed.
  SessionsIndexState? get sessions => _sessionsSub?.state;

  /// Sessions with phase running/prewarming — the card badge count.
  int get runningTaskCount => sessions?.list
          .where((e) => e.phase == 'running' || e.phase == 'prewarming')
          .length ??
      0;

  bool get _busy => _connecting;

  /// Connects and subscribes the sessions-index. Safe to call repeatedly;
  /// a live connection is reused, a retryable failure is re-attempted.
  Future<void> connect() async {
    if (_disposed || _busy || _status == DeviceStatus.connected) return;
    _connecting = true;
    _retryTimer?.cancel();
    _kicked = false;
    _error = null;
    _setStatus(DeviceStatus.connecting);
    final client = RemoteClient(params, onLog: _log);
    _failureSub = client.relay.failures.listen(_onRelayFailure);
    try {
      await client.connect();
      await client.waitPaired(timeout: const Duration(seconds: 90));
      if (_disposed) {
        await client.dispose();
        return;
      }
      _client = client;
      client.relay.stateListenable.addListener(_onRelayState);
      _onRelayState();
      final bootstrap = await client.bootstrap();
      final list = bootstrap['workspaces'];
      _workspaces = [
        if (list is List)
          for (final w in list)
            if (w is Map) w.cast<String, dynamic>(),
      ];
      _retryAttempts = 0;
      // Auto-open the single workspace (web mobile flow). With several
      // workspaces the task list page offers a picker.
      if (_workspaces.length == 1 && _activeWorkspace == null) {
        await openWorkspace(_workspaces.first);
      }
      _setStatus(DeviceStatus.connected);
    } catch (e) {
      await _failureSub?.cancel();
      _failureSub = null;
      if (_disposed) {
        await client.dispose();
        return;
      }
      await client.dispose();
      _error = '$e';
      _setStatus(DeviceStatus.error);
      _maybeScheduleRetry();
    } finally {
      _connecting = false;
    }
  }

  /// Failures worth retrying a few times: server unreachable or the
  /// desktop temporarily gone. Credential errors (expired URL, conflict,
  /// kicked) never retry — they need user action.
  void _maybeScheduleRetry() {
    if (_disposed || _kicked) return;
    final msg = _error ?? '';
    final retryable = msg.contains('relay-unavailable') ||
        msg.contains('desktop-disconnected') ||
        msg.contains('TimeoutException');
    if (!retryable || _retryAttempts >= 3) return;
    _retryAttempts += 1;
    _retryTimer?.cancel();
    _retryTimer = Timer(const Duration(seconds: 30), () {
      if (!_disposed && _status == DeviceStatus.error) connect();
    });
  }

  void _onRelayFailure(RelayFailure failure) {
    if (_disposed) return;
    _error = '$failure';
    _kicked = _kicked || failure.reason == 'kicked';
    if (_kicked) {
      // Another terminal took over; stay quiet until the user acts.
      _retryTimer?.cancel();
    }
    notifyListeners();
  }

  void _onRelayState() {
    if (_disposed) return;
    switch (_client?.relay.state) {
      case RelayState.paired:
        // Transient reconnects pass through here again; only clear the
        // error banner, sessions state keeps its last snapshot.
        if (_status == DeviceStatus.connecting ||
            _status == DeviceStatus.error) {
          _error = null;
          _setStatus(DeviceStatus.connected);
        }
      case RelayState.connecting:
      case RelayState.authenticating:
      case RelayState.waiting:
      case RelayState.reconnecting:
        if (_status != DeviceStatus.connected) {
          _setStatus(DeviceStatus.connecting);
        }
      case RelayState.kicked:
        _kicked = true;
        _setStatus(DeviceStatus.error);
      case RelayState.error:
        _setStatus(DeviceStatus.error);
      case RelayState.closed:
      case null:
      case RelayState.idle:
        break;
    }
  }

  void _setStatus(DeviceStatus s) {
    if (_status == s) return;
    _status = s;
    notifyListeners();
  }

  /// Opens (or switches to) a workspace bridge and subscribes its
  /// sessions-index. Switching disposes the previous bridge first.
  Future<void> openWorkspace(Map<String, dynamic> workspace) async {
    final key = workspaceKeyOf(workspace);
    final client = _client;
    if (key == null || client == null || _disposed) return;
    try {
      final bridge = await client.openBridge(key);
      if (_disposed || _client != client) {
        bridge.dispose();
        return;
      }
      final oldSub = _sessionsSub;
      final oldBridge = _bridge;
      _sessionsSub = null;
      _conversation = null;
      _bridge = bridge;
      _activeWorkspace = workspace;
      unawaited(oldSub?.dispose());
      oldBridge?.dispose();

      final scope = <String, dynamic>{
        'workspacePath': workspace['workspacePath'],
        if (workspace['workspaceIdentity'] != null)
          'workspaceIdentity': workspace['workspaceIdentity'],
      };
      final conversation = bridge.conversation(scope, onLog: _log);
      _conversation = conversation;
      final sub = await conversation.subscribeSessionsIndex();
      if (_disposed || _bridge != bridge) {
        await sub.dispose();
        return;
      }
      _sessionsSub = sub;
      sub.state.addListener(_onSessionsChanged);
      notifyListeners();
    } catch (e) {
      _log('[session] workspace open failed: $e');
      // The relay link itself is fine; only the native list is degraded.
      if (_status == DeviceStatus.connected) {
        _error = '$e';
        notifyListeners();
      }
    }
  }

  void _onSessionsChanged() {
    if (!_disposed) notifyListeners();
  }

  Future<void> stopTask(String sessionId) async {
    final conv = _conversation;
    if (conv == null) throw StateError('not connected');
    await conv.stop(sessionId);
  }

  Future<void> pauseTask(String sessionId) async {
    final conv = _conversation;
    if (conv == null) throw StateError('not connected');
    await conv.pauseGoal(sessionId);
  }

  Future<void> resumeTask(String sessionId) async {
    final conv = _conversation;
    if (conv == null) throw StateError('not connected');
    await conv.resumeGoal(sessionId);
  }

  /// Raw channel RPC over the active workspace bridge (usage-stats,
  /// model-provider, ...). Throws when no bridge is open.
  Future<dynamic> callChannel(String channel, String method,
      [List<Object?> args = const []]) async {
    final bridge = _bridge;
    if (bridge == null) throw StateError('not connected');
    await bridge.waitHealthy();
    return bridge.channels.call(channel, method, args);
  }

  /// Minimal automation primitive: creates a new task (session) on the
  /// active workspace with [text] as the first message. Returns the new
  /// sessionId.
  Future<String> createTaskWithMessage(String text) async {
    final conv = _conversation;
    if (conv == null) throw StateError('not connected');
    final workspaceId = sessions?.workspaceId ??
        (_activeWorkspace == null
            ? null
            : '${_activeWorkspace!['workspaceId'] ??
                workspaceKeyOf(_activeWorkspace!)}');
    if (workspaceId == null || workspaceId.isEmpty) {
      throw StateError('no workspace');
    }
    return conv.createSession(workspaceId, firstText: text);
  }

  /// Cleanly closes the connection so the in-app WebView (or another
  /// terminal) can take the slot without a KICK race. Callers reconnect
  /// via [connect] later (the hub adds the ~1s grace delay).
  Future<void> suspend() async {
    if (_disposed) return;
    _retryTimer?.cancel();
    _connecting = false;
    final client = _client;
    final bridge = _bridge;
    final sub = _sessionsSub;
    _client = null;
    _bridge = null;
    _conversation = null;
    _sessionsSub = null;
    _activeWorkspace = null;
    _workspaces = [];
    _kicked = false;
    _error = null;
    _setStatus(DeviceStatus.disconnected);
    await _failureSub?.cancel();
    _failureSub = null;
    unawaited(sub?.dispose());
    bridge?.dispose();
    await client?.dispose();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await suspend();
    super.dispose();
  }

  void _log(String line) => debugPrint('[$deviceId] $line');
}

/// Owns one [DeviceSession] per device and mediates the
/// native-connection ↔ WebView handover. Kept as a plain ChangeNotifier so
/// device cards can rebuild on any session change.
class DeviceSessionHub extends ChangeNotifier {
  /// Whether the native task list feature is enabled (settings switch).
  final bool Function() nativeListEnabled;

  /// Grace period after the WebView closes before the native connection
  /// comes back — the relay needs a moment to free the device slot.
  static const resumeDelay = Duration(seconds: 1);

  final Map<String, DeviceSession> _sessions = {};
  final Map<String, Timer> _resumes = {};
  bool _disposed = false;

  DeviceSessionHub({required this.nativeListEnabled});

  DeviceSession? sessionOf(String deviceId) => _sessions[deviceId];

  /// Ensures [device] has a (re)connecting native session. Returns null
  /// for devices whose URL cannot be parsed (no protocol layer possible).
  DeviceSession? ensure(Device device) {
    if (_disposed || !nativeListEnabled()) return null;
    final existing = _sessions[device.id];
    if (existing != null) {
      if (existing.status == DeviceStatus.disconnected ||
          (existing.status == DeviceStatus.error && !existing.kicked)) {
        unawaited(existing.connect());
      }
      return existing;
    }
    final params = device.params;
    if (params == null) return null;
    final session = DeviceSession(deviceId: device.id, params: params);
    _sessions[device.id] = session;
    session.addListener(_onSessionChanged);
    unawaited(session.connect());
    _onSessionChanged();
    return session;
  }

  /// Closes the native connection for the WebView handover. The pending
  /// resume timer (if any) is cancelled — the new one is armed by
  /// [scheduleResume] when the WebView page pops.
  Future<void> suspend(String deviceId) async {
    _resumes.remove(deviceId)?.cancel();
    final session = _sessions.remove(deviceId);
    if (session != null) {
      session.removeListener(_onSessionChanged);
      await session.suspend();
      _onSessionChanged();
    }
  }

  /// Reconnects [device] after [resumeDelay] (native list must be on).
  void scheduleResume(Device device) {
    if (_disposed || !nativeListEnabled()) return;
    final id = device.id;
    _resumes.remove(id)?.cancel();
    _resumes[id] = Timer(resumeDelay, () {
      _resumes.remove(id);
      if (_disposed) return;
      final current = _sessions[id];
      if (current == null) {
        ensure(device);
      } else if (current.status == DeviceStatus.disconnected) {
        unawaited(current.connect());
      }
    });
  }

  Future<void> disconnect(String deviceId) async {
    await suspend(deviceId);
  }

  /// Drops every native connection (native list disabled in settings).
  Future<void> disconnectAll() async {
    for (final id in _sessions.keys.toList()) {
      await disconnect(id);
    }
  }

  /// Reconciles native connections with the current device list and the
  /// native-list switch: connect new devices, drop removed ones, tear
  /// everything down when the feature is off.
  void syncWith(List<Device> devices) {
    if (_disposed) return;
    final ids = devices.map((d) => d.id).toSet();
    for (final id in _sessions.keys.toList()) {
      if (!ids.contains(id)) unawaited(disconnect(id));
    }
    if (nativeListEnabled()) {
      for (final d in devices) {
        ensure(d);
      }
    } else {
      unawaited(disconnectAll());
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    for (final t in _resumes.values) {
      t.cancel();
    }
    _resumes.clear();
    final all = _sessions.values.toList();
    _sessions.clear();
    for (final s in all) {
      s.removeListener(_onSessionChanged);
      await s.dispose();
    }
    super.dispose();
  }

  void _onSessionChanged() {
    if (!_disposed) notifyListeners();
  }
}
