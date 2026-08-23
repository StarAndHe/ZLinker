import 'package:flutter/material.dart';

import '../protocol/conversation.dart';
import '../state/device_session.dart';
import '../state/device_store.dart';
import 'automations_page.dart';
import 'chat/chat_page.dart';
import 'device_usage_page.dart';
import 'model_providers_page.dart';
import 'off_peak_page.dart';
import 'phase_pill.dart';
import 'remote_page.dart';
import 'theme.dart';
import 'ui_settings.dart';

/// Native task list of one device (official mobile layout): a connection
/// banner, the "workspaces and tasks" header with stats, and one card per
/// workspace whose rows are the live sessions. Tapping a task opens the
/// NATIVE chat page (no WebView suspend); the WebView stays available from
/// the overflow menu as a fallback.
class TaskListPage extends StatefulWidget {
  final DeviceStore store;
  final DeviceSessionHub hub;
  final Device device;
  final ThemeController? theme;

  /// Test seam: overrides `hub.sessionOf(device.id)` when set.
  @visibleForTesting
  final DeviceSession? sessionOverride;

  const TaskListPage({
    super.key,
    required this.store,
    required this.hub,
    required this.device,
    this.theme,
    this.sessionOverride,
  });

  @override
  State<TaskListPage> createState() => _TaskListPageState();
}

class _TaskListPageState extends State<TaskListPage> {
  bool _collapsed = false;
  bool _runningFirst = false;
  final Set<String> _manualExpand = {};

  /// Dual-pane desktop selection (≥768px): the task opened in the right
  /// pane instead of a pushed route.
  String? _paneSessionId;
  String? _paneTitle;

  /// Official breakpoint: Tailwind md — single column below, dual ≥768.
  static const double kDualPaneBreakpoint = 768;

  /// Official sidebar width (`--workspace-sidebar-panel-width`).
  static const double kSidebarWidth = 264;

