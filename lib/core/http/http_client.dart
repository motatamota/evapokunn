import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

const userAgent =
    'Mozilla/5.0 (42TokyoSaleTracker/1.0; personal use)';
const baseUrl = 'https://profile.intra.42.fr';

class HttpClient {
  HttpClient._(this._dio, this.cookieJar);

  static Future<HttpClient> create() async {
    final cookieJar = await _buildPersistJar();
    final dio = Dio();
    final opts = dio.options;
    opts.baseUrl = baseUrl;
    opts.connectTimeout = const Duration(seconds: 20);
    opts.receiveTimeout = const Duration(seconds: 30);
    opts.followRedirects = true;
    opts.maxRedirects = 8;
    opts.validateStatus = (code) => code != null && code < 500;
    opts.headers = {
      'User-Agent': userAgent,
      'Accept':
          'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Language': 'ja,en;q=0.8',
    };
    dio.interceptors.add(CookieManager(cookieJar));
    if (!kReleaseMode) {
      dio.interceptors.add(LogInterceptor(
        request: true,
        requestHeader: false,
        requestBody: false,
        responseHeader: false,
        responseBody: false,
        error: true,
      ));
    }
    return HttpClient._(dio, cookieJar);
  }

  /// In-memory jar for tests and the (rare) background entry path before
  /// path_provider is wired up. Prefer [create] for real use.
  HttpClient.inMemory()
      : cookieJar = CookieJar(),
        _dio = Dio() {
    final opts = _dio.options;
    opts.baseUrl = baseUrl;
    opts.headers = {'User-Agent': userAgent};
    opts.validateStatus = (code) => code != null && code < 500;
    _dio.interceptors.add(CookieManager(cookieJar));
  }

  final Dio _dio;
  final CookieJar cookieJar;

  Dio get dio => _dio;

  static Future<PersistCookieJar> _buildPersistJar() async {
    final dir = await getApplicationDocumentsDirectory();
    final cookiePath = p.join(dir.path, 'cookies');
    await Directory(cookiePath).create(recursive: true);
    return PersistCookieJar(
      ignoreExpires: false,
      storage: FileStorage(cookiePath),
    );
  }
}
