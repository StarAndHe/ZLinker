import 'package:flutter/material.dart';

import '../state/device_store.dart';
import '../state/scheduled_store.dart';
import 'theme.dart';
import 'ui_settings.dart';

/// Scheduled-message list (automation MVP). Adding needs devices; firing
/// needs the native link on and the app alive at fire time.
class ScheduledPage extends StatefulWidget {
  final DeviceStore devices;
  final ScheduledStore store;
  const ScheduledPage({
    super.key,
    required this.devices,
    required this.store,
  });

  @override
  State<ScheduledPage> createState() => _ScheduledPageState();
}

class _ScheduledPageState extends State<ScheduledPage> {
  @override
  void initState() {
    super.initState();
    widget.store.load();
  }

  Future<void> _showAddSheet() async {
    final devices = widget.devices.devices
        .where((d) => d.params != null)
        .toList();
    if (devices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(context, 'sched.noDevices'))),
      );
      return;
    }
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (c) => _AddSheet(devices: devices, store: widget.store),
    );
    if (created == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(context, 'sched.created'))),
      );
    }
  }

  String _fmtDateTime(int ms) {
    final t = DateTime.fromMillisecondsSinceEpoch(ms).toLocal();
    return '${t.year}-${t.month.toString().padLeft(2, '0')}-'
        '${t.day.toString().padLeft(2, '0')} '
        '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'sched.title'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddSheet,
        icon: const Icon(Icons.add),
        label: Text(tr(context, 'sched.add')),
      ),
      body: AnimatedBuilder(
        animation: Listenable.merge([widget.store, widget.devices]),
        builder: (context, _) {
          final items = widget.store.items;
          if (items.isEmpty) {
            return Center(
              child: Text(
                tr(context, 'sched.empty'),
                style: TextStyle(color: ZInk.muted(context)),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) => _itemCard(items[i]),
          );
        },
      ),
    );
  }

  Widget _itemCard(ScheduledMessage m) {
    final (label, color) = m.sent
        ? (tr(context, 'sched.sent'), ZColors.success)
        : m.attempts >= MessageScheduler.maxAttempts
            ? (tr(context, 'sched.failed'), ZColors.danger)
            : (tr(context, 'sched.pending'), ZColors.sky500);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.schedule, size: 14, color: color),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(m.deviceLabel,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 8),
                      Text(label,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: color)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(m.text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(fontSize: 12, color: ZInk.muted(context))),
                  const SizedBox(height: 4),
                  Text(
                    m.sent
                        ? _fmtDateTime(m.fireAt)
                        : '${_fmtDateTime(m.fireAt)} · ${relativeTime(context, m.fireAt)}',
                    style:
                        TextStyle(fontSize: 11, color: ZInk.ghost(context)),
                  ),
                  if (m.lastError != null && !m.sent)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        m.lastError!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style:
                            TextStyle(fontSize: 11, color: ZColors.danger),
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline,
                  size: 18, color: ZInk.faint(context)),
              onPressed: () => widget.store.remove(m.id),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddSheet extends StatefulWidget {
  final List<Device> devices;
  final ScheduledStore store;
  const _AddSheet({required this.devices, required this.store});

  @override
  State<_AddSheet> createState() => _AddSheetState();
}

class _AddSheetState extends State<_AddSheet> {
  late String _deviceId;
  final _textController = TextEditingController();
  DateTime _fireAt =
      DateTime.now().add(const Duration(minutes: 10));

  @override
  void initState() {
    super.initState();
    _deviceId = widget.devices.first.id;
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate:
          _fireAt.isAfter(DateTime.now()) ? _fireAt : DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(minutes: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_fireAt),
    );
    if (time == null || !mounted) return;
    setState(() {
      _fireAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _submit() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    final device =
        widget.devices.where((d) => d.id == _deviceId).first;
    await widget.store.add(
      deviceId: device.id,
      deviceLabel: device.label,
      text: text,
      fireAt: _fireAt.millisecondsSinceEpoch,
    );
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr(context, 'sched.add'),
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(tr(context, 'sched.hint'),
              style: TextStyle(fontSize: 11, color: ZInk.muted(context))),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _deviceId,
            decoration:
                InputDecoration(labelText: tr(context, 'sched.device')),
            items: [
              for (final d in widget.devices)
                DropdownMenuItem(value: d.id, child: Text(d.label)),
            ],
            onChanged: (v) => setState(() => _deviceId = v ?? _deviceId),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _textController,
            maxLines: 3,
            decoration: InputDecoration(
                labelText: tr(context, 'sched.message')),
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: _pickTime,
            borderRadius: BorderRadius.circular(8),
            child: InputDecorator(
              decoration: InputDecoration(
                  labelText: tr(context, 'sched.time'),
                  suffixIcon: const Icon(Icons.event_outlined, size: 18)),
              child: Text(
                '${_fireAt.year}-${_fireAt.month.toString().padLeft(2, '0')}-'
                '${_fireAt.day.toString().padLeft(2, '0')} '
                '${_fireAt.hour.toString().padLeft(2, '0')}:'
                '${_fireAt.minute.toString().padLeft(2, '0')}',
              ),
            ),
          ),
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
    );
  }
}
