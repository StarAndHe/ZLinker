import 'dart:async';

import 'package:flutter/material.dart';

import '../protocol/off_peak.dart';
import '../state/device_session.dart';
import '../state/device_store.dart';
import 'remote_page.dart';
import 'theme.dart';
import 'ui_settings.dart';

/// Off-peak tasks (闲时任务) of one device: free queued runs executed in
/// compute-rich windows (Coding Plan only, monthly quota). Results open
/// the WebView remote page deep-linked to the produced session.
class OffPeakPage extends StatefulWidget {
  final DeviceStore store;
  final DeviceSessionHub hub;
  final Device device;

  /// Test seam: overrides the hub-resolved device session.
  final OffPeakHost? hostOverride;
  const OffPeakPage({
    super.key,
    required this.store,
    required this.hub,
    required this.device,
    this.hostOverride,
  });

  @override
  State<OffPeakPage> createState() => _OffPeakPageState();
}

class _OffPeakPageState extends State<OffPeakPage> {
  OffPeakHost? get _session =>
      widget.hostOverride ?? widget.hub.sessionOf(widget.device.id);

  List<OffPeakTask> _tasks = const [];
  OffPeakStatus? _status;
  bool _loading = true;
  String? _error;
  bool _busy = false;
  Timer? _refresh;

  @override
  void initState() {
    super.initState();
    _load();
    // Queue position (排队位置) moves server-side; poll while visible.
    _refresh = Timer.periodic(const Duration(seconds: 30), (_) => _load());
  }

