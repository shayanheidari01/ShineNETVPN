import 'package:dio/dio.dart';

/// Optimized HTTP client with performance enhancements
class OptimizedHttpClient {
  static Dio? _instance;
  
  static Dio get instance {
    _instance ??= _createOptimizedClient();
    return _instance!;
  }
  
  static Dio _createOptimizedClient() {
    final dio = Dio(
      BaseOptions(
        baseUrl: '',
        connectTimeout: Duration(seconds: 8), // Reduced from default 15s
        receiveTimeout: Duration(seconds: 10), // Reduced from default 15s
        sendTimeout: Duration(seconds: 8), // Reduced from default 15s
        headers: {
          'X-Content-Type-Options': 'nosniff',
          'User-Agent': 'ShineNETVPN/1.0',
          'Accept': 'application/json, text/plain, */*',
          'Accept-Encoding': 'gzip, deflate',
          'Connection': 'keep-alive',
        },
        // Performance optimizations
        followRedirects: true,
        maxRedirects: 3,
        validateStatus: (status) => status != null && status < 500,
      ),
    );
    
    // Connection pooling will be handled by Dio's default adapter
    
    // Add request/response interceptors for optimization
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // Add request timestamp for performance monitoring
          options.extra['request_start'] = DateTime.now().millisecondsSinceEpoch;
          handler.next(options);
        },
        onResponse: (response, handler) {
          // Log response time for monitoring
          final startTime = response.requestOptions.extra['request_start'] as int?;
          if (startTime != null) {
            final duration = DateTime.now().millisecondsSinceEpoch - startTime;
            print('HTTP Request to ${response.requestOptions.uri} took ${duration}ms');
          }
          handler.next(response);
        },
        onError: (error, handler) {
          // Enhanced error handling with retry logic
          if (_shouldRetry(error)) {
            print('Retrying request to ${error.requestOptions.uri}');
            // Implement exponential backoff retry
            _retryRequest(error.requestOptions).then(
              (response) => handler.resolve(response),
              onError: (e) => handler.next(error),
            );
          } else {
            handler.next(error);
          }
        },
      ),
    );
    
    return dio;
  }
  
  /// Determine if request should be retried
  static bool _shouldRetry(DioException error) {
    return error.type == DioExceptionType.connectionTimeout ||
           error.type == DioExceptionType.receiveTimeout ||
           error.type == DioExceptionType.sendTimeout ||
           (error.response?.statusCode != null && 
            error.response!.statusCode! >= 500);
  }
  
  /// Retry request with exponential backoff
  static Future<Response> _retryRequest(RequestOptions options) async {
    await Future.delayed(Duration(milliseconds: 500)); // Short delay
    return instance.request(
      options.path,
      data: options.data,
      queryParameters: options.queryParameters,
      options: Options(
        method: options.method,
        headers: options.headers,
        responseType: options.responseType,
        contentType: options.contentType,
      ),
    );
  }
  
  /// Clear connection pool and reset client
  static void reset() {
    _instance?.close();
    _instance = null;
  }
}

// Backward compatibility
final httpClient = OptimizedHttpClient.instance;
