import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../protocol/connection_params.dart';
import '../protocol/id.dart';

class Device {
  final String id;
  String label;
  final String url;
  final int addedAt;
  int? lastUsedAt;

  /// Times the device was opened (WebView or native actions). Purely local
  /// usage stats; absent in old backups and defaults to 0.
  int useCount;

  Device({
    required this.id,
    required this.label,
    required this.url,
    required this.addedAt,
    this.lastUsedAt,
    this.useCount = 0,
  });

  factory Device.fromUrl(String url, {String? label}) {
    final params = RemoteConnectionParams.parse(url);
    return Device(
      id: generateUuid(),
      label: (label != null && label.trim().isNotEmpty)
          ? label.trim()
          : (params?.deviceName ??
              params?.source.host ??
              '未命名设备'),
      url: url.trim(),
      addedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  RemoteConnectionParams? get params => RemoteConnectionParams.parse(url);

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'url': url,
        'addedAt': addedAt,
        if (lastUsedAt != null) 'lastUsedAt': lastUsedAt,
        if (useCount > 0) 'useCount': useCount,
      };

  factory Device.fromJson(Map<String, dynamic> j) => Device(
        id: j['id'] as String? ?? generateUuid(),
        label: j['label'] as String? ?? '未命名设备',
        url: j['url'] as String? ?? '',
        addedAt: j['addedAt'] as int? ?? DateTime.now().millisecondsSinceEpoch,
        lastUsedAt: j['lastUsedAt'] as int?,
        useCount: j['useCount'] as int? ?? 0,
      );
}

class DeviceStore extends ChangeNotifier {
  static const _key = 'zremote_devices_v1';
  final List<Device> _devices = [];
  bool _loaded = false;

  List<Device> get devices => List.unmodifiable(_devices);
  bool get loaded => _loaded;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        _devices
          ..clear()
          ..addAll(list
              .whereType<Map<String, dynamic>>()
              .map(Device.fromJson)
              .where((d) => d.url.isNotEmpty));
      } catch (_) {
        // Corrupt storage should not crash the app; start empty.
      }
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(_devices.map((d) => d.toJson()).toList()));
  }

  /// Adds a device from a pasted/scanned URL. Returns the new device, or the
  /// existing one if the URL was already stored (dedupe).
  Future<Device> addUrl(String url, {String? label}) async {
    final trimmed = url.trim();
    final existing =
        _devices.where((d) => d.url == trimmed).firstOrNull;
    if (existing != null) return existing;
    final device = Device.fromUrl(trimmed, label: label);
    _devices.add(device);
    notifyListeners();
    await _save();
    return device;
  }

  Future<void> remove(String id) async {
    _devices.removeWhere((d) => d.id == id);
    notifyListeners();
    await _save();
  }

  Future<void> rename(String id, String label) async {
    final d = _devices.firstWhere((e) => e.id == id, orElse: () => throw StateError('not found'));
    d.label = label.trim().isEmpty ? d.label : label.trim();
    notifyListeners();
    await _save();
  }

  Future<void> touch(String id) async {
    final d = _devices.where((d) => d.id == id).firstOrNull;
    if (d == null) return;
    d.lastUsedAt = DateTime.now().millisecondsSinceEpoch;
    d.useCount += 1;
    notifyListeners();
    await _save();
  }

  /// Backup/export envelope.
  String exportJson() => jsonEncode({
        'app': 'zremote',
        'format': 'devices',
        'version': 1,
        'exportedAt': DateTime.now().toIso8601String(),
        'devices': _devices.map((d) => d.toJson()).toList(),
      });

  /// Imports devices from [exportJson] output. Skips duplicates and empty
  /// URLs. Returns the number of devices added.
  Future<int> importJson(String raw) async {
    final data = jsonDecode(raw);
    final list = (data is Map<String, dynamic> ? data['devices'] : data)
        as List<dynamic>;
    var added = 0;
    for (final item in list.whereType<Map<String, dynamic>>()) {
      final url = (item['url'] as String? ?? '').trim();
      if (url.isEmpty) continue;
      if (_devices.any((d) => d.url == url)) continue;
      _devices.add(Device.fromJson(item));
      added++;
    }
    if (added > 0) {
      notifyListeners();
      await _save();
    }
    return added;
  }
}
