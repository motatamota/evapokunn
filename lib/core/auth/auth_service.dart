import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  /// Resolves the logged-in user's login (e.g. "ahirayam") by
  /// inspecting where `/users/me` redirects to. Returns null if not
  /// authenticated or the redirect target is unexpected.
  Future<String?> fetchUsername() async {
    final res = await _http.dio.get(
      '/users/me',
      options: Options(
        followRedirects: false,
        validateStatus: (c) => c != null && c < 500,
      ),
    );
    if (res.statusCode != 302) return null;
    final location = res.headers.value('location') ?? '';
    final match = RegExp(r'/users/([^/?#]+)').firstMatch(location);
    final login = match?.group(1);
    if (login == null || login == 'me') return null;
    return login;
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
