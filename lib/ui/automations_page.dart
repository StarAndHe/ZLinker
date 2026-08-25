import 'package:flutter/material.dart';

import '../protocol/automation.dart';
import '../protocol/conversation.dart';
import '../state/device_session.dart';
import '../state/device_store.dart';
import 'model_option_field.dart';
import 'theme.dart';
import 'ui_settings.dart';

/// Server-side automations of one device (desktop zcode-cron-scheduler).
/// Standalone page with a device picker; the pane itself is embedded by
/// the scheduled page so both entries share the exact list UI.
class AutomationsPage extends StatefulWidget {
  final DeviceStore store;
  final DeviceSessionHub hub;
  final String? initialDeviceId;
  const AutomationsPage({
    super.key,
    required this.store,
    required this.hub,
    this.initialDeviceId,
  });

  @override
  State<AutomationsPage> createState() => _AutomationsPageState();
}

class _AutomationsPageState extends State<AutomationsPage> {
  late String? _deviceId;

  @override
  void initState() {
    super.initState();
    widget.store.load();
    _deviceId = widget.initialDeviceId;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final devices =
            widget.store.devices.where((d) => d.params != null).toList();
        if (_deviceId == null ||
            !devices.any((d) => d.id == _deviceId)) {
          _deviceId = devices.isEmpty ? null : devices.first.id;
        }
        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(tr(context, 'auto.title'),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                Text(tr(context, 'auto.subtitle'),
                    style:
                        TextStyle(fontSize: 11, color: ZInk.faint(context))),
              ],
            ),
          ),
          body: devices.isEmpty
              ? Center(
                  child: Text(tr(context, 'sched.noDevices'),
                      style: TextStyle(color: ZInk.muted(context))))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: _devicePicker(devices),
                    ),
                    Expanded(
                      child: AutomationsPane(
                        key: ValueKey('auto-$_deviceId'),
                        session: _deviceId == null
                            ? null
                            : widget.hub.sessionOf(_deviceId!),
                        onRetry: () => widget.hub.syncWith(widget.store.devices),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _devicePicker(List<Device> devices) {
    return DropdownButtonFormField<String>(
      initialValue: _deviceId,
      decoration: InputDecoration(
        labelText: tr(context, 'sched.device'),
        suffixIcon: const Icon(Icons.desktop_windows_outlined, size: 18),
      ),
      items: [
        for (final d in devices)
          DropdownMenuItem(value: d.id, child: Text(d.label)),
      ],
      onChanged: (v) => setState(() => _deviceId = v ?? _deviceId),
    );
  }
}

/// Automations list of one device session: load / unavailable / list, plus
/// create/edit (bottom sheet), enable toggle and delete-with-confirm.
///
/// [compact] embeds without its own scroll view (the host page scrolls);
/// otherwise the list is a RefreshIndicator + ListView.
class AutomationsPane extends StatefulWidget {
  final AutomationHost? session;

  /// Retry hook when the device has no live session (re-sync connections).
  final void Function()? onRetry;
  final bool compact;

  const AutomationsPane({
    super.key,
    required this.session,
    this.onRetry,
    this.compact = false,
  });

  @override
  State<AutomationsPane> createState() => _AutomationsPaneState();
}

class _AutomationsPaneState extends State<AutomationsPane> {
  List<AutomationItem> _items = const [];
  bool _loading = true;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final session = widget.session;
    if (session == null) {
      setState(() {
        _loading = false;
        _error = null;
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await session.automation.list();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  void _toast(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _runOp(Future<void> Function() op) async {
    if (_busy) return;
    _busy = true;
    try {
      await op();
    } catch (e) {
      if (mounted) {
        _toast(trP(context, 'auto.opFailed', ['$e']));
      }
    } finally {
      _busy = false;
    }
  }

  Future<void> _showSheet({AutomationItem? edit}) async {
    final session = widget.session;
    final input = await showModalBottomSheet<AutomationInput>(
      context: context,
      isScrollControlled: true,
      builder: (c) => AutomationSheet(
        initial: edit?.toInput(),
        loadOptions:
            session is DeviceSession ? session.prepareWorkspace : null,
      ),
    );
    if (input == null) return;
    if (session == null) return;
    await _runOp(() async {
      if (edit == null) {
        await session.automation.create(input);
        if (mounted) _toast(tr(context, 'auto.created'));
      } else {
        await session.automation.update(edit.id, input);
        if (mounted) _toast(tr(context, 'auto.saved'));
      }
      await _load();
    });
  }

  Future<void> _toggle(AutomationItem item, bool enabled) async {
    final session = widget.session;
    if (session == null) return;
    await _runOp(() async {
      await session.automation.setEnabled(item.id, enabled);
      await _load();
    });
  }

  Future<void> _delete(AutomationItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr(context, 'auto.delete.title')),
        content: Text(trP(
            context, 'auto.delete.body',
            [item.title.isEmpty ? item.id : item.title])),
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
    if (confirmed != true) return;
    final session = widget.session;
    if (session == null) return;
    await _runOp(() async {
      await session.automation.remove(item.id);
      if (mounted) _toast(tr(context, 'auto.deleted'));
      await _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    if (session == null ||
        session.status == DeviceStatus.error ||
        session.status == DeviceStatus.disconnected) {
      return _unavailable(context);
    }
    if (_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(tr(context, 'auto.loading'),
                style:
                    TextStyle(fontSize: 13, color: ZInk.faint(context))),
          ],
        ),
      );
    }
    if (_error != null) {
      return _errorView(context);
    }
    if (_items.isEmpty) {
      final empty = Padding(
        padding: EdgeInsets.symmetric(
            vertical: 24, horizontal: widget.compact ? 0 : 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(tr(context, 'auto.empty'),
                style: TextStyle(
                    fontSize: 14, color: ZInk.muted(context))),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: () => _showSheet(),
              icon: const Icon(Icons.add, size: 18),
              label: Text(tr(context, 'auto.add')),
            ),
          ],
        ),
      );
      if (widget.compact) return empty;
      return Center(child: SingleChildScrollView(child: empty));
    }
    final cards = [
      for (final item in _items) ...[
        _itemCard(item),
        const SizedBox(height: 8),
      ],
      _addAction(context),
    ];
    if (widget.compact) return Column(children: cards);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
        itemCount: cards.length,
        separatorBuilder: (_, _) => const SizedBox.shrink(),
        itemBuilder: (context, i) => cards[i],
      ),
    );
  }

  Widget _addAction(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => _showSheet(),
          icon: const Icon(Icons.add, size: 18),
          label: Text(tr(context, 'auto.add')),
        ),
      );

  /// Mirrors the task-list fallback view: reason + retry + guidance to the
  /// local scheduled-send fallback.
  Widget _unavailable(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 44, color: ZInk.ghost(context)),
            const SizedBox(height: 16),
            Text(
              tr(context, 'auto.unavailable.title'),
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: ZInk.solid(context)),
            ),
            const SizedBox(height: 8),
            Text(
              tr(context, 'auto.unavailable.body'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: ZInk.faint(context)),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: widget.onRetry ?? _load,
              child: Text(tr(context, 'tasks.retry')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorView(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              trP(context, 'auto.loadFailed', [_error!]),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: ZInk.faint(context)),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _load,
              child: Text(tr(context, 'tasks.retry')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemCard(AutomationItem item) {
    final dotColor = item.enabled ? ZColors.success : ZColors.neutral400;
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
                    BoxDecoration(color: dotColor, shape: BoxShape.circle),
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
                          item.title.isEmpty ? item.id : item.title,
                          style: const TextStyle(
                              fontSize: 14.5, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        item.enabled
                            ? tr(context, 'auto.enabled')
                            : tr(context, 'auto.disabled'),
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: item.enabled
                                ? ZColors.success
                                : ZInk.muted(context)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    describeTrigger(context, item),
                    style:
                        TextStyle(fontSize: 12, color: ZInk.muted(context)),
                  ),
                  if (item.prompt.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        item.prompt,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12, color: ZInk.muted(context)),
                      ),
                    ),
                  if (item.lastRunAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      trP(context, 'auto.lastRun',
                          [relativeTime(context, item.lastRunAt!)]),
                      style: TextStyle(
                          fontSize: 11, color: ZInk.ghost(context)),
                    ),
                  ],
                ],
              ),
            ),
            Switch(
              value: item.enabled,
              onChanged: (v) => _toggle(item, v),
            ),
            PopupMenuButton<String>(
              onSelected: (v) {
                switch (v) {
                  case 'edit':
                    _showSheet(edit: item);
                  case 'delete':
                    _delete(item);
                }
              },
              itemBuilder: (c) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      const Icon(Icons.edit_outlined, size: 18),
                      const SizedBox(width: 8),
                      Text(tr(context, 'auto.edit')),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      const Icon(Icons.delete_outline, size: 18),
                      const SizedBox(width: 8),
                      Text(tr(context, 'devices.menu.delete'),
                          style:
                              TextStyle(color: Theme.of(c).colorScheme.error)),
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
}

