import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:html/parser.dart' as html_parser;

import '../../../core/auth/auth_service.dart';
import '../../../core/http/http_client.dart';
import '../domain/evaluation.dart';

final evaluationFetcherProvider =
    FutureProvider<EvaluationFetcher>((ref) async {
  return EvaluationFetcher(
    http: await ref.watch(httpClientProvider.future),
    auth: await ref.watch(authServiceProvider.future),
  );
});

class EvaluationsResult {
  final List<Evaluation> items;
  final bool needsLogin;
  final String? error;
  const EvaluationsResult({
    this.items = const [],
    this.needsLogin = false,
    this.error,
  });
}

/// Fetches the user's intra dashboard and extracts evaluation
/// reservations from `#collapseEvaluations`.
class EvaluationFetcher {
  EvaluationFetcher({required HttpClient http, required AuthService auth})
      : _http = http,
        _auth = auth;

  final HttpClient _http;
  final AuthService _auth;

  Future<EvaluationsResult> fetch() async {
    final ok = await _auth.ensureAuthenticated();
    if (!ok) return const EvaluationsResult(needsLogin: true);

    final res = await _http.dio.get(
      '/',
      options: Options(
        followRedirects: false,
        validateStatus: (c) => c != null && c < 500,
      ),
    );
    final code = res.statusCode ?? 0;
    if (code == 302) {
      final location = res.headers.value('location') ?? '';
      if (location.contains('auth.42.fr') ||
          location.contains('sign_in') ||
          location.contains('/users/auth')) {
        return const EvaluationsResult(needsLogin: true);
      }
    }
    if (code != 200 || res.data is! String) {
      return EvaluationsResult(error: 'HTTP $code');
    }
    return EvaluationsResult(items: _parse(res.data as String));
  }

  /// Extracts evaluation items from `#collapseEvaluations`. The exact
  /// inner DOM is currently unknown (the user has no reservations to
  /// inspect), so we use a forgiving heuristic: any `<a>` with an href,
  /// otherwise any list item / div with non-empty text.
  List<Evaluation> _parse(String html) {
    final doc = html_parser.parse(html);
    final container = doc.querySelector('#collapseEvaluations');
    if (container == null) return const [];

    final result = <Evaluation>[];
    final anchors = container.querySelectorAll('a');
    for (final a in anchors) {
      final text = a.text.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (text.isEmpty) continue;
      result.add(Evaluation(
        text: text,
        url: a.attributes['href'],
        when: _extractTime(a),
      ));
    }
    if (result.isNotEmpty) return result;

    // Fallback: take top-level child divs / lis with text.
    for (final el
        in container.querySelectorAll('li, div.evaluation, [class*="eval"]')) {
      final text = el.text.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (text.isEmpty) continue;
      result.add(Evaluation(text: text, when: _extractTime(el)));
      if (result.length >= 20) break;
    }
    return result;
  }

  DateTime? _extractTime(dynamic el) {
    final t = el.querySelector('time[datetime]');
    final dt = t?.attributes['datetime'];
    if (dt == null) return null;
    return DateTime.tryParse(dt)?.toUtc();
  }
}
