import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../state/device_store.dart';
import 'qr_scan_page.dart';
import 'remote_page.dart';
import 'theme.dart';

/// Home: the device list. Add by scan or paste, tap a card to open the
/// official web remote page, long-term management via the overflow menu.
class DevicesPage extends StatefulWidget {
  final DeviceStore store;
  final ThemeController theme;
  const DevicesPage({super.key, required this.store, required this.theme});

  @override
  State<DevicesPage> createState() => _DevicesPageState();
}

class _DevicesPageState extends State<DevicesPage> {
  @override
  void initState() {
    super.initState();
    widget.store.load();
  }

  Future<void> _open(Device device) async {
    await widget.store.touch(device.id);
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => RemotePage(device: device),
    ));
  }

  Future<void> _addByUrl() async {
    final controller = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('粘贴链接添加'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          minLines: 2,
          keyboardType: TextInputType.url,
          style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
          decoration: const InputDecoration(
            hintText:
                'https://zcode.z.ai/remote/v4?sid=...&hash=...&t=...',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(c, controller.text),
            child: const Text('添加'),
          ),
        ],
      ),
    );
    if (url == null || url.trim().isEmpty) return;
    final device = await widget.store.addUrl(url);
    if (!mounted) return;
    if (device.params == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('URL 无法解析，但仍已保存')),
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
        const SnackBar(content: Text('URL 无法解析，但仍已保存')),
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
              title: const Text('扫码添加'),
              subtitle: const Text('对准桌面端 ZCode 远程控制二维码'),
              onTap: () {
                Navigator.pop(c);
                _addByScan();
              },
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('粘贴链接添加'),
              subtitle: const Text('粘贴远程控制 URL'),
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
        title: const Text('重命名设备'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '设备名称'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(c, controller.text),
              child: const Text('保存')),
        ],
      ),
    );
    if (label != null) await widget.store.rename(device.id, label);
  }

  Future<void> _delete(Device device) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('删除设备'),
        content: Text('确定要删除「${device.label}」吗？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(c).colorScheme.error,
                foregroundColor: Theme.of(c).colorScheme.onError),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('删除'),
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
        .showSnackBar(const SnackBar(content: Text('链接已复制')));
  }

  Future<void> _openInBrowser(Device device) async {
    await launchUrl(Uri.parse(device.url),
        mode: LaunchMode.externalApplication);
  }

  void _showExport() async {
    await Clipboard.setData(ClipboardData(text: widget.store.exportJson()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已复制设备备份 JSON 到剪贴板')),
    );
  }

  Future<void> _showImport() async {
    final controller = TextEditingController();
    final raw = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('导入设备'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          minLines: 3,
          style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
          decoration: const InputDecoration(hintText: '粘贴设备备份 JSON'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(c, controller.text),
              child: const Text('导入')),
        ],
      ),
    );
    if (raw == null || raw.trim().isEmpty) return;
    try {
      final n = await widget.store.importJson(raw);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('已导入 $n 台设备')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('备份格式无效')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('ZRemote'),
        actions: [
          IconButton(
            tooltip: '切换主题',
            icon: Icon(switch (theme.mode) {
              ThemeMode.dark => Icons.dark_mode_outlined,
              ThemeMode.light => Icons.light_mode_outlined,
              ThemeMode.system => Icons.brightness_auto_outlined,
            }),
            onPressed: theme.cycle,
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'export') _showExport();
              if (v == 'import') _showImport();
            },
            itemBuilder: (c) => const [
              PopupMenuItem(value: 'export', child: Text('导出设备备份')),
              PopupMenuItem(value: 'import', child: Text('导入设备备份')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddSheet,
        icon: const Icon(Icons.add),
        label: const Text('添加设备'),
      ),
      body: AnimatedBuilder(
        animation: widget.store,
        builder: (context, _) {
          final devices = widget.store.devices;
          if (!widget.store.loaded) {
            return const Center(child: CircularProgressIndicator());
          }
          if (devices.isEmpty) return _emptyState(context);
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: devices.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) => _deviceCard(devices[i]),
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
            Text('还没有设备',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: ZInk.solid(context))),
            const SizedBox(height: 8),
            Text(
              '在桌面 ZCode 中打开「远程控制」，\n扫码或粘贴链接即可添加设备',
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
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(device),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: ListTile(
            leading: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: ZColors.sky500.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.desktop_windows_outlined,
                  size: 22, color: ZColors.sky500),
            ),
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
                  if (host.isNotEmpty)
                    Text(host,
                        style: TextStyle(
                            fontSize: 11, color: ZInk.faint(context))),
                  Text(
                    device.lastUsedAt != null
                        ? '上次使用 ${_relativeTime(device.lastUsedAt!)}'
                        : '从未使用',
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
                      case 'browser':
                        _openInBrowser(device);
                      case 'copy':
                        _copyUrl(device);
                      case 'delete':
                        _delete(device);
                    }
                  },
                  itemBuilder: (c) => [
                    const PopupMenuItem(value: 'rename', child: Text('重命名')),
                    const PopupMenuItem(
                        value: 'browser', child: Text('在浏览器中打开')),
                    const PopupMenuItem(value: 'copy', child: Text('复制链接')),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('删除',
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

  String _relativeTime(int ms) {
    final diff = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(ms));
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes} 分钟前';
    if (diff.inDays < 1) return '${diff.inHours} 小时前';
    if (diff.inDays < 30) return '${diff.inDays} 天前';
    return DateTime.fromMillisecondsSinceEpoch(ms)
        .toLocal()
        .toString()
        .substring(0, 10);
  }
}