/// Create/edit form (bottom sheet, official mobile form shape). Field order
/// follows the official web form: title → prompt → model → trigger rule.
class AutomationSheet extends StatefulWidget {
  final AutomationInput? initial;

  /// prepareWorkspace loader (the full device session): drives the model /
  /// thought-level selectors — desktop parity, pick instead of type.
  final Future<WorkspacePrep> Function()? loadOptions;
  const AutomationSheet({super.key, this.initial, this.loadOptions});

  @override
  State<AutomationSheet> createState() => AutomationSheetState();
}

class AutomationSheetState extends State<AutomationSheet> {
  late final TextEditingController _title;
  late final TextEditingController _prompt;
  late final TextEditingController _cron;
  late final TextEditingController _interval;
  late final TextEditingController _maxRuns;
  late final TextEditingController _delay;
  late final TextEditingController _targetTask;

  /// Selected model option (`provider/model` composite) split for the wire
  /// (automation carries model + provider separately); null = 默认.
  String? _modelValue;
  String? _thought;
  late String _trigger;
  late String _intervalUnit;
  late bool _recurring;
  String? _mode;
  bool _advanced = false;

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    _title = TextEditingController(text: init?.title ?? '');
    _prompt = TextEditingController(text: init?.prompt ?? '');
    _cron = TextEditingController(text: init?.cronExpr ?? '0 9 * * *');
    _interval = TextEditingController(text: '${init?.interval ?? 1}');
    _maxRuns = TextEditingController(text: '${init?.maxRuns ?? 10}');
    _delay = TextEditingController(
        text: '${init?.relativeDelayMinutes ?? 60}');
    _trigger = init?.trigger ?? AutomationInput.triggerCron;
    _intervalUnit = init?.intervalUnit ?? 'day';
    _recurring = init?.recurring ?? true;
    _mode = init?.mode;
    _modelValue = (init?.provider ?? '').isNotEmpty && (init?.model ?? '').isNotEmpty
        ? '${init!.provider}/${init.model}'
        : init?.model;
    _thought = init?.thoughtLevel;
    _targetTask = TextEditingController(text: init?.targetTaskId ?? '');
    _advanced =
        (_modelValue ?? '').isNotEmpty || (_thought ?? '').isNotEmpty;
  }

  @override
  void dispose() {
    _title.dispose();
    _prompt.dispose();
    _cron.dispose();
    _interval.dispose();
    _maxRuns.dispose();
    _delay.dispose();
    _targetTask.dispose();
    super.dispose();
  }

  void _submit() {
    // Split the composite option value back into the wire's provider+model.
    String? provider;
    String? model;
    final mv = _modelValue;
    if (mv != null && mv.isNotEmpty) {
      final idx = mv.lastIndexOf('/');
      if (idx > 0) {
        provider = mv.substring(0, idx);
        model = mv.substring(idx + 1);
      } else {
        model = mv;
      }
    }
    final input = AutomationInput(
      title: _title.text,
      prompt: _prompt.text,
      trigger: _trigger,
      cronExpr: _cron.text,
      interval: int.tryParse(_interval.text.trim()),
      intervalUnit: _intervalUnit,
      recurring: _recurring,
      maxRuns: int.tryParse(_maxRuns.text.trim()),
      relativeDelayMinutes: int.tryParse(_delay.text.trim()),
      model: model,
      provider: provider,
      mode: _mode,
      thoughtLevel:
          _thought == null || _thought!.isEmpty ? null : _thought,
      targetTaskId: _targetTask.text.trim().isEmpty
          ? null
          : _targetTask.text.trim(),
    );
    final error = input.validate();
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(context, error))),
      );
      return;
    }
    Navigator.pop(context, input);
  }

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
            Text(
              tr(context,
                  widget.initial == null ? 'auto.add' : 'auto.edit'),
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              tr(context, 'auto.hint'),
              style: TextStyle(fontSize: 11, color: ZInk.muted(context)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              decoration: InputDecoration(labelText: tr(context, 'auto.name')),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _prompt,
              maxLines: 3,
              decoration:
                  InputDecoration(labelText: tr(context, 'auto.prompt')),
            ),
            const SizedBox(height: 10),
            ModelOptionField(
              loadOptions: widget.loadOptions,
              optionId: 'model',
              labelText: tr(context, 'auto.model'),
              noneLabel: tr(context, 'auto.model.default'),
              value: _modelValue,
              onChanged: (v) => setState(() => _modelValue = v),
            ),
            const SizedBox(height: 16),
            Text(tr(context, 'auto.trigger'),
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: ZInk.muted(context))),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: AutomationInput.triggerCron,
                  label: Text(tr(context, 'auto.trigger.cron')),
                ),
                ButtonSegment(
                  value: AutomationInput.triggerInterval,
                  label: Text(tr(context, 'auto.trigger.interval')),
                ),
                ButtonSegment(
                  value: AutomationInput.triggerOneShot,
                  label: Text(tr(context, 'auto.trigger.oneShot')),
                ),
              ],
              selected: {_trigger},
              onSelectionChanged: (s) => setState(() => _trigger = s.first),
              showSelectedIcon: false,
            ),
            const SizedBox(height: 10),
            if (_trigger == AutomationInput.triggerCron) ...[
              TextField(
                controller: _cron,
                style:
                    const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                decoration: InputDecoration(
                  labelText: tr(context, 'auto.cronExpr'),
                  helperText: tr(context, 'auto.cronHint'),
                ),
              ),
            ],
            if (_trigger == AutomationInput.triggerInterval) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _interval,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                          labelText: tr(context, 'auto.interval')),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<String>(
                      initialValue: _intervalUnit,
                      decoration: InputDecoration(
                          labelText: tr(context, 'auto.intervalUnit.label')),
                      items: [
                        for (final u in AutomationInput.intervalUnits)
                          DropdownMenuItem(
                            value: u,
                            child: Text(tr(context, 'auto.intervalUnit.$u')),
                          ),
                      ],
                      onChanged: (v) =>
                          setState(() => _intervalUnit = v ?? _intervalUnit),
                    ),
                  ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(tr(context, 'auto.recurring'),
                    style: const TextStyle(fontSize: 13)),
                value: _recurring,
                onChanged: (v) => setState(() => _recurring = v),
              ),
              if (!_recurring)
                TextField(
                  controller: _maxRuns,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                      labelText: tr(context, 'auto.maxRuns')),
                ),
            ],
            if (_trigger == AutomationInput.triggerOneShot)
              TextField(
                controller: _delay,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: tr(context, 'auto.delayMinutes'),
                  helperText: tr(context, 'auto.delayHint'),
                ),
              ),
            const SizedBox(height: 6),
            _advancedSection(context),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submit,
                child: Text(tr(context, 'devices.rename.save')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _advancedSection(BuildContext context) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      dense: true,
      title: Text(tr(context, 'auto.advanced'),
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: ZInk.muted(context))),
      initiallyExpanded: _advanced,
      children: [
        DropdownButtonFormField<String?>(
          initialValue: _mode,
          decoration: InputDecoration(labelText: tr(context, 'auto.mode')),
          items: [
            DropdownMenuItem(
              value: null,
              child: Text(tr(context, 'auto.mode.default')),
            ),
            for (final m in const ['build', 'plan', 'yolo'])
              DropdownMenuItem(value: m, child: Text(m)),
          ],
          onChanged: (v) => setState(() => _mode = v),
        ),
        const SizedBox(height: 10),
        ModelOptionField(
          loadOptions: widget.loadOptions,
          optionId: 'thought_level',
          labelText: tr(context, 'auto.thoughtLevel'),
          noneLabel: tr(context, 'auto.thoughtLevel.default'),
          value: _thought,
          onChanged: (v) => setState(() => _thought = v),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _targetTask,
          style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
          decoration: InputDecoration(
              labelText: tr(context, 'auto.targetTask')),
        ),
      ],
    );
  }
}

