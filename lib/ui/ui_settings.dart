import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// UI preferences: locale (zh-CN / en-US) and the native task-list switch.
class UiSettings extends ChangeNotifier {
  static const _localeKey = 'zremote_ui_locale';
  static const _nativeListKey = 'zremote_native_list';

  String locale = 'zh-CN';
  bool nativeListEnabled = true;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    locale = prefs.getString(_localeKey) ?? 'zh-CN';
    nativeListEnabled = prefs.getBool(_nativeListKey) ?? true;
    notifyListeners();
  }

  Future<void> setLocale(String value) async {
    locale = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, value);
  }

  Future<void> setNativeListEnabled(bool value) async {
    nativeListEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_nativeListKey, value);
  }
}

class UiSettingsProvider extends InheritedWidget {
  final UiSettings settings;

  const UiSettingsProvider({
    super.key,
    required this.settings,
    required super.child,
  });

  static UiSettings? of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<UiSettingsProvider>()
      ?.settings;

  @override
  bool updateShouldNotify(UiSettingsProvider oldWidget) =>
      settings != oldWidget.settings;
}

/// Lightweight i18n lookup (single-file table scheme).
String tr(BuildContext context, String key) {
  final locale = UiSettingsProvider.of(context)?.locale ?? 'zh-CN';
  final table = locale.startsWith('en') ? _en : _zh;
  return table[key] ?? _zh[key] ?? key;
}

/// [tr] with positional substitution: `$0`, `$1`, ... in the template are
/// replaced by [args] in order.
String trP(BuildContext context, String key, List<String> args) {
  var out = tr(context, key);
  for (var i = 0; i < args.length; i++) {
    out = out.replaceAll('\$$i', args[i]);
  }
  return out;
}

/// Relative-time formatting using the 'time.*' table keys.
String relativeTime(BuildContext context, int ms) {
  final diff =
      DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ms));
  if (diff.inMinutes < 1) return tr(context, 'time.justNow');
  if (diff.inHours < 1) {
    return trP(context, 'time.minutesAgo', ['${diff.inMinutes}']);
  }
  if (diff.inDays < 1) {
    return trP(context, 'time.hoursAgo', ['${diff.inHours}']);
  }
  if (diff.inDays < 30) {
    return trP(context, 'time.daysAgo', ['${diff.inDays}']);
  }
  return DateTime.fromMillisecondsSinceEpoch(ms)
      .toLocal()
      .toString()
      .substring(0, 10);
}

