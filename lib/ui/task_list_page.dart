import 'package:flutter/material.dart';

import '../protocol/conversation.dart';
import '../state/device_session.dart';
import '../state/device_store.dart';
import 'device_usage_page.dart';
import 'model_providers_page.dart';
import 'remote_page.dart';
import 'theme.dart';
import 'ui_settings.dart';

/// Native task list of one device, driven by the live sessions-index
/// subscription. Tapping a task suspends the native connection and opens
/// the WebView remote page with a deep-link injection to that session.
class TaskListPage extends StatefulWidget {
  final DeviceStore store;
  final DeviceSessionHub hub;
  final Device device;
  const TaskListPage({
    super.key,
    required this.store,
    required this.hub,
    required this.device,
  });

  @override
  State<TaskListPage> createState() => _TaskListPageState();
}

class _TaskListPageState extends State<TaskListPage> {
  DeviceSession? get _session => widget.hub.sessionOf(widget.device.id);

  /// Suspend the native connection (one terminal per device), open the
  /// WebView, then let the hub reconnect ~1s after it pops.
  Future<void> _openRemote({String? targetSessionId, String? targetTitle}) async {
    await widget.store.touch(widget.device.id);
    await widget.hub.suspend(widget.device.id);
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => RemotePage(
        device: widget.device,
        targetSessionId: targetSessionId,
        targetTitle: targetTitle,
      ),
    ));
    widget.hub.scheduleResume(widget.device);
  }

  Future<void> _runOp(Future<void> Function() op) async {
    try {
      await op();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(trP(context, 'tasks.opFailed', ['$e']))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.device.label,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600)),
            Text(tr(context, 'tasks.title'),
                style:
                    TextStyle(fontSize: 11, color: ZInk.faint(context))),
          ],
        ),
        actions: [
          _workspacePicker(),
          PopupMenuButton<String>(
            onSelected: (v) {
              final session = _session;
              if (session == null) return;
              switch (v) {
                case 'usage':
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => DeviceUsagePage(session: session),
                  ));
                case 'providers':
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ModelProvidersPage(session: session),
                  ));
              }
            },
            itemBuilder: (c) => [
              PopupMenuItem(
                  value: 'usage', child: Text(tr(context, 'tasks.menu.usage'))),
              PopupMenuItem(
                  value: 'providers',
                  child: Text(tr(context, 'tasks.menu.providers'))),
            ],
          ),
          TextButton(
            onPressed: () => _openRemote(),
            child: Text(tr(context, 'tasks.openWeb')),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: widget.hub,
        builder: (context, _) {
          final session = _session;
          final sessions = session?.sessions;
          if (session == null ||
              session.status == DeviceStatus.error ||
              sessions == null) {
            return _fallback(context, session);
          }
          final list = sessions.list;
          if (list.isEmpty) {
            return Center(
              child: Text(tr(context, 'tasks.empty'),
                  style: TextStyle(color: ZInk.muted(context))),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              final ws = session.activeWorkspace;
              if (ws != null) await session.openWorkspace(ws);
            },
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) => _taskCard(list[i], session),
            ),
          );
        },
      ),
    );
  }

  /// Workspace switcher for devices with several open workspaces.
  Widget _workspacePicker() {
    final session = _session;
    final workspaces = session?.workspaces ?? const [];
    if (workspaces.length <= 1) return const SizedBox.shrink();
    final active = session?.activeWorkspace;
    return PopupMenuButton<Map<String, dynamic>>(
      tooltip: tr(context, 'tasks.workspaces'),
      itemBuilder: (c) => [
        for (final ws in workspaces)
          PopupMenuItem(
            value: ws,
            child: Row(
              children: [
                if (identical(ws, active))
                  const Icon(Icons.check, size: 18)
                else
                  const SizedBox(width: 18),
                const SizedBox(width: 8),
                Flexible(child: Text(workspaceTitle(ws),
                    overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
      ],
      onSelected: (ws) => session?.openWorkspace(ws),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(workspaceTitle(active ?? const {}),
                style: TextStyle(
                    fontSize: 13, color: ZInk.muted(context))),
            const SizedBox(width: 4),
            Icon(Icons.folder_outlined,
                size: 16, color: ZInk.muted(context)),
          ],
        ),
      ),
    );
  }

  Widget _fallback(BuildContext context, DeviceSession? session) {
    final connecting = session != null &&
        session.status != DeviceStatus.error &&
        session.status != DeviceStatus.disconnected;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (connecting)
              const CircularProgressIndicator()
            else
              Icon(Icons.cloud_off, size: 44, color: ZInk.ghost(context)),
            const SizedBox(height: 16),
            Text(
              connecting
                  ? tr(context, 'tasks.loading')
                  : tr(context, 'tasks.fallback.title'),
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: ZInk.solid(context)),
            ),
            const SizedBox(height: 8),
            Text(
              connecting ? '' : tr(context, 'tasks.fallback.body'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: ZInk.faint(context)),
            ),
            const SizedBox(height: 20),
            if (!connecting) ...[
              FilledButton(
                onPressed: () => _openRemote(),
                child: Text(tr(context, 'tasks.openWeb')),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => session?.connect(),
                child: Text(tr(context, 'tasks.retry')),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _taskCard(SessionEntry entry, DeviceSession session) {
    final (phaseLabel, phaseColor) = _phaseVisual(entry.phase);
    final preview = entry.lastAssistantPreview?.trim() ?? '';
    final running =
        entry.phase == 'running' || entry.phase == 'prewarming';
    final paused = entry.phase.toLowerCase().contains('pause');
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openRemote(
          targetSessionId: entry.sessionId,
          targetTitle: entry.title,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: _phaseDot(phaseColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.title.trim().isEmpty
                                ? tr(context, 'tasks.untitled')
                                : entry.title,
                            style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(phaseLabel,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: phaseColor)),
                      ],
                    ),
                    if (preview.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          preview,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12, color: ZInk.muted(context)),
                        ),
                      ),
                    const SizedBox(height: 6),
                    Text(
                      relativeTime(context, entry.lastActivityAt),
                      style: TextStyle(
                          fontSize: 11, color: ZInk.ghost(context)),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  switch (v) {
                    case 'stop':
                      _runOp(() => session.stopTask(entry.sessionId));
                    case 'pause':
                      _runOp(() => session.pauseTask(entry.sessionId));
                    case 'resume':
                      _runOp(() => session.resumeTask(entry.sessionId));
                  }
                },
                itemBuilder: (c) => [
                  PopupMenuItem(
                    value: 'stop',
                    enabled: running,
                    child: Row(
                      children: [
                        const Icon(Icons.stop_circle_outlined, size: 18),
                        const SizedBox(width: 8),
                        Text(tr(context, 'tasks.stop')),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'pause',
                    enabled: running,
                    child: Row(
                      children: [
                        const Icon(Icons.pause_circle_outline, size: 18),
                        const SizedBox(width: 8),
                        Text(tr(context, 'tasks.pause')),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'resume',
                    enabled: paused,
                    child: Row(
                      children: [
                        const Icon(Icons.play_circle_outline, size: 18),
                        const SizedBox(width: 8),
                        Text(tr(context, 'tasks.resume')),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _phaseDot(Color color) => Container(
        width: 8,
        height: 8,
        decoration:
            BoxDecoration(color: color, shape: BoxShape.circle),
      );

  (String, Color) _phaseVisual(String phase) {
    switch (phase) {
      case 'running':
        return (tr(context, 'phase.running'), ZColors.sky500);
      case 'prewarming':
        return (tr(context, 'phase.prewarming'), ZColors.sky400);
      case 'completedSuccess':
        return (tr(context, 'phase.completedSuccess'), ZColors.success);
      case 'completedInterrupted':
        return (tr(context, 'phase.completedInterrupted'), ZColors.neutral500);
      case 'error':
        return (tr(context, 'phase.error'), ZColors.danger);
      case 'draft':
        return (tr(context, 'phase.draft'), ZColors.neutral400);
      default:
        if (phase.toLowerCase().contains('pause')) {
          return (tr(context, 'phase.paused'), ZColors.neutral500);
        }
        return (phase, ZColors.neutral400);
    }
  }
}
