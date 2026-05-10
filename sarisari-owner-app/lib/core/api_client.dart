import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  // Override API_BASE_URL with --dart-define for local/dev builds when needed.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://sarisarithesis-production.up.railway.app/api',
  );

  late final Dio dio;
  Future<String?>? _refreshFuture;

  ApiClient() {
    dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Content-Type': 'application/json',
      },
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('owner_token');
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (DioException e, handler) {
        _handleAuthError(e, handler);
      },
    ));
  }

  Future<void> _handleAuthError(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    final statusCode = error.response?.statusCode;
    final alreadyRetried = error.requestOptions.extra['authRetry'] == true;

    if (statusCode != 401 || alreadyRetried) {
      return handler.next(error);
    }

    final newToken = await _refreshAccessToken();
    if (newToken == null) {
      return handler.next(error);
    }

    final retryOptions = error.requestOptions;
    retryOptions.extra['authRetry'] = true;
    retryOptions.headers['Authorization'] = 'Bearer $newToken';

    try {
      final response = await dio.fetch<dynamic>(retryOptions);
      return handler.resolve(response);
    } on DioException catch (retryError) {
      return handler.next(retryError);
    }
  }

  Future<String?> _refreshAccessToken() {
    _refreshFuture ??= _performRefresh().whenComplete(() {
      _refreshFuture = null;
    });
    return _refreshFuture!;
  }

  Future<String?> _performRefresh() async {
    final prefs = await SharedPreferences.getInstance();
    final refreshToken = prefs.getString('owner_refresh_token');
    if (refreshToken == null || refreshToken.isEmpty) {
      await _clearAuthTokens(prefs);
      return null;
    }

    try {
      final refreshClient = Dio(BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'Content-Type': 'application/json',
        },
      ));

      final response = await refreshClient.post('/auth/refresh', data: {
        'refreshToken': refreshToken,
      });

      final data = response.data;
      if (data is! Map || data['accessToken'] == null) {
        await _clearAuthTokens(prefs);
        return null;
      }

      final accessToken = data['accessToken'].toString();
      await prefs.setString('owner_token', accessToken);
      if (data['refreshToken'] != null) {
        await prefs.setString(
          'owner_refresh_token',
          data['refreshToken'].toString(),
        );
      }

      return accessToken;
    } catch (_) {
      await _clearAuthTokens(prefs);
      return null;
    }
  }

  Future<void> _clearAuthTokens(SharedPreferences prefs) async {
    await prefs.remove('owner_token');
    await prefs.remove('owner_refresh_token');
  }
}

final apiClient = ApiClient().dio;