  @override
  void dispose() {
    _refresh?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final session = _session;
    if (session == null || session.status != DeviceStatus.connected) {
      if (mounted) {
        setState(() {
          _loading = session != null &&
              session.status == DeviceStatus.connecting;
          _error = null;
        });
      }
      return;
    }
    try {
      final tasks = await session.offPeak.list();
      unawaited(session.offPeak.wake());
      final status = await session.offPeak.status();
      if (!mounted) return;
      setState(() {
        _tasks = tasks;
        _status = status;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  Future<void> _runOp(Future<void> Function() op) async {
    if (_busy) return;
    _busy = true;
    try {
      await op();
    } on OffPeakError catch (e) {
      if (mounted) _toast(_offPeakErrorText(context, e));
    } catch (e) {
      if (mounted) _toast(trP(context, 'op.err.other', ['$e']));
    } finally {
      _busy = false;
    }
  }

  void _toast(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  /// Official error copy for the three known error states.
  String _offPeakErrorText(BuildContext context, OffPeakError e) =>
      switch (e.kind) {
        OffPeakError.codingPlanOnly => tr(context, 'op.err.codingPlanOnly'),
        OffPeakError.quota => tr(context, 'op.err.quota'),
        OffPeakError.unavailable => tr(context, 'op.err.unavailable'),
        _ => trP(context, 'op.err.other', [e.message]),
      };

  Future<void> _showAddSheet() async {
    final session = _session;
    if (session == null || session.status != DeviceStatus.connected) {
      _toast(tr(context, 'op.unavailable.title'));
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (c) => OffPeakSheet(session: session),
    );
    await _load();
  }

  /// Mirrors the task list's handover: suspend the native connection, open
  /// the WebView deep-linked to the result session, resume after pop.
  Future<void> _openResult(OffPeakTask task) async {
    final sessionId = task.sessionId ?? task.conversationId;
    if (sessionId == null) return;
    await widget.store.touch(widget.device.id);
    await widget.hub.suspend(widget.device.id);
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => RemotePage(
        device: widget.device,
        targetSessionId: sessionId,
        targetTitle: task.title.isEmpty ? null : task.title,
      ),
    ));
    widget.hub.scheduleResume(widget.device);
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.device.label,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600)),
            Text(tr(context, 'op.subtitle'),
                style: TextStyle(fontSize: 11, color: ZInk.faint(context))),
          ],
        ),
        actions: [
          IconButton(
            tooltip: tr(context, 'tasks.retry'),
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddSheet,
        icon: const Icon(Icons.add),
        label: Text(tr(context, 'op.add')),
      ),
      body: AnimatedBuilder(
        animation: widget.hub,
        builder: (context, _) {
          if (session == null ||
              session.status == DeviceStatus.disconnected ||
              session.status == DeviceStatus.error) {
            return _centerNote(context, tr(context, 'op.unavailable.title'),
                tr(context, 'op.unavailable.body'));
          }
          if (_loading && _tasks.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(tr(context, 'op.loading'),
                      style: TextStyle(
                          fontSize: 13, color: ZInk.faint(context))),
                ],
              ),
            );
          }
          final active = _tasks.where((t) => !t.terminal).toList();
          final history = _tasks.where((t) => t.terminal).toList();
          return RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                _quotaHeader(context),
                if (_error != null && _tasks.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(trP(context, 'op.loadFailed', [_error!]),
                        style: TextStyle(
                            fontSize: 12, color: ZColors.danger)),
                  ),
                if (active.isNotEmpty) ...[
                  _sectionLabel(context, tr(context, 'op.section.active')),
                  for (final t in active) ...[
                    _taskCard(t),
                    const SizedBox(height: 8),
                  ],
                ],
                if (history.isNotEmpty) ...[
                  _sectionLabel(context, tr(context, 'op.section.history')),
                  for (final t in history) ...[
                    _taskCard(t),
                    const SizedBox(height: 8),
                  ],
                ],
                if (_tasks.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Text(tr(context, 'op.empty'),
                          style: TextStyle(color: ZInk.muted(context))),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        child: Text(text,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: ZInk.muted(context))),
      );

  /// 额度余量 + 最早可用 (page header per the official layout).
  Widget _quotaHeader(BuildContext context) {
    final status = _status;
    if (status == null) return const SizedBox.shrink();
    if (!status.entitled) {
      final text = switch (status.reason) {
        OffPeakError.codingPlanOnly => tr(context, 'op.err.codingPlanOnly'),
        OffPeakError.quota => tr(context, 'op.err.quota'),
        _ => tr(context, 'op.err.unavailable'),
      };
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const Icon(Icons.lock_outline, size: 18, color: ZColors.danger),
              const SizedBox(width: 10),
              Expanded(
                child: Text(text,
                    style:
                        TextStyle(fontSize: 13, color: ZInk.soft(context))),
              ),
            ],
          ),
        ),
      );
    }
    final parts = <String>[
      if (status.quotaRemainingMinutes != null)
        trP(context, 'op.quota',
            [formatMinutes(context, status.quotaRemainingMinutes!)]),
      if (status.earliestAvailableAt != null)
        trP(context, 'op.earliest',
            [relativeTime(context, status.earliestAvailableAt!)]),
    ];
    if (parts.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.bolt_outlined, size: 18, color: ZColors.sky500),
            const SizedBox(width: 10),
            Expanded(
              child: Text(parts.join(' · '),
                  style:
                      TextStyle(fontSize: 13, color: ZInk.soft(context))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _taskCard(OffPeakTask task) {
    final (statusLabel, statusColor) = _statusVisual(task);
    final canViewResult = task.completed && task.sessionId != null;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Container(
                width: 8,
                height: 8,
                decoration:
                    BoxDecoration(color: statusColor, shape: BoxShape.circle),
              ),
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
                          task.title.isEmpty ? task.prompt : task.title,
                          style: const TextStyle(
                              fontSize: 14.5, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 排队位置徽标: sky 数字 + 浅色底 (official shape).
                      if (task.queued && task.queuePosition != null)
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: ZColors.sky500.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '#${task.queuePosition}',
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: ZColors.sky500),
                          ),
                        ),
                      Text(statusLabel,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: statusColor)),
                    ],
                  ),
                  if (task.prompt.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        task.prompt,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12, color: ZInk.muted(context)),
                      ),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    [
                      if (task.createdAt != null)
                        relativeTime(context, task.createdAt!),
                      if (task.durationMs != null)
                        trP(context, 'op.duration', [
                          formatMinutes(context, task.durationMs! ~/ 60000)
                        ]),
                    ].join(' · '),
                    style:
                        TextStyle(fontSize: 11, color: ZInk.ghost(context)),
                  ),
                  if (task.failed && task.error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        task.error!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style:
                            TextStyle(fontSize: 11, color: ZColors.danger),
                      ),
                    ),
                  if (canViewResult)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: FilledButton.tonalIcon(
                        onPressed: () => _openResult(task),
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: Text(tr(context, 'op.viewResult')),
                        style: FilledButton.styleFrom(
                            visualDensity: VisualDensity.compact),
                      ),
                    ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (v) => _menuAction(task, v),
              itemBuilder: (c) => [
                if (task.running || task.queued)
                  PopupMenuItem(
                    value: 'pause',
                    child: Row(
                      children: [
                        const Icon(Icons.pause_circle_outline, size: 18),
                        const SizedBox(width: 8),
                        Text(tr(context, 'tasks.pause')),
                      ],
                    ),
                  ),
                if (task.paused)
                  PopupMenuItem(
                    value: 'resume',
                    child: Row(
                      children: [
                        const Icon(Icons.play_circle_outline, size: 18),
                        const SizedBox(width: 8),
                        Text(tr(context, 'tasks.resume')),
                      ],
                    ),
                  ),
                if (!task.terminal)
                  PopupMenuItem(
                    value: 'cancel',
                    child: Row(
                      children: [
                        const Icon(Icons.stop_circle_outlined, size: 18),
                        const SizedBox(width: 8),
                        Text(tr(context, 'op.cancel')),
                      ],
                    ),
                  ),
                if (task.terminal)
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        const Icon(Icons.delete_outline, size: 18),
                        const SizedBox(width: 8),
                        Text(tr(context, 'devices.menu.delete'),
                            style: TextStyle(
                                color: Theme.of(c).colorScheme.error)),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _menuAction(OffPeakTask task, String action) async {
    final session = _session;
    if (session == null) return;
    switch (action) {
      case 'pause':
        await _runOp(() => session.offPeak.pause(task.id));
      case 'resume':
        await _runOp(() => session.offPeak.resume(task.id));
      case 'cancel':
        await _runOp(() => session.offPeak.cancel(task.id));
      case 'delete':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(tr(context, 'op.deleteTitle')),
            content: Text(trP(
                context,
                'op.deleteBody',
                [task.title.isEmpty ? task.prompt : task.title])),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(c, false),
                  child: Text(tr(context, 'devices.add.cancel'))),
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(c).colorScheme.error,
                    foregroundColor: Theme.of(c).colorScheme.onError),
                onPressed: () => Navigator.pop(c, true),
                child: Text(tr(context, 'devices.delete.confirm')),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          await _runOp(() => session.offPeak.remove(task.id));
        }
    }
    await _load();
  }

  (String, Color) _statusVisual(OffPeakTask task) => switch (task.status) {
        'queued' => (tr(context, 'op.status.queued'), ZColors.sky500),
        'running' => (tr(context, 'op.status.running'), ZColors.success),
        'paused' => (tr(context, 'op.status.paused'), ZColors.neutral500),
        'completed' => (tr(context, 'op.status.completed'), ZColors.success),
        'failed' => (tr(context, 'op.status.failed'), ZColors.danger),
        'cancelled' => (tr(context, 'op.status.cancelled'), ZColors.neutral500),
        _ => (task.status, ZColors.neutral400),
      };

  Widget _centerNote(BuildContext context, String title, String body) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 44, color: ZInk.ghost(context)),
            const SizedBox(height: 16),
            Text(title,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: ZInk.solid(context))),
            const SizedBox(height: 8),
            Text(body,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: ZInk.faint(context))),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => widget.hub.ensure(widget.device),
              child: Text(tr(context, 'tasks.retry')),
            ),
          ],
        ),
      ),
    );
  }
}

