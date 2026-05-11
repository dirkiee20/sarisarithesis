import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  // Override API_BASE_URL with --dart-define for local/dev builds when needed.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://sarisarithesis-production.up.railway.app/api',
  );

  late final Dio dio;

  // Separate Dio instance used only for token refresh — avoids infinite loop.
  static final Dio _refreshDio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {'Content-Type': 'application/json'},
  ));

  // Lock flag to prevent multiple simultaneous refresh calls.
  static bool _isRefreshing = false;

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
        final token = prefs.getString('auth_token');
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (DioException e, handler) async {
        // Only attempt refresh on 401 and when we aren't already refreshing.
        if (e.response?.statusCode != 401 || _isRefreshing) {
          return handler.next(e);
        }

        _isRefreshing = true;
        try {
          final prefs = await SharedPreferences.getInstance();
          final refreshToken = prefs.getString('auth_refresh_token');

          if (refreshToken == null || refreshToken.isEmpty) {
            // No refresh token — cannot recover; pass error through.
            return handler.next(e);
          }

          // Call /auth/refresh using the dedicated Dio instance.
          final refreshResponse = await _refreshDio.post(
            '/auth/refresh',
            data: {'refreshToken': refreshToken},
          );

          final newAccessToken =
              refreshResponse.data['accessToken'] as String?;
          final newRefreshToken =
              refreshResponse.data['refreshToken'] as String?;

          if (newAccessToken == null || newRefreshToken == null) {
            return handler.next(e);
          }

          // Persist the new tokens.
          await prefs.setString('auth_token', newAccessToken);
          await prefs.setString('auth_refresh_token', newRefreshToken);

          debugPrint('[ApiClient] Access token refreshed successfully.');

          // Retry the original request with the new access token.
          final retryOptions = e.requestOptions;
          retryOptions.headers['Authorization'] = 'Bearer $newAccessToken';

          final retryResponse = await dio.fetch(retryOptions);
          return handler.resolve(retryResponse);
        } on DioException catch (refreshError) {
          debugPrint(
            '[ApiClient] Token refresh failed: '
            '${refreshError.response?.data ?? refreshError.message}',
          );
          // Clear stored tokens so the user is prompted to log in again.
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('auth_token');
          await prefs.remove('auth_refresh_token');
          return handler.next(e);
        } finally {
          _isRefreshing = false;
        }
      },
    ));
  }
}

final apiClient = ApiClient().dio;
