import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';

import '../state/device_store.dart';
import 'theme.dart';

/// Full-screen web remote control page. The official ZCode web app owns the
/// entire protocol; we only load the device URL. keepAlive keeps the session
/// warm so reopening the same device is instant.
class RemotePage extends StatefulWidget {
  final Device device;
  const RemotePage({super.key, required this.device});

  @override
  State<RemotePage> createState() => _RemotePageState();
}

class _RemotePageState extends State<RemotePage> {
  InAppWebViewController? _controller;
  double _progress = 0;
  bool _hasError = false;
  String? _errorDescription;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.device.label,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            Text('zcode.z.ai',
                style: TextStyle(fontSize: 11, color: ZInk.faint(context))),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _controller?.reload(),
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'browser') {
                await launchUrl(Uri.parse(widget.device.url),
                    mode: LaunchMode.externalApplication);
              } else if (v == 'reload') {
                await _controller?.reload();
              }
            },
            itemBuilder: (c) => const [
              PopupMenuItem(value: 'browser', child: Text('在浏览器中打开')),
              PopupMenuItem(value: 'reload', child: Text('重新加载')),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: _progress < 1 && !_hasError
              ? const LinearProgressIndicator(
                  minHeight: 2,
                  color: ZColors.sky500,
                  backgroundColor: Colors.transparent,
                )
              : const SizedBox(height: 2),
        ),
      ),
      body: Stack(
        children: [
          InAppWebView(
            initialUrlRequest:
                URLRequest(url: WebUri(widget.device.url)),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              domStorageEnabled: true,
              databaseEnabled: true,
              useHybridComposition: true,
              // Keep the page alive across list<->remote navigation.
              // (incognito must stay false so DOM storage persists pairing.)
              incognito: false,
              supportZoom: false,
              mediaPlaybackRequiresUserGesture: false,
            ),
            onWebViewCreated: (c) => _controller = c,
            onProgressChanged: (c, p) =>
                setState(() => _progress = p / 100),
            onReceivedError: (c, request, error) {
              if (request.isForMainFrame ?? true) {
                setState(() {
                  _hasError = true;
                  _errorDescription = error.description;
                });
              }
            },
          ),
          if (_hasError)
            Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              alignment: Alignment.center,
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_off,
                      size: 48, color: ZInk.ghost(context)),
                  const SizedBox(height: 16),
                  Text('无法连接到桌面设备',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: ZInk.solid(context))),
                  const SizedBox(height: 8),
                  Text(
                    _errorDescription?.isNotEmpty == true
                        ? _errorDescription!
                        : '请确认桌面 ZCode 已打开且网络可用',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(fontSize: 13, color: ZInk.faint(context)),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () {
                      setState(() {
                        _hasError = false;
                        _progress = 0;
                      });
                      _controller?.reload();
                    },
                    child: const Text('重试'),
                  ),
                ],
              ),
            ),
        ],
      ),
      backgroundColor:
          isDark ? ZColors.darkBackground : ZColors.lightBackground,
    );
  }
}
