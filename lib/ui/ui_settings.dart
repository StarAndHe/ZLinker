import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// UI preferences: locale (zh-CN / en-US), the native task-list switch and
/// the notification switches (master + per channel).
class UiSettings extends ChangeNotifier {
  static const _localeKey = 'zremote_ui_locale';
  static const _nativeListKey = 'zremote_native_list';
  static const _notifyKey = 'zremote_notify';
  static const _notifyTasksKey = 'zremote_notify_tasks';
  static const _notifyOffPeakKey = 'zremote_notify_offpeak';
  static const _notifyAutoKey = 'zremote_notify_auto';

  String locale = 'zh-CN';
  bool nativeListEnabled = true;
  bool notificationsEnabled = true;
  bool notifyTasksEnabled = true;
  bool notifyOffPeakEnabled = true;
  bool notifyAutoEnabled = true;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    locale = prefs.getString(_localeKey) ?? 'zh-CN';
    nativeListEnabled = prefs.getBool(_nativeListKey) ?? true;
    notificationsEnabled = prefs.getBool(_notifyKey) ?? true;
    notifyTasksEnabled = prefs.getBool(_notifyTasksKey) ?? true;
    notifyOffPeakEnabled = prefs.getBool(_notifyOffPeakKey) ?? true;
    notifyAutoEnabled = prefs.getBool(_notifyAutoKey) ?? true;
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

  Future<void> setNotificationsEnabled(bool value) async {
    notificationsEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notifyKey, value);
  }

  Future<void> setNotifyTasksEnabled(bool value) async {
    notifyTasksEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notifyTasksKey, value);
  }

  Future<void> setNotifyOffPeakEnabled(bool value) async {
    notifyOffPeakEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notifyOffPeakKey, value);
  }

  Future<void> setNotifyAutoEnabled(bool value) async {
    notifyAutoEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notifyAutoKey, value);
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
String tr(BuildContext context, String key) =>
    trLocale(UiSettingsProvider.of(context)?.locale ?? 'zh-CN', key);