const _zh = {
  'app.title': 'ZRemote',
  'devices.empty.title': '还没有设备',
  'devices.empty.body': '在桌面 ZCode 中打开「远程控制」，\n扫码或粘贴链接即可添加设备',
  'devices.add': '添加设备',
  'devices.add.scan': '扫码添加',
  'devices.add.scanHint': '对准桌面端 ZCode 远程控制二维码',
  'devices.add.paste': '粘贴链接添加',
  'devices.add.pasteHint': '粘贴远程控制 URL',
  'devices.add.pasteTitle': '粘贴链接添加',
  'devices.add.pasteHint2': 'https://zcode.z.ai/remote/v4?sid=...&hash=...&t=...',
  'devices.add.cancel': '取消',
  'devices.add.confirm': '添加',
  'devices.add.savedUnparsed': 'URL 无法解析，但仍已保存',
  'devices.scan.title': '扫码添加设备',
  'devices.scan.fromGallery': '从相册选择二维码图片',
  'devices.scan.cameraError': '相机不可用: \$0\n可改用右上角从图片识别',
  'devices.scan.cameraInitFailed': '相机初始化失败',
  'devices.scan.decodeFailed': '未能从图片中识别二维码',
  'devices.scan.decodeError': '图片识别失败: \$0',
  'devices.scan.hint': '对准桌面端 ZCode 远程控制二维码，或从相册选择二维码截图',
  'devices.lastUsed': '上次使用 \$0',
  'devices.neverUsed': '从未使用',
  'devices.menu.rename': '重命名',
  'devices.menu.web': '网页版打开',
  'devices.menu.browser': '在浏览器中打开',
  'devices.menu.copy': '复制链接',
  'devices.menu.delete': '删除',
  'devices.menu.export': '导出设备备份',
  'devices.menu.import': '导入设备备份',
  'devices.rename.title': '重命名设备',
  'devices.rename.hint': '设备名称',
  'devices.rename.save': '保存',
  'devices.delete.title': '删除设备',
  'devices.delete.body': '确定要删除「\$0」吗？',
  'devices.delete.confirm': '删除',
  'devices.copy.done': '链接已复制',
  'devices.export.done': '已复制设备备份 JSON 到剪贴板',
  'devices.import.title': '导入设备',
  'devices.import.hint': '粘贴设备备份 JSON',
  'devices.import.confirm': '导入',
  'devices.import.done': '已导入 \$0 台设备',
  'devices.import.invalid': '备份格式无效',
  'devices.unnamed': '未命名设备',
  'status.online': '在线',
  'status.connecting': '连接中…',
  'status.offline': '离线',
  'status.error': '原生列表不可用，请用网页版',
  'status.kicked': '已被其他终端接管',
  'status.tasksRunning': '\$0 个任务运行中',
  'time.justNow': '刚刚',
  'time.minutesAgo': '\$0 分钟前',
  'time.hoursAgo': '\$0 小时前',
  'time.daysAgo': '\$0 天前',
  'tasks.title': '任务',
  'tasks.empty': '暂无任务',
  'tasks.loading': '正在获取任务列表…',
  'tasks.fallback.title': '原生列表不可用',
  'tasks.fallback.body': '协议连接未就绪，可先用网页版操作此设备。',
  'tasks.openWeb': '网页版打开',
  'tasks.retry': '重试',
  'tasks.stop': '停止',
  'tasks.pause': '暂停',
  'tasks.resume': '恢复',
  'tasks.opFailed': '操作失败: \$0',
  'tasks.untitled': '未命名任务',
  'tasks.workspaces': '工作区',
  'tasks.deepLinking': '正在直达任务…',
  'phase.running': '运行中',
  'phase.prewarming': '预热中',
  'phase.completedSuccess': '已完成',
  'phase.completedInterrupted': '已中断',
  'phase.error': '出错',
  'phase.draft': '草稿',
  'phase.paused': '已暂停',
  'remote.error.title': '无法连接到桌面设备',
  'remote.error.hint': '请确认桌面 ZCode 已打开且网络可用',
  'remote.reload': '重新加载',
  'settings.title': '设置',
  'settings.appearance': '外观',
  'settings.theme': '主题',
  'settings.theme.dark': '深色',
  'settings.theme.light': '浅色',
  'settings.theme.system': '跟随系统',
  'settings.general': '通用',
  'settings.language': '语言',
  'settings.language.zh': '中文',
  'settings.language.en': 'English',
  'settings.nativeList': '原生任务列表',
  'settings.nativeListHint': '原生显示设备在线状态与任务列表；关闭后仅用网页版',
  'settings.data': '数据',
  'settings.usageStats': '使用统计',
  'settings.usageStatsHint': '仅保存在本机',
  'settings.about': '关于 ZRemote',
  'about.version': '版本',
  'about.github': 'GitHub 仓库',
  'about.licenses': '开源许可',
  'about.privacy': '隐私政策',
  'about.disclaimer': 'ZRemote 是非官方的社区客户端，与 Zhipu AI 及 ZCode 无关联。',
  'usage.title': '使用统计',
  'usage.summary.devices': '设备数',
  'usage.summary.opens': '累计打开',
  'usage.perDevice': '按设备',
  'usage.opens': '\$0 次',
  'usage.addedAt': '添加于 \$0',
  'usage.neverUsed': '从未使用',
  'tasks.menu.usage': '用量',
  'tasks.menu.providers': '模型供应商',
  'usageRpc.title': '用量',
  'usageRpc.loadFailed': '加载失败: \$0',
  'usageRpc.remaining': '剩余额度',
  'usageRpc.remainingDetail': '剩余 \$0% · 重置时间 \$1',
  'usageRpc.limits': '配额限制',
  'usageRpc.subscription': '订阅',
  'usageRpc.product': '产品',
  'usageRpc.billing': '计费周期',
  'usageRpc.renew': '续费时间',
  'usageRpc.expire': '到期时间',
  'usageRpc.used': '用量 \$0',
  'usageRpc.left': '剩余 \$0',
  'usageRpc.resetAt': '重置 \$0',
  'providers.title': '模型供应商',
  'providers.add': '添加',
  'providers.addTitle': '添加模型供应商',
  'providers.name': '名称',
  'providers.apiFormat': 'API 格式',
  'providers.apiKey': 'API Key（可选）',
  'providers.models': '模型 ID（逗号分隔）',
  'providers.modelsCount': '\$0 个模型',
  'providers.disabled': '停用: \$0',
  'providers.loadFailed': '加载失败: \$0',
  'providers.toggleFailed': '切换失败: \$0',
  'providers.deleteFailed': '删除失败: \$0',
  'providers.addFailed': '添加失败: \$0',
  'providers.added': '已添加供应商',
  'providers.deleteTitle': '删除模型供应商？',
  'providers.deleteBody': '将删除「\$0」',
  'sched.menu': '定时消息',
  'sched.title': '定时消息',
  'sched.add': '新建定时消息',
  'sched.empty': '暂无定时消息',
  'sched.noDevices': '请先添加可用设备',
  'sched.created': '已创建定时消息',
  'sched.device': '设备',
  'sched.message': '消息内容',
  'sched.time': '发送时间',
  'sched.pending': '待发送',
  'sched.sent': '已发送',
  'sched.failed': '失败',
  'sched.hint': '到点时需保持 App 在前台，且开启「原生任务列表」',
  'settings.checkUpdate': '检查更新',
  'update.latest': '已是最新版本',
  'update.newVersion': '发现新版本 v\$0',
  'update.availableBody': '有新的 ZRemote 版本可用。',
  'update.download': '到浏览器下载',
  'update.later': '稍后',
  'update.failed': '检查更新失败: \$0',
  'update.storePending': '请通过 App Store 检查更新',
};

