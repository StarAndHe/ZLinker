import 'package:flutter/material.dart';

import '../state/device_session.dart';
import 'theme.dart';
import 'ui_settings.dart';

/// Entitlement / quota usage of one device
/// (usage-stats.getEntitlementSnapshot over the workspace bridge).
class DeviceUsagePage extends StatefulWidget {
  final DeviceSession session;
  const DeviceUsagePage({super.key, required this.session});

  @override
  State<DeviceUsagePage> createState() => _DeviceUsagePageState();
}

class _DeviceUsagePageState extends State<DeviceUsagePage> {
  Map<String, dynamic>? _data;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await widget.session.callChannel(
        'usage-stats',
        'getEntitlementSnapshot',
        [
          {'includeSubscription': true}
        ],
      );
      if (mounted) {
        setState(() {
          _data = res is Map ? res.cast<String, dynamic>() : {};
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _loading = false;
        });
      }
    }
  }

  String _fmtTime(Object? millis) {
    if (millis is! num) return '-';
    final t = DateTime.fromMillisecondsSinceEpoch(millis.toInt()).toLocal();
    return '${t.year}-${t.month.toString().padLeft(2, '0')}-'
        '${t.day.toString().padLeft(2, '0')} '
        '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(context, 'usageRpc.title')),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(trP(context, 'usageRpc.loadFailed', [_error!])))
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    final data = _data ?? const {};
    final context_ = data['context'];
    final provider = data['provider'];
    final remaining = data['remaining'];
    final subscription = data['subscription'];
    final quota = data['quota'];

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: ZColors.sky500.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.bolt, color: ZColors.sky500),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context_ is Map
                              ? '${context_['displayName'] ?? '-'}'
                              : '-',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          [
                            if (provider is Map) '${provider['name'] ?? ''}',
                            if (quota is Map && quota['level'] != null)
                              '${quota['level']}',
                          ].join(' · '),
                          style: TextStyle(
                              fontSize: 12, color: ZInk.faint(context)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (remaining is Map && remaining['isShow'] == true)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(tr(context, 'usageRpc.remaining'),
                            style: const TextStyle(fontSize: 14)),
                        Text(
                          '${remaining['count'] ?? '-'}',
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: ZColors.sky500),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value:
                            ((remaining['percentage'] as num?) ?? 0) / 100,
                        minHeight: 6,
                        backgroundColor:
                            Theme.of(context).colorScheme.surfaceContainerHighest,
                        valueColor:
                            const AlwaysStoppedAnimation(ZColors.sky500),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      trP(context, 'usageRpc.remainingDetail', [
                        '${remaining['percentage'] ?? '-'}',
                        _fmtTime(remaining['nextResetTime']),
                      ]),
                      style: TextStyle(
                          fontSize: 11, color: ZInk.faint(context)),
                    ),
                  ],
                ),
              ),
            ),
          if (quota is Map && quota['limits'] is List) ...[
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr(context, 'usageRpc.limits'),
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    for (final limit in quota['limits'] as List)
                      if (limit is Map)
                        _LimitRow(
                            limit: limit.cast<String, dynamic>(),
                            fmtTime: _fmtTime),
                  ],
                ),
              ),
            ),
          ],
          if (subscription is Map &&
              subscription['details'] is List &&
              (subscription['details'] as List).isNotEmpty) ...[
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr(context, 'usageRpc.subscription'),
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    for (final d in subscription['details'] as List)
                      if (d is Map) ...[
                        _kv(tr(context, 'usageRpc.product'),
                            '${d['productName'] ?? '-'}'),
                        _kv(tr(context, 'usageRpc.billing'),
                            '${d['billingCycle'] ?? '-'}'),
                        _kv(tr(context, 'usageRpc.renew'),
                            '${d['renewTime'] ?? '-'}'),
                        _kv(tr(context, 'usageRpc.expire'),
                            '${d['expireTime'] ?? '-'}'),
                      ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _kv(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(fontSize: 12, color: ZInk.muted(context))),
          Flexible(
            child: Text(value,
                style: const TextStyle(fontSize: 12),
                textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }
}

class _LimitRow extends StatelessWidget {
  final Map<String, dynamic> limit;
  final String Function(Object?) fmtTime;

  const _LimitRow({required this.limit, required this.fmtTime});

  @override
  Widget build(BuildContext context) {
    final type = '${limit['type'] ?? ''}';
    final percentage = (limit['percentage'] as num?)?.toDouble();
    final usageDetails = limit['usageDetails'];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$type · unit ${limit['unit'] ?? '-'}',
                  style: const TextStyle(fontSize: 12)),
              Text(
                [
                  if (limit['usage'] != null)
                    trP(context, 'usageRpc.used', ['${limit['usage']}']),
                  if (limit['remaining'] != null)
                    trP(context, 'usageRpc.left', ['${limit['remaining']}']),
                  if (percentage != null) '$percentage%',
                ].join(' · '),
                style: TextStyle(fontSize: 11, color: ZInk.muted(context)),
              ),
            ],
          ),
          if (percentage != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: (percentage / 100).clamp(0.0, 1.0),
                  minHeight: 4,
                  backgroundColor:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation(
                    percentage > 80 ? ZColors.danger : ZColors.sky500,
                  ),
                ),
              ),
            ),
          if (usageDetails is List && usageDetails.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                usageDetails
                    .whereType<Map>()
                    .map((u) => '${u['modelCode']}: ${u['usage']}')
                    .join('  '),
                style:
                    TextStyle(fontSize: 10, color: ZInk.faint(context)),
              ),
            ),
          Text(
            trP(context, 'usageRpc.resetAt', [fmtTime(limit['nextResetTime'])]),
            style: TextStyle(fontSize: 10, color: ZInk.ghost(context)),
          ),
        ],
      ),
    );
  }
}