/// Context-free lookup for surfaces without a BuildContext (push
/// notifications render outside the widget tree).
String trLocale(String locale, String key) {
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
  'tasks.pickWorkspace': '选择工作区',
  'tasks.noWorkspaces.title': '桌面端没有打开的工作区',
  'tasks.noWorkspaces.body': '请先在桌面 ZCode 中打开一个项目，再回到这里重试',
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
  'about.tos': '服务条款',
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
  'sched.menu': '定时与自动化',
  'sched.title': '定时与自动化',
  'sched.section.server': '设备自动化',
  'sched.section.local': '本地定时发送',
  'sched.openAuto': '管理设备自动化',
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
  'tasks.menu.automations': '自动化',
  'auto.title': '自动化',
  'auto.subtitle': '由桌面端定时调度，无需 App 在线',
  'auto.add': '新建自动化',
  'auto.edit': '编辑自动化',
  'auto.empty': '暂无自动化',
  'auto.loading': '正在获取自动化列表…',
  'auto.loadFailed': '加载失败: \$0',
  'auto.unavailable.title': '设备自动化不可用',
  'auto.unavailable.body':
      '设备离线或协议握手未完成。可先用「本地定时发送」兜底，设备上线后再来管理。',
  'auto.opFailed': '操作失败: \$0',
  'auto.created': '已创建自动化',
  'auto.saved': '已保存',
  'auto.deleted': '已删除',
  'auto.delete.title': '删除自动化？',
  'auto.delete.body': '将删除「\$0」',
  'auto.enabled': '已启用',
  'auto.disabled': '已停用',
  'auto.name': '标题',
  'auto.prompt': '指令',
  'auto.hint': '由桌面端调度进程定时触发，无需 App 在线',
  'auto.trigger': '触发规则',
  'auto.trigger.cron': 'Cron',
  'auto.trigger.interval': '间隔重复',
  'auto.trigger.oneShot': '一次性延迟',
  'auto.cronExpr': 'Cron 表达式',
  'auto.cronHint': '5 段式，如 0 9 * * 1-5 表示工作日每天 9 点',
  'auto.interval': '间隔',
  'auto.intervalUnit.label': '单位',
  'auto.intervalUnit.minute': '分钟',
  'auto.intervalUnit.hour': '小时',
  'auto.intervalUnit.day': '天',
  'auto.intervalUnit.week': '周',
  'auto.intervalUnit.month': '月',
  'auto.intervalUnit.year': '年',
  'auto.recurring': '无限重复',
  'auto.maxRuns': '最大运行次数',
  'auto.maxRunsN': '最多 \$0 次',
  'auto.delayMinutes': '延迟分钟数',
  'auto.delayHint': '从创建时起延迟执行，最长 1 年',
  'auto.model': '模型（可选）',
  'auto.mode': '模式（可选）',
  'auto.mode.default': '默认',
  'auto.thoughtLevel': '思考等级（可选）',
  'auto.targetTask': '绑定任务 ID（可选）',
  'auto.advanced': '更多选项',
  'auto.cronAt': '按 Cron \$0',
  'auto.every': '每 \$0 \$1',
  'auto.once': '一次性 · \$0后',
  'auto.minutes': '\$0 分钟',
  'auto.hours': '\$0 小时',
  'auto.days': '\$0 天',
  'auto.lastRun': '上次触发 \$0',
  'auto.err.title': '请填写标题',
  'auto.err.prompt': '请填写指令',
  'auto.err.cron': '请填写 Cron 表达式',
  'auto.err.interval': '间隔需为正整数',
  'auto.err.delay': '延迟需在 1 分钟到 1 年之间',
  'tasks.menu.offPeak': '闲时任务',
  'op.title': '闲时任务',
  'op.subtitle': '算力富余时段免费执行 · Coding Plan',
  'op.hint': '提交后排队，在算力富余时段免费执行；需要 Coding Plan 订阅',
  'op.add': '新建闲时任务',
  'op.submit': '提交',
  'op.empty': '暂无闲时任务',
  'op.loading': '正在获取闲时任务…',
  'op.loadFailed': '加载失败: \$0',
  'op.unavailable.title': '闲时任务不可用',
  'op.unavailable.body': '设备离线或协议握手未完成，稍后再试。',
  'op.name': '标题',
  'op.prompt': '指令',
  'op.model': '模型（可选）',
  'op.earliestAt': '最早可用时间（可选）',
  'op.earliest.any': '不限，排队后尽快',
  'op.keepAwake': '保持唤醒',
  'op.keepAwakeHint': '保持与设备的连接，以便及时收到结果',
  'op.permission': '权限模式',
  'op.permission.build': 'build',
  'op.permission.plan': 'plan',
  'op.permission.yolo': 'yolo',
  'op.tpl.ci.title': 'CI flaky 报告',
  'op.tpl.ci.prompt': '分析最近的 CI 失败，找出 flaky 测试并输出报告',
  'op.tpl.docs.title': '文档同步检查',
  'op.tpl.docs.prompt': '检查最近代码变更涉及的文档是否需要同步更新，列出过期条目',
  'op.tpl.standup.title': '站会 git 总结',
  'op.tpl.standup.prompt': '总结昨天的 git 提交，生成站会汇报要点',
  'op.created': '已提交闲时任务',
  'op.quota': '剩余额度 \$0',
  'op.earliest': '最早可用 \$0',
  'op.minutes': '\$0 分钟',
  'op.hours': '\$0 小时',
  'op.duration': '用时 \$0',
  'op.queue': '排队中 #\$0',
  'op.status.queued': '排队中',
  'op.status.running': '执行中',
  'op.status.paused': '已暂停',
  'op.status.completed': '已完成',
  'op.status.failed': '失败',
  'op.status.cancelled': '已取消',
  'op.viewResult': '查看结果',
  'op.cancel': '取消任务',
  'op.deleteTitle': '删除闲时任务？',
  'op.deleteBody': '将从历史中移除「\$0」',
  'op.section.active': '进行中',
  'op.section.history': '历史',
  'op.err.prompt': '请填写指令',
  'op.err.noWorkspace': '该设备没有打开的工作区',
  'op.err.codingPlanOnly': '闲时任务仅 Coding Plan 订阅可用',
  'op.err.quota': '本月闲时额度已用尽',
  'op.err.unavailable': '闲时任务服务暂不可用',
  'op.err.other': '操作失败: \$0',
  'settings.notifications': '通知',
  'settings.notificationsHint': '任务完成/失败、闲时结果与自动化触发推送到本机',
  'settings.notify.tasks': '任务事件',
  'settings.notify.offPeak': '闲时事件',
  'settings.notify.auto': '自动化结果',
  'notify.task.done': '任务完成',
  'notify.task.failed': '任务失败',
  'notify.task.interrupted': '任务已中断',
  'notify.offPeak.done': '闲时任务完成',
  'notify.offPeak.failed': '闲时任务失败',
  'notify.auto.done': '自动化触发成功',
  'notify.auto.failed': '自动化触发失败',
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
  'tasks.pickWorkspace': 'Choose a workspace',
  'tasks.noWorkspaces.title': 'No open workspace on the desktop',
  'tasks.noWorkspaces.body':
      'Open a project in ZCode desktop first, then retry here',
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
  'about.tos': 'Terms of Service',
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
  'sched.menu': 'Scheduled & automations',
  'sched.title': 'Scheduled & automations',
  'sched.section.server': 'Device automations',
  'sched.section.local': 'Local scheduled messages',
  'sched.openAuto': 'Manage device automations',
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
  'tasks.menu.automations': 'Automations',
  'auto.title': 'Automations',
  'auto.subtitle': 'Scheduled by the desktop — the app can be offline',
  'auto.add': 'New automation',
  'auto.edit': 'Edit automation',
  'auto.empty': 'No automations yet',
  'auto.loading': 'Loading automations…',
  'auto.loadFailed': 'Load failed: \$0',
  'auto.unavailable.title': 'Device automations unavailable',
  'auto.unavailable.body':
      'The device is offline or the protocol handshake is unfinished. Use "local scheduled messages" as a fallback and manage automations once the device is back.',
  'auto.opFailed': 'Operation failed: \$0',
  'auto.created': 'Automation created',
  'auto.saved': 'Saved',
  'auto.deleted': 'Deleted',
  'auto.delete.title': 'Delete automation?',
  'auto.delete.body': 'This deletes "\$0".',
  'auto.enabled': 'Enabled',
  'auto.disabled': 'Disabled',
  'auto.name': 'Title',
  'auto.prompt': 'Instruction',
  'auto.hint': 'Triggered by the desktop scheduler; no need to keep the app online',
  'auto.trigger': 'Trigger rule',
  'auto.trigger.cron': 'Cron',
  'auto.trigger.interval': 'Interval',
  'auto.trigger.oneShot': 'One-shot',
  'auto.cronExpr': 'Cron expression',
  'auto.cronHint': '5 fields, e.g. 0 9 * * 1-5 for weekdays at 9',
  'auto.interval': 'Every',
  'auto.intervalUnit.label': 'Unit',
  'auto.intervalUnit.minute': 'minute(s)',
  'auto.intervalUnit.hour': 'hour(s)',
  'auto.intervalUnit.day': 'day(s)',
  'auto.intervalUnit.week': 'week(s)',
  'auto.intervalUnit.month': 'month(s)',
  'auto.intervalUnit.year': 'year(s)',
  'auto.recurring': 'Repeat forever',
  'auto.maxRuns': 'Max runs',
  'auto.maxRunsN': 'max \$0 runs',
  'auto.delayMinutes': 'Delay (minutes)',
  'auto.delayHint': 'Delayed from creation, up to 1 year',
  'auto.model': 'Model (optional)',
  'auto.mode': 'Mode (optional)',
  'auto.mode.default': 'Default',
  'auto.thoughtLevel': 'Thought level (optional)',
  'auto.targetTask': 'Target task ID (optional)',
  'auto.advanced': 'More options',
  'auto.cronAt': 'Cron \$0',
  'auto.every': 'Every \$0 \$1',
  'auto.once': 'One-shot · after \$0',
  'auto.minutes': '\$0 min',
  'auto.hours': '\$0 h',
  'auto.days': '\$0 d',
  'auto.lastRun': 'Last run \$0',
  'auto.err.title': 'Title is required',
  'auto.err.prompt': 'Instruction is required',
  'auto.err.cron': 'Cron expression is required',
  'auto.err.interval': 'Interval must be a positive integer',
  'auto.err.delay': 'Delay must be between 1 minute and 1 year',
  'tasks.menu.offPeak': 'Off-peak tasks',
  'op.title': 'Off-peak tasks',
  'op.subtitle': 'Free runs in compute-rich windows · Coding Plan',
  'op.hint':
      'Queued after submitting, executed free in compute-rich windows; requires a Coding Plan subscription',
  'op.add': 'New off-peak task',
  'op.submit': 'Submit',
  'op.empty': 'No off-peak tasks yet',
  'op.loading': 'Loading off-peak tasks…',
  'op.loadFailed': 'Load failed: \$0',
  'op.unavailable.title': 'Off-peak tasks unavailable',
  'op.unavailable.body':
      'The device is offline or the protocol handshake is unfinished; try again later.',
  'op.name': 'Title',
  'op.prompt': 'Instruction',
  'op.model': 'Model (optional)',
  'op.earliestAt': 'Earliest available (optional)',
  'op.earliest.any': 'Any — run as soon as queued',
  'op.keepAwake': 'Keep awake',
  'op.keepAwakeHint':
      'Keep the device connection alive so results arrive promptly',
  'op.permission': 'Permission mode',
  'op.permission.build': 'build',
  'op.permission.plan': 'plan',
  'op.permission.yolo': 'yolo',
  'op.tpl.ci.title': 'CI flaky report',
  'op.tpl.ci.prompt':
      'Analyze recent CI failures, identify flaky tests and write a report',
  'op.tpl.docs.title': 'Docs sync check',
  'op.tpl.docs.prompt':
      'Check whether docs touched by recent code changes need updating and list stale entries',
  'op.tpl.standup.title': 'Standup git summary',
  'op.tpl.standup.prompt':
      'Summarize yesterday\'s git commits into standup notes',
  'op.created': 'Off-peak task submitted',
  'op.quota': '\$0 quota left',
  'op.earliest': 'Earliest \$0',
  'op.minutes': '\$0 min',
  'op.hours': '\$0 h',
  'op.duration': 'Took \$0',
  'op.queue': 'Queued #\$0',
  'op.status.queued': 'Queued',
  'op.status.running': 'Running',
  'op.status.paused': 'Paused',
  'op.status.completed': 'Completed',
  'op.status.failed': 'Failed',
  'op.status.cancelled': 'Cancelled',
  'op.viewResult': 'View result',
  'op.cancel': 'Cancel task',
  'op.deleteTitle': 'Delete off-peak task?',
  'op.deleteBody': 'This removes "\$0" from history.',
  'op.section.active': 'Active',
  'op.section.history': 'History',
  'op.err.prompt': 'Instruction is required',
  'op.err.noWorkspace': 'No open workspace on this device',
  'op.err.codingPlanOnly':
      'Off-peak tasks require a Coding Plan subscription',
  'op.err.quota': 'Monthly off-peak quota is used up',
  'op.err.unavailable': 'Off-peak service is temporarily unavailable',
  'op.err.other': 'Operation failed: \$0',
  'settings.notifications': 'Notifications',
  'settings.notificationsHint':
      'Task completions, off-peak results and automation runs pushed locally',
  'settings.notify.tasks': 'Task events',
  'settings.notify.offPeak': 'Off-peak events',
  'settings.notify.auto': 'Automation results',
  'notify.task.done': 'Task completed',
  'notify.task.failed': 'Task failed',
  'notify.task.interrupted': 'Task interrupted',
  'notify.offPeak.done': 'Off-peak task completed',
  'notify.offPeak.failed': 'Off-peak task failed',
  'notify.auto.done': 'Automation triggered',
  'notify.auto.failed': 'Automation run failed',
  'settings.checkUpdate': 'Check for updates',
  'update.latest': 'Up to date',
  'update.newVersion': 'New version v\$0',
  'update.availableBody': 'A new ZRemote version is available.',
  'update.download': 'Download in browser',
  'update.later': 'Later',
  'update.failed': 'Update check failed: \$0',
  'update.storePending': 'Check for updates in the App Store',
};
