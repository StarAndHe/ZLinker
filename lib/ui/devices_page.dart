import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../state/device_session.dart';
import '../state/device_store.dart';
import '../state/scheduled_store.dart';
import 'qr_scan_page.dart';
import 'remote_page.dart';
import 'scheduled_page.dart';
import 'settings_page.dart';
import 'task_list_page.dart';
import 'theme.dart';
import 'ui_settings.dart';

/// Home: the device list with live native status. Tap a card to open the
/// official web remote page (native connection suspended for the handover),
/// long-term management via the overflow menu.
class DevicesPage extends StatefulWidget {
  final DeviceStore store;
  final ThemeController theme;
  final UiSettings ui;
  final DeviceSessionHub hub;
  final ScheduledStore scheduled;
  const DevicesPage({
    super.key,
    required this.store,
    required this.theme,
    required this.ui,
    required this.hub,
    required this.scheduled,
  });

  @override
  State<DevicesPage> createState() => _DevicesPageState();
}

class _DevicesPageState extends State<DevicesPage> {
  @override
  void initState() {
    super.initState();
    widget.store.load();
    widget.store.addListener(_syncConnections);
    widget.ui.addListener(_syncConnections);
  }

  @override
  void dispose() {
    widget.store.removeListener(_syncConnections);
    widget.ui.removeListener(_syncConnections);
    super.dispose();
  }

  /// Keeps native connections in step with the device list and the
  /// native-list switch (see [DeviceSessionHub.syncWith]).
  void _syncConnections() {
    if (!widget.store.loaded || !mounted) return;
    widget.hub.syncWith(widget.store.devices);
  }