  DeviceSession? get _session =>
      widget.sessionOverride ?? widget.hub.sessionOf(widget.device.id);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= kDualPaneBreakpoint) {
          return _buildDualPane(context);
        }
        return _buildMobile(context);
      },
    );
  }

  Widget _buildMobile(BuildContext context) {
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
          _overflowMenu(),
        ],
      ),
      body: _listBody(context, compact: false),
    );
  }

  /// Official desktop layout: a 264px sidebar with its own slim header, a
  /// 1px divider, then the chat pane side by side.
  Widget _buildDualPane(BuildContext context) {
    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: kSidebarWidth,
            child: Column(
              children: [
                _sidebarHeader(context),
                Expanded(child: _listBody(context, compact: true)),
              ],
            ),
          ),
          VerticalDivider(
              width: 1, thickness: 1, color: ZInk.hairline(context)),
          Expanded(child: _chatPane(context)),
        ],
      ),
    );
  }

  /// Desktop sidebar header: back + device label + overflow menu (official
  /// sidebar top row parity).
  Widget _sidebarHeader(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          IconButton(
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            icon: const Icon(Icons.arrow_back, size: 20),
            color: ZInk.muted(context),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Text(widget.device.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: ZInk.solid(context))),
          ),
          _overflowMenu(),
        ],
      ),
    );
  }

  /// Right pane: the selected task's chat, or the empty placeholder.
  Widget _chatPane(BuildContext context) {
    final session = _session;
    final id = _paneSessionId;
    final title = _paneTitle;
    if (session == null || title == null) {
      return Center(
        child: Text(tr(context, 'tasks.paneHint'),
            style: TextStyle(fontSize: 13, color: ZInk.faint(context))),
      );
    }
    return ChatPage(
      key: ValueKey(id ?? 'draft'),
      gateway: session,
      sessionId: id,
      title: title,
      theme: widget.theme,
      embedded: true,
    );
  }

  Widget _overflowMenu() {
    return PopupMenuButton<String>(
      onSelected: _onMenu,
      itemBuilder: (c) => [
        PopupMenuItem(
            value: 'automations',
            child: Row(
              children: [
                const Icon(Icons.schedule_outlined, size: 18),
                const SizedBox(width: 8),
                Text(tr(context, 'tasks.menu.automations')),
              ],
            )),
        PopupMenuItem(
            value: 'offPeak',
            child: Row(
              children: [
                const Icon(Icons.nights_stay_outlined, size: 18),
                const SizedBox(width: 8),
                Text(tr(context, 'tasks.menu.offPeak')),
              ],
            )),
        PopupMenuItem(
            value: 'usage', child: Text(tr(context, 'tasks.menu.usage'))),
        PopupMenuItem(
            value: 'providers',
            child: Text(tr(context, 'tasks.menu.providers'))),
        PopupMenuItem(
            value: 'web',
            child: Row(
              children: [
                const Icon(Icons.open_in_browser, size: 18),
                const SizedBox(width: 8),
                Text(tr(context, 'tasks.openWeb')),
              ],
            )),
      ],
    );
  }

  Widget _listBody(BuildContext context, {required bool compact}) {
    return AnimatedBuilder(
      animation: widget.hub,
      builder: (context, _) {
        final session = _session;
        final banner = _ConnectionBanner(session: session, onWeb: _openRemote);
        final bannerOnline = session != null &&
            session.status == DeviceStatus.connected &&
            !session.kicked &&
            (session.error?.isEmpty ?? true);
        // The desktop sidebar skips the healthy status card (official
        // sidebar has none); degraded states still surface there.
        final showBanner = !compact || !bannerOnline;
        return RefreshIndicator(
          onRefresh: () async =>
              session?.reloadTasks() ?? widget.hub.ensure(widget.device),
          child: ListView(
            padding: EdgeInsets.fromLTRB(compact ? 8 : 12, 12, compact ? 8 : 12, 32),
            children: [
              if (showBanner) ...[
                banner,
                const SizedBox(height: 12),
              ],
              _headerRow(context, session, compact),
              const SizedBox(height: 12),
              if (session != null) ..._pinnedGroup(context, session),
              if (session == null || session.workspaces.isEmpty)
                _fallback(context, session)
              else
                for (final ws in session.workspaces)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _workspaceCard(context, session, ws, compact),
                  ),
            ],
          ),
        );
      },
    );
  }

  /// The official page always shows the connection status card at the top,
  /// even when the link is healthy (green online state + explanation).
  /// [compact] is the 264px desktop sidebar: smaller type, tighter icons.
  Widget _headerRow(BuildContext context, DeviceSession? session, bool compact) {
    final workspaces = session?.workspaces.length ?? 0;
    final tasks = session?.sessions?.list.length ?? 0;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr(context, 'tasks.sectionTitle'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: compact ? 14 : 16,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(
                trP(context, 'tasks.stats', ['$workspaces', '$tasks']),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: compact ? 11.5 : 12.5,
                    color: ZInk.faint(context)),
              ),
            ],
          ),
        ),
        for (final b in [
          (
            _collapsed
                ? tr(context, 'tasks.expandAll')
                : tr(context, 'tasks.collapseAll'),
            _collapsed
                ? Icons.unfold_more_outlined
                : Icons.unfold_less_outlined,
            ZInk.muted(context),
            () => setState(() {
                  _collapsed = !_collapsed;
                  if (_collapsed) _manualExpand.clear();
                }),
          ),
          (
            tr(context, 'tasks.tidy'),
            _runningFirst
                ? Icons.filter_alt_outlined
                : Icons.filter_alt_off_outlined,
            _runningFirst ? ZColors.sky500 : ZInk.muted(context),
            () => setState(() => _runningFirst = !_runningFirst),
          ),
          (
            tr(context, 'tasks.retry'),
            Icons.refresh,
            ZInk.muted(context),
            () {
              final s = _session;
              if (s != null) {
                s.reloadTasks();
              } else {
                widget.hub.ensure(widget.device);
              }
            },
          ),
        ])
          IconButton(
            tooltip: b.$1,
            icon: Icon(b.$2),
            iconSize: compact ? 18 : 20,
            color: b.$3,
            visualDensity:
                compact ? VisualDensity.compact : VisualDensity.standard,
            onPressed: b.$4,
          ),
      ],
    );
  }

  /// Official "已置顶" group above the workspace cards: one card per pinned
  /// task (title, workspace · time, phase pill).
  List<Widget> _pinnedGroup(BuildContext context, DeviceSession session) {
    final entries = session.sessions?.list
            .where((e) => e.raw['pinned'] == true)
            .toList() ??
        const <SessionEntry>[];
    if (entries.isEmpty) return const [];
    return [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(tr(context, 'tasks.pinned'),
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: ZInk.ghost(context))),
      ),
      for (final e in entries)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _pinnedCard(context, e),
        ),
    ];
  }

  Widget _pinnedCard(BuildContext context, SessionEntry entry) {
    final (phaseLabel, _) = _phaseVisual(entry.phase);
    final title = entry.title.trim().isEmpty
        ? tr(context, 'tasks.untitled')
        : entry.title;
    final ws = _session?.activeWorkspace;
    final subtitle = [
      if (ws != null) workspaceTitle(ws),
      relativeTime(context, entry.lastActivityAt),
    ].join(' · ');
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: ZInk.hairline(context)),
      ),
      child: InkWell(
        onTap: () => _openChat(sessionId: entry.sessionId, title: title),
        onLongPress: () {
          final s = _session;
          if (s != null) _taskActions(context, s, entry);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14.5, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12.5, color: ZInk.faint(context))),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              PhasePill(label: phaseLabel, phase: entry.phase, solid: true),
            ],
          ),
        ),
      ),
    );
  }

  /// One workspace card: name + 本地 badge, folder + path, updated-at, task
  /// count + chevron + new-task button; expanded shows the task rows.
  /// [compact] is the 264px desktop sidebar density.
  Widget _workspaceCard(
      BuildContext context, DeviceSession session, Map<String, dynamic> ws,
      [bool compact = false]) {
    final isActive = identical(session.activeWorkspace, ws) ||
        workspaceKeyOf(ws) == workspaceKeyOf(session.activeWorkspace ?? const {});
    final key = workspaceKeyOf(ws) ?? workspaceTitle(ws);
    var expanded = !_collapsed || _manualExpand.contains(key);
    if (!isActive) expanded = expanded && _manualExpand.contains(key);

    final sessions = isActive ? session.sessions : null;
    var entries = sessions?.ready == true ? sessions!.list : const <SessionEntry>[];
    if (_runningFirst) {
      entries = [...entries]..sort((a, b) {
          int rank(SessionEntry e) => e.phase == 'running' ||
                  e.phase == 'prewarming'
              ? 0
              : 1;
          final r = rank(a).compareTo(rank(b));
          return r != 0 ? r : b.lastActivityAt.compareTo(a.lastActivityAt);
        });
    }
    final lastActivity = entries.isEmpty
        ? null
        : entries.map((e) => e.lastActivityAt).reduce((a, b) => a > b ? a : b);
    // Official highlight: the "current" task row (latest running, else the
    // most recently active) gets a rounded white/10 background.
    final current = _currentEntry(entries);

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: ZInk.hairline(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () {
              if (!isActive) {
                session.openWorkspace(ws);
              }
              setState(() {
                if (expanded) {
                  _manualExpand.remove(key);
                } else {
                  _manualExpand.add(key);
                }
                if (!isActive) {
                  // freshly opened workspace starts expanded
                  _manualExpand.add(key);
                }
              });
            },
            child: Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: compact ? 12 : 16, vertical: compact ? 10 : 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(workspaceTitle(ws),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w600)),
                            ),
                            const SizedBox(width: 6),
                            _localBadge(context),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.folder_outlined,
                                size: 13, color: ZInk.ghost(context)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '${ws['workspacePath'] ?? ''}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 11.5,
                                    color: ZInk.faint(context)),
                              ),
                            ),
                          ],
                        ),
                        if (lastActivity != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            trP(context, 'tasks.updatedAt',
                                [relativeTime(context, lastActivity)]),
                            style: TextStyle(
                                fontSize: 11, color: ZInk.ghost(context)),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (isActive)
                    Text(
                      trP(context, 'tasks.taskCount', ['${entries.length}']),
                      style: TextStyle(
                          fontSize: 11.5, color: ZInk.faint(context)),
                    ),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 20,
                    color: ZInk.ghost(context),
                  ),
                  const SizedBox(width: 4),
                  _newTaskButton(context, session),
                ],
              ),
            ),
          ),
          if (expanded && isActive && sessions != null) ...[
            Divider(height: 1, color: ZInk.hairline(context)),
            if (!sessions.ready)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                    child:
                        SizedBox(child: CircularProgressIndicator(strokeWidth: 2))),
              )
            else if (entries.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Text(tr(context, 'tasks.empty'),
                      style:
                          TextStyle(fontSize: 12.5, color: ZInk.faint(context))),
                ),
              )
            else
              for (var i = 0; i < entries.length; i++)
                _taskRow(context, session, entries[i],
                    highlight: current != null &&
                        entries[i].sessionId == current.sessionId,
                    compact: compact),
          ],
        ],
      ),
    );
  }

  /// The row the official page highlights: the latest running task, falling
  /// back to the most recently active one.
  static SessionEntry? _currentEntry(List<SessionEntry> entries) {
    SessionEntry? current;
    for (final e in entries) {
      final running = e.phase == 'running' || e.phase == 'prewarming';
      if (running &&
          (current == null || e.lastActivityAt > current.lastActivityAt)) {
        current = e;
      }
    }
    if (current != null || entries.isEmpty) return current;
    return entries.reduce((a, b) => a.lastActivityAt > b.lastActivityAt ? a : b);
  }

  Widget _localBadge(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: ZInk.tile(context),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(tr(context, 'tasks.local'),
          style: TextStyle(fontSize: 10, color: ZInk.faint(context))),
    );
  }

  /// ➕ starts a draft chat (createSession fires on first send).
  Widget _newTaskButton(BuildContext context, DeviceSession session) {
    return SizedBox(
      width: 34,
      height: 34,
      child: IconButton(
        tooltip: tr(context, 'tasks.new'),
        padding: EdgeInsets.zero,
        icon: Icon(Icons.add_circle_outline,
            size: 20, color: ZInk.muted(context)),
        onPressed: () => _openChat(title: tr(context, 'tasks.new')),
      ),
    );
  }

  /// One task row: title + phase pill + relative time. No per-row overflow
  /// button (official mobile parity) — a long press opens the action sheet.
  /// The current (latest running / most recent) row gets the official
  /// rounded white/10 highlight.
  Widget _taskRow(
      BuildContext context, DeviceSession session, SessionEntry entry,
      {bool highlight = false, bool compact = false}) {
    final (phaseLabel, _) = _phaseVisual(entry.phase);
    final title = entry.title.trim().isEmpty
        ? tr(context, 'tasks.untitled')
        : entry.title;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 8, vertical: 1),
      child: Material(
        color: highlight
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _openChat(
            sessionId: entry.sessionId,
            title: title,
          ),
          onLongPress: () => _taskActions(context, session, entry),
          child: Padding(
            padding: EdgeInsets.fromLTRB(10, compact ? 7 : 9, 10, compact ? 7 : 9),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: compact ? 14 : 14.5,
                              fontWeight: FontWeight.w500)),
                      const SizedBox(height: 3),
                      Text(
                        relativeTime(context, entry.lastActivityAt),
                        style: TextStyle(
                            fontSize: compact ? 11.5 : 12.5,
                            color: ZInk.faint(context)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                PhasePill(label: phaseLabel, phase: entry.phase, solid: true),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Long-press action sheet: stop / pause / resume (enabled per phase).
  Future<void> _taskActions(
      BuildContext context, DeviceSession session, SessionEntry entry) {
    final running =
        entry.phase == 'running' || entry.phase == 'prewarming';
    final paused = entry.phase.toLowerCase().contains('pause');
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.stop_circle_outlined),
              title: Text(tr(sheetCtx, 'tasks.stop')),
              enabled: running,
              onTap: () {
                Navigator.of(sheetCtx).pop();
                _runOp(() => session.stopTask(entry.sessionId));
              },
            ),
            ListTile(
              leading: const Icon(Icons.pause_circle_outline),
              title: Text(tr(sheetCtx, 'tasks.pause')),
              enabled: running,
              onTap: () {
                Navigator.of(sheetCtx).pop();
                _runOp(() => session.pauseTask(entry.sessionId));
              },
            ),
            ListTile(
              leading: const Icon(Icons.play_circle_outline),
              title: Text(tr(sheetCtx, 'tasks.resume')),
              enabled: paused,
              onTap: () {
                Navigator.of(sheetCtx).pop();
                _runOp(() => session.resumeTask(entry.sessionId));
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Opens a task chat. On ≥768px the chat lands in the right pane (the
  /// native connection STAYS live — one sid, one terminal, and we are it);
  /// on phones it pushes the full-screen page. Falls back to the WebView
  /// deep link when no protocol session exists.
  Future<void> _openChat({String? sessionId, required String title}) async {
    final session = _session;
    if (session == null || session.status == DeviceStatus.disconnected) {
      await _openRemote(targetSessionId: sessionId, targetTitle: title);
      return;
    }
    await widget.store.touch(widget.device.id);
    if (!mounted) return;
    if (MediaQuery.sizeOf(context).width >= kDualPaneBreakpoint) {
      setState(() {
        _paneSessionId = sessionId;
        _paneTitle = title;
      });
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ChatPage(
        gateway: session,
        sessionId: sessionId,
        title: title,
        theme: widget.theme,
      ),
    ));
  }

  /// WebView fallback (overflow menu): suspend the native connection, open
  /// the remote page deep-linked to a session, resume ~1s after it pops.
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

  void _onMenu(String v) {
    final session = _session;
    switch (v) {
      case 'usage':
        if (session == null) return;
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => DeviceUsagePage(session: session),
        ));
      case 'providers':
        if (session == null) return;
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ModelProvidersPage(session: session),
        ));
      case 'automations':
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => AutomationsPage(
            store: widget.store,
            hub: widget.hub,
            initialDeviceId: widget.device.id,
          ),
        ));
      case 'offPeak':
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => OffPeakPage(
            store: widget.store,
            hub: widget.hub,
            device: widget.device,
          ),
        ));
      case 'web':
        _openRemote();
    }
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
    final error = session?.error;
    final connecting = session != null &&
        session.status != DeviceStatus.error &&
        session.status != DeviceStatus.disconnected &&
        (session.status == DeviceStatus.connecting ||
            session.openingWorkspace);
    if (connecting) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: Column(
            children: [
              const CircularProgressIndicator(strokeWidth: 2),
              const SizedBox(height: 16),
              Text(tr(context, 'tasks.loading'),
                  style:
                      TextStyle(fontSize: 13, color: ZInk.faint(context))),
            ],
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.cloud_off, size: 44, color: ZInk.ghost(context)),
            const SizedBox(height: 16),
            Text(
              tr(context, 'tasks.fallback.title'),
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: ZInk.solid(context)),
            ),
            const SizedBox(height: 8),
            Text(
              error ?? tr(context, 'tasks.fallback.body'),
              textAlign: TextAlign.center,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style:
                  TextStyle(fontSize: 13, color: ZInk.faint(context)),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => _openRemote(),
              child: Text(tr(context, 'tasks.openWeb')),
            ),
          ],
        ),
      ),
    );
  }

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

