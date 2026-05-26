import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:html/parser.dart' as html_parser;

import '../http/http_client.dart';

final httpClientProvider = FutureProvider<HttpClient>((ref) async {
  return HttpClient.create();
});

final authServiceProvider = FutureProvider<AuthService>((ref) async {
  final http = await ref.watch(httpClientProvider.future);
  return AuthService(http: http);
});

/// Cookie-based authentication for profile.intra.42.fr.
///
/// We don't run the OAuth/Keycloak flow ourselves (2FA makes that
/// impractical). Instead the user logs in via [WebLoginPage] and the
/// resulting session cookies are persisted on disk. This service only
/// checks whether those cookies still authenticate us.
class AuthService {
  AuthService({required HttpClient http}) : _http = http;

  final HttpClient _http;

  /// True when the current cookies authenticate us against the intra.
  Future<bool> ensureAuthenticated() async {
    final res = await _http.dio.get(
      '/',
      options: Options(
        followRedirects: false,
        validateStatus: (code) => code != null && code < 500,
      ),
    );
    final code = res.statusCode ?? 0;
    final location = res.headers.value('location') ?? '';
    if (code == 200) return true;
    if (code == 302 && _isAuthRedirect(location)) return false;
    return false;
  }

  Future<void> logout() async {
    _http.cookieJar.deleteAll();
  }

  /// Resolves the logged-in user's login (e.g. "ahirayam").
  /// Tries three strategies in order, returning the first that yields
  /// a usable login:
  ///   1. `/users/me` → 302 → Location: `/users/<login>`
  ///   2. `/users/me` → 200 → parse the rendered profile page
  ///   3. dashboard `/` → parse navbar / canonical link
  Future<String?> fetchUsername() async {
    // 1 + 2
    try {
      final res = await _http.dio.get(
        '/users/me',
        options: Options(
          followRedirects: false,
          validateStatus: (c) => c != null && c < 500,
        ),
      );
      final code = res.statusCode ?? 0;
      if (code == 302) {
        final from = _loginFromUrl(res.headers.value('location') ?? '');
        if (from != null) return from;
      }
      if (code == 200 && res.data is String) {
        final from = _loginFromHtml(res.data as String);
        if (from != null) return from;
      }
    } catch (_) {}

    // 3
    try {
      final res = await _http.dio.get('/');
      if ((res.statusCode ?? 0) == 200 && res.data is String) {
        return _loginFromHtml(res.data as String);
      }
    } catch (_) {}

    return null;
  }

  String? _loginFromUrl(String url) {
    final match = RegExp(r'/users/([^/?#]+)').firstMatch(url);
    final login = match?.group(1);
    if (login == null || login.isEmpty || login == 'me' || login == 'auth') {
      return null;
    }
    return login;
  }

  String? _loginFromHtml(String html) {
    final doc = html_parser.parse(html);
    // Canonical link is the most reliable on a logged-in profile page.
    final canonical =
        doc.querySelector('link[rel="canonical"]')?.attributes['href'];
    if (canonical != null) {
      final v = _loginFromUrl(canonical);
      if (v != null) return v;
    }
    // og:url meta
    final og = doc.querySelector('meta[property="og:url"]')?.attributes['content'];
    if (og != null) {
      final v = _loginFromUrl(og);
      if (v != null) return v;
    }
    // Any /users/<login> link in the navbar/header.
    for (final a in doc.querySelectorAll('a[href*="/users/"]')) {
      final v = _loginFromUrl(a.attributes['href'] ?? '');
      if (v != null) return v;
    }
    return null;
  }

  Future<List<Cookie>> sessionCookies() {
    return _http.cookieJar.loadForRequest(Uri.parse(baseUrl));
  }

  bool _isAuthRedirect(String location) {
    return location.contains('auth.42.fr') ||
        location.contains('/users/auth/') ||
        location.contains('sign_in');
  }
}
