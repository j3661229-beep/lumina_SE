import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ApiClient {
  static ApiClient? _instance;
  late final Dio _dio;

  ApiClient._() {
    _dio = Dio(
      BaseOptions(
        baseUrl: const String.fromEnvironment(
          'API_BASE_URL',
          defaultValue: 'http://10.10.43.18:3000/api',
        ),
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 60),
        // Do NOT set Content-Type here — let Dio set it per-request.
        // Hardcoding 'application/json' breaks multipart/form-data file uploads.
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final session = Supabase.instance.client.auth.currentSession;
          if (session != null) {
            options.headers['Authorization'] = 'Bearer ${session.accessToken}';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            // Try to refresh the session before signing out
            try {
              final refreshed = await Supabase.instance.client.auth.refreshSession();
              if (refreshed.session != null) {
                // Retry the original request with the new token
                final opts = error.requestOptions;
                opts.headers['Authorization'] =
                    'Bearer ${refreshed.session!.accessToken}';
                final retry = await _dio.fetch(opts);
                return handler.resolve(retry);
              }
            } catch (_) {}
            // Refresh failed — sign out and let GoRouter redirect to /auth
            Supabase.instance.client.auth.signOut();
          }
          handler.next(error);
        },
      ),
    );
  }

  static ApiClient get instance => _instance ??= ApiClient._();
  Dio get dio => _dio;

  Future<T> get<T>(String path, {Map<String, dynamic>? params}) async {
    final res = await _dio.get<T>(path, queryParameters: params);
    return res.data as T;
  }

  Future<T> post<T>(String path, {required Map<String, dynamic> data}) async {
    final res = await _dio.post<T>(path, data: data);
    return res.data as T;
  }

  Future<T> put<T>(String path, {required Map<String, dynamic> data}) async {
    final res = await _dio.put<T>(path, data: data);
    return res.data as T;
  }

  Future<void> delete(String path) async => await _dio.delete(path);
}