const _en = {
  'app.title': 'ZRemote',
  'devices.empty.title': 'No devices yet',
  'devices.empty.body':
      'Open "Remote Control" in ZCode desktop,\nthen scan or paste the link',
  'devices.add': 'Add device',
  'devices.add.scan': 'Scan QR code',
  'devices.add.scanHint': 'Aim at the ZCode remote-control QR code',
  'devices.add.paste': 'Paste link',
  'devices.add.pasteHint': 'Paste the remote-control URL',
  'devices.add.pasteTitle': 'Paste link',
  'devices.add.pasteHint2': 'https://zcode.z.ai/remote/v4?sid=...&hash=...&t=...',
  'devices.add.cancel': 'Cancel',
  'devices.add.confirm': 'Add',
  'devices.add.savedUnparsed': 'URL could not be parsed but was saved',
  'devices.scan.title': 'Scan to add device',
  'devices.scan.fromGallery': 'Pick a QR image from gallery',
  'devices.scan.cameraError':
      'Camera unavailable: \$0\nUse "pick from gallery" in the top-right instead',
  'devices.scan.cameraInitFailed': 'Camera failed to start',
  'devices.scan.decodeFailed': 'No QR code found in that image',
  'devices.scan.decodeError': 'Image decode failed: \$0',
  'devices.scan.hint':
      'Aim at the ZCode remote-control QR code, or pick a screenshot',
  'devices.lastUsed': 'Last used \$0',
  'devices.neverUsed': 'Never used',
  'devices.menu.rename': 'Rename',
  'devices.menu.web': 'Open web version',
  'devices.menu.browser': 'Open in browser',
  'devices.menu.copy': 'Copy link',
  'devices.menu.delete': 'Delete',
  'devices.menu.export': 'Export device backup',
  'devices.menu.import': 'Import device backup',
  'devices.rename.title': 'Rename device',
  'devices.rename.hint': 'Device name',
  'devices.rename.save': 'Save',
  'devices.delete.title': 'Delete device',
  'devices.delete.body': 'Delete "\$0"?',
  'devices.delete.confirm': 'Delete',
  'devices.copy.done': 'Link copied',
  'devices.export.done': 'Device backup JSON copied to clipboard',
  'devices.import.title': 'Import devices',
  'devices.import.hint': 'Paste device backup JSON',
  'devices.import.confirm': 'Import',
  'devices.import.done': 'Imported \$0 device(s)',
  'devices.import.invalid': 'Invalid backup format',
  'devices.unnamed': 'Unnamed device',
  'status.online': 'Online',
  'status.connecting': 'Connecting…',
  'status.offline': 'Offline',
  'status.error': 'Native list unavailable — use the web version',
  'status.kicked': 'Taken over by another terminal',
  'status.tasksRunning': '\$0 task(s) running',
  'time.justNow': 'just now',
  'time.minutesAgo': '\$0 min ago',
  'time.hoursAgo': '\$0 h ago',
  'time.daysAgo': '\$0 d ago',
  'tasks.title': 'Tasks',
  'tasks.empty': 'No tasks yet',
  'tasks.loading': 'Loading tasks…',
  'tasks.fallback.title': 'Native list unavailable',
  'tasks.fallback.body':
      'The protocol link is not ready — use the web version for now.',
  'tasks.openWeb': 'Open web version',
  'tasks.retry': 'Retry',
  'tasks.stop': 'Stop',
  'tasks.pause': 'Pause',
  'tasks.resume': 'Resume',
  'tasks.opFailed': 'Operation failed: \$0',
  'tasks.untitled': 'Untitled task',
  'tasks.workspaces': 'Workspace',
  'tasks.deepLinking': 'Jumping to the task…',
  'phase.running': 'Running',
  'phase.prewarming': 'Prewarming',
  'phase.completedSuccess': 'Completed',
  'phase.completedInterrupted': 'Interrupted',
  'phase.error': 'Error',
  'phase.draft': 'Draft',
  'phase.paused': 'Paused',
  'remote.error.title': 'Cannot reach the desktop device',
  'remote.error.hint': 'Make sure ZCode desktop is running and the network works',
  'remote.reload': 'Reload',
  'settings.title': 'Settings',
  'settings.appearance': 'Appearance',
  'settings.theme': 'Theme',
  'settings.theme.dark': 'Dark',
  'settings.theme.light': 'Light',
  'settings.theme.system': 'System',
  'settings.general': 'General',
  'settings.language': 'Language',
  'settings.language.zh': '中文',
  'settings.language.en': 'English',
  'settings.nativeList': 'Native task list',
  'settings.nativeListHint':
      'Native device status and task list; turn off to use the web version only',
  'settings.data': 'Data',
  'settings.usageStats': 'Usage statistics',
  'settings.usageStatsHint': 'Stored on this device only',
  'settings.about': 'About ZRemote',
  'about.version': 'Version',
  'about.github': 'GitHub repository',
  'about.licenses': 'Open-source licenses',
  'about.privacy': 'Privacy policy',
  'about.disclaimer':
      'ZRemote is an unofficial community client, not affiliated with Zhipu AI or ZCode.',
  'usage.title': 'Usage statistics',
  'usage.summary.devices': 'Devices',
  'usage.summary.opens': 'Total opens',
  'usage.perDevice': 'Per device',
  'usage.opens': '\$0 opens',
  'usage.addedAt': 'Added \$0',
  'usage.neverUsed': 'Never used',
  'tasks.menu.usage': 'Usage',
  'tasks.menu.providers': 'Model providers',
  'usageRpc.title': 'Usage',
  'usageRpc.loadFailed': 'Load failed: \$0',
  'usageRpc.remaining': 'Remaining quota',
  'usageRpc.remainingDetail': '\$0% left · resets \$1',
  'usageRpc.limits': 'Quota limits',
  'usageRpc.subscription': 'Subscription',
  'usageRpc.product': 'Product',
  'usageRpc.billing': 'Billing cycle',
  'usageRpc.renew': 'Renews',
  'usageRpc.expire': 'Expires',
  'usageRpc.used': 'Used \$0',
  'usageRpc.left': '\$0 left',
  'usageRpc.resetAt': 'Resets \$0',
  'providers.title': 'Model providers',
  'providers.add': 'Add',
  'providers.addTitle': 'Add model provider',
  'providers.name': 'Name',
  'providers.apiFormat': 'API format',
  'providers.apiKey': 'API Key (optional)',
  'providers.models': 'Model IDs (comma-separated)',
  'providers.modelsCount': '\$0 models',
  'providers.disabled': 'Disabled: \$0',
  'providers.loadFailed': 'Load failed: \$0',
  'providers.toggleFailed': 'Toggle failed: \$0',
  'providers.deleteFailed': 'Delete failed: \$0',
  'providers.addFailed': 'Add failed: \$0',
  'providers.added': 'Provider added',
  'providers.deleteTitle': 'Delete model provider?',
  'providers.deleteBody': 'This deletes "\$0".',
  'sched.menu': 'Scheduled messages',
  'sched.title': 'Scheduled messages',
  'sched.add': 'New message',
  'sched.empty': 'No scheduled messages',
  'sched.noDevices': 'Add a device first',
  'sched.created': 'Scheduled message created',
  'sched.device': 'Device',
  'sched.message': 'Message',
  'sched.time': 'Send at',
  'sched.pending': 'Pending',
  'sched.sent': 'Sent',
  'sched.failed': 'Failed',
  'sched.hint':
      'Keep the app in the foreground at fire time, with the native task list enabled',
  'settings.checkUpdate': 'Check for updates',
  'update.latest': 'Up to date',
  'update.newVersion': 'New version v\$0',
  'update.availableBody': 'A new ZRemote version is available.',
  'update.download': 'Download in browser',
  'update.later': 'Later',
  'update.failed': 'Update check failed: \$0',
  'update.storePending': 'Check for updates in the App Store',
};
