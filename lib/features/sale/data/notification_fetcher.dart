import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_service.dart';
import '../../../core/http/http_client.dart';

final notificationFetcherProvider = FutureProvider<NotificationFetcher>((ref) async {
  return NotificationFetcher(
    http: await ref.watch(httpClientProvider.future),
    auth: await ref.watch(authServiceProvider.future),
  );
});

class FetchResult {
  final int statusCode;
  final String? html;
  final String? etag;
  final String? lastModified;
  final bool notModified;
  final bool needsLogin;
  final int page;
  const FetchResult({
    required this.statusCode,
    this.html,
    this.etag,
    this.lastModified,
    this.notModified = false,
    this.needsLogin = false,
    this.page = 1,
  });
}

class FetchedPages {
  final List<FetchResult> pages;
  final bool needsLogin;
  const FetchedPages({required this.pages, this.needsLogin = false});

  bool get isEmpty => pages.isEmpty;
}

class NotificationFetcher {
  NotificationFetcher({required HttpClient http, required AuthService auth})
      : _http = http,
        _auth = auth;

  final HttpClient _http;
  final AuthService _auth;

  static const path = '/notifications';

  /// Fetch one page (defaults to page 1).
  Future<FetchResult> fetch({
    int page = 1,
    String? etag,
    String? lastModified,
  }) async {
    final ok = await _auth.ensureAuthenticated();
    if (!ok) {
      return FetchResult(statusCode: 401, needsLogin: true, page: page);
    }
    final headers = <String, dynamic>{};
    if (etag != null) headers['If-None-Match'] = etag;
    if (lastModified != null) headers['If-Modified-Since'] = lastModified;

    final res = await _http.dio.get(
      path,
      queryParameters: page > 1 ? {'page': page} : null,
      options: Options(
        headers: headers,
        followRedirects: false,
        validateStatus: (c) => c != null && c < 500,
      ),
    );
    final code = res.statusCode ?? 0;
    if (code == 304) {
      return FetchResult(statusCode: 304, notModified: true, page: page);
    }
    if (code == 302) {
      final location = res.headers.value('location') ?? '';
      if (_isAuthRedirect(location)) {
        return FetchResult(statusCode: 401, needsLogin: true, page: page);
      }
    }
    return FetchResult(
      statusCode: code,
      html: res.data is String ? res.data as String : res.data?.toString(),
      etag: res.headers.value('etag'),
      lastModified: res.headers.value('last-modified'),
      page: page,
    );
  }

  /// Fetch multiple pages sequentially. Stops early on auth failure or
  /// non-200 (consider it end-of-list). Adds a small delay between
  /// requests to be polite (spec §6).
  Future<FetchedPages> fetchPages(int count) async {
    final pages = <FetchResult>[];
    for (var i = 1; i <= count; i++) {
      final res = await fetch(page: i);
      if (res.needsLogin) {
        return FetchedPages(pages: pages, needsLogin: true);
      }
      if (res.statusCode != 200 || res.html == null) {
        // First failure: bail out — likely past last page or rate-limited.
        if (pages.isEmpty) pages.add(res);
        break;
      }
      pages.add(res);
      if (i < count) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    }
    return FetchedPages(pages: pages);
  }

  bool _isAuthRedirect(String location) {
    return location.contains('auth.42.fr') ||
        location.contains('sign_in') ||
        location.contains('/users/auth');
  }
}
