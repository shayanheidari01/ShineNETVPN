import 'dart:async';
import 'server_cache_manager.dart';

/// Immediate server fetching utility service
/// دریافت فوری لیست سرورها و ذخیره در کش
class ImmediateServerFetcher {
  static final ImmediateServerFetcher _instance = ImmediateServerFetcher._internal();
  factory ImmediateServerFetcher() => _instance;
  ImmediateServerFetcher._internal();

  final ServerCacheManager _cacheManager = ServerCacheManager();
  
  /// Fetch servers immediately and cache them
  /// دریافت فوری سرورها و ذخیره در کش
  Future<List<String>> fetchAndCacheNow({
    Function(String)? onStatusUpdate,
    bool forceRefresh = true,
  }) async {
    try {
      onStatusUpdate?.call('🚀 شروع دریافت فوری سرورها...');
      
      // Use the enhanced cache manager for immediate fetching
      final servers = await _cacheManager.fetchAndCacheImmediately(
        onStatusUpdate: onStatusUpdate,
        forceRefresh: forceRefresh,
      );
      
      onStatusUpdate?.call('✅ ${servers.length} سرور با موفقیت دریافت و ذخیره شد!');
      
      return servers;
      
    } catch (e) {
      onStatusUpdate?.call('❌ خطا در دریافت سرورها: ${e.toString()}');
      rethrow;
    }
  }
  
  /// Get servers with automatic fetching if needed
  /// دریافت سرورها با بروزرسانی خودکار در صورت نیاز
  Future<List<String>> getServersWithAutoUpdate({
    Function(String)? onStatusUpdate,
  }) async {
    try {
      return await _cacheManager.getServersWithAutoFetch(
        onStatusUpdate: onStatusUpdate,
      );
    } catch (e) {
      onStatusUpdate?.call('❌ خطا در دریافت خودکار سرورها: ${e.toString()}');
      rethrow;
    }
  }
  
  /// Force refresh all cached data
  /// بروزرسانی اجباری تمام داده‌های کش شده
  Future<void> forceRefreshCache({
    Function(String)? onStatusUpdate,
  }) async {
    try {
      await _cacheManager.refreshServersNow(
        onStatusUpdate: onStatusUpdate,
      );
    } catch (e) {
      onStatusUpdate?.call('❌ خطا در بروزرسانی کش: ${e.toString()}');
      rethrow;
    }
  }
  
  /// Get cache statistics
  /// دریافت آمار کش
  Future<Map<String, dynamic>> getCacheInfo() async {
    try {
      return await _cacheManager.getCacheStats();
    } catch (e) {
      print('❌ خطا در دریافت آمار کش: $e');
      return {};
    }
  }
  
  /// Check if cache is valid
  /// بررسی معتبر بودن کش
  Future<bool> isCacheValid() async {
    try {
      return await _cacheManager.isServerCacheValid();
    } catch (e) {
      print('❌ خطا در بررسی معتبر بودن کش: $e');
      return false;
    }
  }
  
  /// Get cached servers count
  /// دریافت تعداد سرورهای کش شده
  Future<int> getCachedServerCount() async {
    try {
      final servers = await _cacheManager.getCachedServers();
      return servers.length;
    } catch (e) {
      print('❌ خطا در دریافت تعداد سرورهای کش شده: $e');
      return 0;
    }
  }
  
  /// Clear all cache
  /// پاک کردن تمام کش
  Future<void> clearAllCache({
    Function(String)? onStatusUpdate,
  }) async {
    try {
      onStatusUpdate?.call('🗑️ در حال پاک کردن کش...');
      await _cacheManager.clearCache();
      onStatusUpdate?.call('✅ کش با موفقیت پاک شد');
    } catch (e) {
      onStatusUpdate?.call('❌ خطا در پاک کردن کش: ${e.toString()}');
      rethrow;
    }
  }
}