/// Connection status card at the top of the list (official mobile layout).
/// Always visible: the healthy link shows the green online state plus the
/// explanation copy; degraded states add retry + web fallback actions.
class _ConnectionBanner extends StatelessWidget {
  final DeviceSession? session;
  final Future<void> Function() onWeb;

  const _ConnectionBanner({required this.session, required this.onWeb});

  bool get _online =>
      session != null &&
      session!.status == DeviceStatus.connected &&
      !session!.kicked &&
      (session!.error?.isEmpty ?? true);

  @override
  Widget build(BuildContext context) {
    if (_online) return _onlineCard(context);
    return _degradedCard(context);
  }

  /// Official online state: title + green subtitle + explanation card.
  Widget _onlineCard(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 2, 4, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr(context, 'tasks.banner.onlineTitle'),
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: ZInk.solid(context))),
              const SizedBox(height: 3),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.circle,
                      size: 7, color: ZColors.pillSuccessBg),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(tr(context, 'tasks.banner.onlineSubtitle'),
                        style: const TextStyle(
                            fontSize: 12.5, color: ZColors.pillSuccessBg)),
                  ),
                ],
              ),
            ],
          ),
        ),
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: ZInk.hairline(context)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              tr(context, 'tasks.banner.onlineDesc'),
              style: TextStyle(
                  fontSize: 13, height: 1.6, color: ZInk.faint(context)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _degradedCard(BuildContext context) {
    final s = session;
    String title;
    String body;
    IconData icon;
    Color color;
    if (s == null) {
      title = tr(context, 'status.offline');
      body = tr(context, 'tasks.banner.nativeOff');
      icon = Icons.cloud_off;
      color = ZColors.neutral400;
    } else if (s.kicked) {
      title = tr(context, 'status.kicked');
      body = tr(context, 'tasks.banner.kicked');
      icon = Icons.phonelink_erase_outlined;
      color = ZColors.danger;
    } else if (s.status == DeviceStatus.connecting) {
      title = tr(context, 'status.connecting');
      body = tr(context, 'tasks.banner.connecting');
      icon = Icons.sync;
      color = ZColors.sky400;
    } else {
      title = tr(context, 'tasks.fallback.title');
      body = s.error ?? tr(context, 'tasks.fallback.body');
      icon = Icons.cloud_off;
      color = ZColors.danger;
    }
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: ZInk.hairline(context)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: ZInk.solid(context))),
                  const SizedBox(height: 4),
                  Text(body,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12, color: ZInk.faint(context))),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Flexible(
                        child: FilledButton.tonal(
                          onPressed: () {
                            final s2 = session;
                            if (s2 != null) {
                              s2.reloadTasks();
                            }
                          },
                          child: Text(tr(context, 'tasks.retry'),
                              style:
                                  const TextStyle(fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: TextButton(
                          onPressed: onWeb,
                          child: Text(tr(context, 'tasks.openWeb'),
                              style: const TextStyle(fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
