import 'dart:io' as io;

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../http/http_client.dart';

/// Opens an in-app WebView so the user can complete the 42 Keycloak
/// login (including 2FA). On success the WebView cookies — including
/// the HttpOnly Rails session cookie — are copied into the Dio cookie
/// jar so the rest of the app can scrape the intra as that user.
class WebLoginPage extends StatefulWidget {
  const WebLoginPage({super.key, required this.httpClient});

  final HttpClient httpClient;

  @override
  State<WebLoginPage> createState() => _WebLoginPageState();
}

class _WebLoginPageState extends State<WebLoginPage> {
  final _cookieManager = CookieManager.instance();
  bool _loading = true;
  bool _capturing = false;
  String _currentUrl = '$baseUrl/';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showIntraVersionWarning());
  }

  Future<void> _showIntraVersionWarning() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_amber, color: Colors.orange, size: 32),
        title: const Text('intra v2 を利用します'),
        content: const Text(
          'このアプリは intra v2 (profile.intra.42.fr) からデータを取得します。\n\n'
          'intra v3 を使っているとアプリは動作しません。intra の設定で '
          'v2 に切り替えてからログインしてください。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('了解'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('42 にログイン'),
        actions: [
          IconButton(
            tooltip: '閉じる（キャンセル）',
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: _loading
              ? const LinearProgressIndicator(minHeight: 2)
              : const SizedBox(height: 2),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              _currentUrl,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: InAppWebView(
              initialUrlRequest: URLRequest(
                url: WebUri('$baseUrl/'),
              ),
              initialSettings: InAppWebViewSettings(
                userAgent: userAgent,
                javaScriptEnabled: true,
                clearCache: false,
                thirdPartyCookiesEnabled: true,
                cacheEnabled: true,
              ),
              onLoadStart: (_, url) {
                setState(() {
                  _loading = true;
                  _currentUrl = url?.toString() ?? _currentUrl;
                });
              },
              onLoadStop: (_, url) async {
                setState(() {
                  _loading = false;
                  _currentUrl = url?.toString() ?? _currentUrl;
                });
                await _maybeCaptureCookies(url);
              },
            ),
          ),
          if (_capturing) const LinearProgressIndicator(),
        ],
      ),
    );
  }

  /// Heuristic: we're "logged in" when the current URL is on
  /// profile.intra.42.fr and not on an auth/sign-in path.
  bool _looksAuthenticated(Uri uri) {
    if (uri.host != 'profile.intra.42.fr') return false;
    final path = uri.path.toLowerCase();
    if (path.contains('sign_in')) return false;
    if (path.contains('/users/auth')) return false;
    return true;
  }

  Future<void> _maybeCaptureCookies(WebUri? url) async {
    if (_capturing) return;
    if (url == null) return;
    final uri = Uri.tryParse(url.toString());
    if (uri == null || !_looksAuthenticated(uri)) return;
    setState(() => _capturing = true);
    try {
      final ok = await _copyCookiesToJar();
      if (!ok) return;
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  Future<bool> _copyCookiesToJar() async {
    final cookies = await _cookieManager.getCookies(url: WebUri(baseUrl));
    if (cookies.isEmpty) return false;

    final ioCookies = <io.Cookie>[];
    for (final c in cookies) {
      final cookie = io.Cookie(c.name, c.value.toString())
        ..path = c.path ?? '/'
        ..secure = c.isSecure ?? true
        ..httpOnly = c.isHttpOnly ?? false;
      final domain = c.domain;
      if (domain != null && domain.isNotEmpty) {
        cookie.domain = domain;
      } else {
        cookie.domain = 'profile.intra.42.fr';
      }
      final exp = c.expiresDate;
      if (exp != null) {
        cookie.expires = DateTime.fromMillisecondsSinceEpoch(exp);
      }
      ioCookies.add(cookie);
    }

    await widget.httpClient.cookieJar.saveFromResponse(
      Uri.parse(baseUrl),
      ioCookies,
    );
    return true;
  }
}