/// Humanized trigger summary (official terms): cron 表达式 / 每 N 单位 /
/// 一次性延迟.
String describeTrigger(BuildContext context, AutomationItem item) {
  switch (item.trigger) {
    case AutomationInput.triggerCron:
      return trP(context, 'auto.cronAt', [item.cronExpr]);
    case AutomationInput.triggerInterval:
      final unit =
          tr(context, 'auto.intervalUnit.${item.intervalUnit ?? 'day'}');
      var text =
          trP(context, 'auto.every', ['${item.interval ?? 0}', unit]);
      if (!item.recurring) {
        text += ' · ${trP(context, 'auto.maxRunsN', ['${item.maxRuns ?? '?'}'])}';
      }
      return text;
    default:
      return trP(context, 'auto.once',
          [formatDelay(context, item.relativeDelayMinutes ?? 0)]);
  }
}

/// 90 → 90 分钟; 1440 → 24 小时 → also days for big values.
String formatDelay(BuildContext context, int minutes) {
  if (minutes < 60) return trP(context, 'auto.minutes', ['$minutes']);
  if (minutes < 60 * 24) {
    return trP(
        context, 'auto.hours', [(minutes / 60).toStringAsFixed(0)]);
  }
  return trP(
      context, 'auto.days', [(minutes / 60 / 24).toStringAsFixed(0)]);
}
