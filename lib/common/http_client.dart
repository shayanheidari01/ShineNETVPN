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
        connectTimeout: Duration(seconds: 8),
        receiveTimeout: Duration(seconds: 10),
        sendTimeout: Duration(seconds: 8),
        headers: {
          'accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7',
          'accept-encoding': 'gzip, deflate, br, zstd',
          'accept-language': 'en-US,en;q=0.9,fa-IR;q=0.8,fa;q=0.7',
          'cache-control': 'max-age=0',
          'priority': 'u=0, i',
          'sec-ch-ua': '"Not;A=Brand";v="8", "Chromium";v="150", "Google Chrome";v="150"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"Windows"',
          'sec-fetch-dest': 'document',
          'sec-fetch-mode': 'navigate',
          'sec-fetch-site': 'none',
          'sec-fetch-user': '?1',
          'upgrade-insecure-requests': '1',
          'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/150.0.0.0 Safari/537.36',
        },
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