  /// Card tap: native task list when the protocol link is healthy, the
  /// WebView remote page otherwise.
  Future<void> _open(Device device) async {
    final session = widget.hub.sessionOf(device.id);
    if (widget.ui.nativeListEnabled &&
        session != null &&
        session.status != DeviceStatus.error) {
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => TaskListPage(
          store: widget.store,
          hub: widget.hub,
          device: device,
        ),
      ));
      return;
    }
    await _openRemote(device);
  }

  /// Opens the in-app WebView remote page. The native connection is
  /// suspended first (one terminal per device) and resumes ~1s after the
  /// page pops.
  Future<void> _openRemote(Device device) async {
    await widget.store.touch(device.id);
    await widget.hub.suspend(device.id);
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => RemotePage(device: device),
    ));
    widget.hub.scheduleResume(device);
  }

  Future<void> _addByUrl() async {
    final controller = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr(context, 'devices.add.pasteTitle')),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          minLines: 2,
          keyboardType: TextInputType.url,
          style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
          decoration: InputDecoration(
            hintText: tr(context, 'devices.add.pasteHint2'),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c),
              child: Text(tr(context, 'devices.add.cancel'))),
          FilledButton(
            onPressed: () => Navigator.pop(c, controller.text),
            child: Text(tr(context, 'devices.add.confirm')),
          ),
        ],
      ),
    );
    if (url == null || url.trim().isEmpty) return;
    final device = await widget.store.addUrl(url);
    if (!mounted) return;
    if (device.params == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(context, 'devices.add.savedUnparsed'))),
      );
    }
  }

  Future<void> _addByScan() async {
    final url = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QrScanPage()),
    );
    if (url == null || url.trim().isEmpty) return;
    final device = await widget.store.addUrl(url);
    if (!mounted) return;
    if (device.params == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(context, 'devices.add.savedUnparsed'))),
      );
    }
  }

  void _showAddSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.qr_code_scanner),
              title: Text(tr(context, 'devices.add.scan')),
              subtitle: Text(tr(context, 'devices.add.scanHint')),
              onTap: () {
                Navigator.pop(c);
                _addByScan();
              },
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: Text(tr(context, 'devices.add.paste')),
              subtitle: Text(tr(context, 'devices.add.pasteHint')),
              onTap: () {
                Navigator.pop(c);
                _addByUrl();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _rename(Device device) async {
    final controller = TextEditingController(text: device.label);
    final label = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr(context, 'devices.rename.title')),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: tr(context, 'devices.rename.hint')),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c),
              child: Text(tr(context, 'devices.add.cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(c, controller.text),
              child: Text(tr(context, 'devices.rename.save'))),
        ],
      ),
    );
    if (label != null) await widget.store.rename(device.id, label);
  }

  Future<void> _delete(Device device) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr(context, 'devices.delete.title')),
        content:
            Text(trP(context, 'devices.delete.body', [device.label])),
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
    if (confirm == true) await widget.store.remove(device.id);
  }

  Future<void> _copyUrl(Device device) async {
    await Clipboard.setData(ClipboardData(text: device.url));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(tr(context, 'devices.copy.done'))));
  }

  Future<void> _openInBrowser(Device device) async {
    await launchUrl(Uri.parse(device.url),
        mode: LaunchMode.externalApplication);
  }

  void _showExport() async {
    await Clipboard.setData(ClipboardData(text: widget.store.exportJson()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr(context, 'devices.export.done'))),
    );
  }

  void _showScheduled() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ScheduledPage(
        devices: widget.store,
        store: widget.scheduled,
      ),
    ));
  }

  Future<void> _showImport() async {
    final controller = TextEditingController();
    final raw = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr(context, 'devices.import.title')),
        content: TextField(
          controller: controller,
          maxLines: 5,
          minLines: 3,
          style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
          decoration: InputDecoration(hintText: tr(context, 'devices.import.hint')),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c),
              child: Text(tr(context, 'devices.add.cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(c, controller.text),
              child: Text(tr(context, 'devices.import.confirm'))),
        ],
      ),
    );
    if (raw == null || raw.trim().isEmpty) return;
    try {
      final n = await widget.store.importJson(raw);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(trP(context, 'devices.import.done', ['$n']))));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr(context, 'devices.import.invalid'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(context, 'app.title')),
        actions: [
          IconButton(
            tooltip: tr(context, 'settings.title'),
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => SettingsPage(
                store: widget.store,
                theme: widget.theme,
                ui: widget.ui,
              ),
            )),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'export') _showExport();
              if (v == 'import') _showImport();
              if (v == 'sched') _showScheduled();
            },
            itemBuilder: (c) => [
              PopupMenuItem(
                  value: 'export', child: Text(tr(context, 'devices.menu.export'))),
              PopupMenuItem(
                  value: 'import', child: Text(tr(context, 'devices.menu.import'))),
              PopupMenuItem(
                  value: 'sched', child: Text(tr(context, 'sched.menu'))),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddSheet,
        icon: const Icon(Icons.add),
        label: Text(tr(context, 'devices.add')),
      ),
      body: AnimatedBuilder(
        animation: Listenable.merge([widget.store, widget.hub, widget.ui]),
        builder: (context, _) {
          final devices = widget.store.devices;
          if (!widget.store.loaded) {
            return const Center(child: CircularProgressIndicator());
          }
          if (devices.isEmpty) return _emptyState(context);
          return RefreshIndicator(
            onRefresh: () async => _syncConnections(),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: devices.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) => _deviceCard(devices[i]),
            ),
          );
        },
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: ZColors.sky500.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.devices, size: 36, color: ZColors.sky500),
            ),
            const SizedBox(height: 20),
            Text(tr(context, 'devices.empty.title'),
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: ZInk.solid(context))),
            const SizedBox(height: 8),
            Text(
              tr(context, 'devices.empty.body'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: ZInk.faint(context)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _deviceCard(Device device) {
    final host = device.params?.source.host ?? '';
    final session = widget.hub.sessionOf(device.id);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(device),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: ListTile(
            leading: _deviceLeading(context, session),
            title: Text(
              device.label,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _statusLine(context, session),
                  if (host.isNotEmpty)
                    Text(host,
                        style: TextStyle(
                            fontSize: 11, color: ZInk.faint(context))),
                  Text(
                    device.lastUsedAt != null
                        ? trP(context, 'devices.lastUsed', [
                            relativeTime(context, device.lastUsedAt!)
                          ])
                        : tr(context, 'devices.neverUsed'),
                    style:
                        TextStyle(fontSize: 11, color: ZInk.ghost(context)),
                  ),
                ],
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.chevron_right, color: ZInk.ghost(context)),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    switch (v) {
                      case 'rename':
                        _rename(device);
                      case 'web':
                        _openRemote(device);
                      case 'browser':
                        _openInBrowser(device);
                      case 'copy':
                        _copyUrl(device);
                      case 'delete':
                        _delete(device);
                    }
                  },
                  itemBuilder: (c) => [
                    PopupMenuItem(
                        value: 'rename',
                        child: Text(tr(context, 'devices.menu.rename'))),
                    PopupMenuItem(
                        value: 'web', child: Text(tr(context, 'devices.menu.web'))),
                    PopupMenuItem(
                        value: 'browser',
                        child: Text(tr(context, 'devices.menu.browser'))),
                    PopupMenuItem(
                        value: 'copy',
                        child: Text(tr(context, 'devices.menu.copy'))),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(tr(context, 'devices.menu.delete'),
                          style: TextStyle(
                              color: Theme.of(c).colorScheme.error)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Device avatar with a live status dot and a running-task badge.
  Widget _deviceLeading(BuildContext context, DeviceSession? session) {
    final running = session?.runningTaskCount ?? 0;
    final dotColor = switch (session?.status) {
      DeviceStatus.connected => ZColors.success,
      DeviceStatus.connecting => ZColors.sky500,
      DeviceStatus.error => ZColors.danger,
      _ => ZColors.neutral400,
    };
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: ZColors.sky500.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.desktop_windows_outlined,
              size: 22, color: ZColors.sky500),
        ),
        Positioned(
          right: -1,
          bottom: -1,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
              border: Border.all(
                  color: Theme.of(context).colorScheme.surface, width: 2.5),
            ),
          ),
        ),
        if (running > 0)
          Positioned(
            right: -8,
            top: -8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: ZColors.sky500,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: Theme.of(context).colorScheme.surface, width: 2),
              ),
              child: Text(
                running > 9 ? '9+' : '$running',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _statusLine(BuildContext context, DeviceSession? session) {
    final (text, color) = switch (session?.status) {
      DeviceStatus.connected => session != null && session.runningTaskCount > 0
          ? (trP(context, 'status.tasksRunning',
                ['${session.runningTaskCount}']),
              ZColors.success)
          : (tr(context, 'status.online'), ZColors.success),
      DeviceStatus.connecting =>
        (tr(context, 'status.connecting'), ZColors.sky500),
      DeviceStatus.error => session?.kicked == true
          ? (tr(context, 'status.kicked'), ZColors.danger)
          : (tr(context, 'status.error'), ZColors.danger),
      _ => (tr(context, 'status.offline'), ZInk.ghost(context)),
    };
    return Text(text,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w500, color: color));
  }
}