/// Create form (bottom sheet): 标题 → 指令 → 模型 → 时间选项 → 权限模式,
/// plus three quick templates that prefill title + prompt.
///
/// 保持唤醒 (keepAwake) is a local preference: it keeps the native
/// connection alive so results (and later notifications) arrive — it is
/// not part of the off-peak-run wire schema.
class OffPeakSheet extends StatefulWidget {
  final OffPeakHost session;
  const OffPeakSheet({super.key, required this.session});

  @override
  State<OffPeakSheet> createState() => _OffPeakSheetState();
}

class _OffPeakSheetState extends State<OffPeakSheet> {
  final _title = TextEditingController();
  final _prompt = TextEditingController();
  final _model = TextEditingController();
  DateTime? _earliest;
  bool _keepAwake = true;
  String _permission = 'build';
  bool _submitting = false;

  static const _templateKeys = ['tpl.ci', 'tpl.docs', 'tpl.standup'];

  @override
  void dispose() {
    _title.dispose();
    _prompt.dispose();
    _model.dispose();
    super.dispose();
  }

  Future<void> _pickEarliest() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _earliest ?? DateTime.now().add(const Duration(hours: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
          _earliest ?? DateTime.now().add(const Duration(hours: 1))),
    );
    if (time == null || !mounted) return;
    setState(() {
      _earliest = DateTime(
          date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (_prompt.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr(context, 'op.err.prompt'))));
      return;
    }
    final scope = widget.session.offPeakScope;
    final workspacePath = '${scope['workspacePath'] ?? ''}';
    if (workspacePath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr(context, 'op.err.noWorkspace'))));
      return;
    }
    setState(() => _submitting = true);
    try {
      await widget.session.offPeak.submit(OffPeakSubmitInput(
        prompt: _prompt.text,
        workspacePath: workspacePath,
        workspaceIdentity: scope['workspaceIdentity'] as String?,
        permissionMode: _permission,
        model: _model.text.trim().isEmpty ? null : _model.text.trim(),
        earliestAtMs: _earliest?.millisecondsSinceEpoch,
        title: _title.text.trim().isEmpty ? null : _title.text.trim(),
      ));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr(context, 'op.created'))));
      Navigator.pop(context);
    } on OffPeakError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_errorText(context, e))));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(trP(context, 'op.err.other', ['$e']))));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _errorText(BuildContext context, OffPeakError e) => switch (e.kind) {
        OffPeakError.codingPlanOnly => tr(context, 'op.err.codingPlanOnly'),
        OffPeakError.quota => tr(context, 'op.err.quota'),
        OffPeakError.unavailable => tr(context, 'op.err.unavailable'),
        _ => trP(context, 'op.err.other', [e.message]),
      };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr(context, 'op.add'),
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(tr(context, 'op.hint'),
                style: TextStyle(fontSize: 11, color: ZInk.muted(context))),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final key in _templateKeys)
                  ActionChip(
                    label: Text(tr(context, 'op.$key.title'),
                        style: const TextStyle(fontSize: 12)),
                    onPressed: () => setState(() {
                          _title.text = tr(context, 'op.$key.title');
                          _prompt.text = tr(context, 'op.$key.prompt');
                        }),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              decoration: InputDecoration(labelText: tr(context, 'op.name')),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _prompt,
              maxLines: 3,
              decoration:
                  InputDecoration(labelText: tr(context, 'op.prompt')),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _model,
              decoration: InputDecoration(
                  labelText: tr(context, 'op.model'), hintText: 'GLM-5.2'),
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: _pickEarliest,
              borderRadius: BorderRadius.circular(8),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: tr(context, 'op.earliestAt'),
                  suffixIcon: const Icon(Icons.event_outlined, size: 18),
                ),
                child: Text(
                  _earliest == null
                      ? tr(context, 'op.earliest.any')
                      : _fmt(_earliest!),
                  style: TextStyle(
                      fontSize: 13,
                      color: _earliest == null
                          ? ZInk.ghost(context)
                          : ZInk.soft(context)),
                ),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(tr(context, 'op.keepAwake'),
                  style: const TextStyle(fontSize: 13)),
              subtitle: Text(tr(context, 'op.keepAwakeHint'),
                  style:
                      TextStyle(fontSize: 11, color: ZInk.faint(context))),
              value: _keepAwake,
              onChanged: (v) => setState(() => _keepAwake = v),
            ),
            DropdownButtonFormField<String>(
              initialValue: _permission,
              decoration:
                  InputDecoration(labelText: tr(context, 'op.permission')),
              items: [
                for (final m in const ['build', 'plan', 'yolo'])
                  DropdownMenuItem(
                      value: m, child: Text(tr(context, 'op.permission.$m'))),
              ],
              onChanged: (v) =>
                  setState(() => _permission = v ?? _permission),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(tr(context, 'op.submit')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime t) =>
      '${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} '
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

/// 90 → 90 分钟; 5400 → 1.5 小时.
String formatMinutes(BuildContext context, int minutes) {
  if (minutes < 60) return trP(context, 'op.minutes', ['$minutes']);
  return trP(context, 'op.hours', [(minutes / 60).toStringAsFixed(1)]);
}
