package com.shythonx.shinenet_vpn

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import org.json.JSONArray
import org.json.JSONObject

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.shythonx.shinenet_vpn/native_ping"
    private lateinit var pingService: NativePingService
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Initialize native ping service
        pingService = NativePingService()
        
        // Set up method channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "tcpPing" -> {
                    val host = call.argument<String>("host") ?: ""
                    val port = call.argument<Int>("port") ?: 80
                    val timeout = call.argument<Int>("timeout") ?: 1000
                    
                    CoroutineScope(Dispatchers.Main).launch {
                        try {
                            val pingResult = pingService.tcpPing(host, port, timeout)
                            result.success(pingResult)
                        } catch (e: Exception) {
                            result.error("TCP_PING_ERROR", e.message, null)
                        }
                    }
                }
                
                "icmpPing" -> {
                    val host = call.argument<String>("host") ?: ""
                    val timeout = call.argument<Int>("timeout") ?: 2000
                    val count = call.argument<Int>("count") ?: 1
                    
                    CoroutineScope(Dispatchers.Main).launch {
                        try {
                            val pingResult = pingService.icmpPing(host, timeout, count)
                            result.success(pingResult)
                        } catch (e: Exception) {
                            result.error("ICMP_PING_ERROR", e.message, null)
                        }
                    }
                }
                
                "batchTcpPing" -> {
                    val servers = call.argument<List<String>>("servers") ?: emptyList()
                    val timeout = call.argument<Int>("timeout") ?: 1000
                    
                    CoroutineScope(Dispatchers.Main).launch {
                        try {
                            val results = pingService.batchTcpPing(servers, timeout)
                            
                            // Convert results to JSON format for Flutter
                            val jsonResults = JSONObject()
                            results.forEach { (server, ping) ->
                                jsonResults.put(server, ping)
                            }
                            
                            result.success(jsonResults.toString())
                        } catch (e: Exception) {
                            result.error("BATCH_TCP_PING_ERROR", e.message, null)
                        }
                    }
                }
                
                "batchIcmpPing" -> {
                    val servers = call.argument<List<String>>("servers") ?: emptyList()
                    val timeout = call.argument<Int>("timeout") ?: 2000
                    
                    CoroutineScope(Dispatchers.Main).launch {
                        try {
                            val results = pingService.batchIcmpPing(servers, timeout)
                            
                            // Convert results to JSON format for Flutter
                            val jsonResults = JSONObject()
                            results.forEach { (server, ping) ->
                                jsonResults.put(server, ping)
                            }
                            
                            result.success(jsonResults.toString())
                        } catch (e: Exception) {
                            result.error("BATCH_ICMP_PING_ERROR", e.message, null)
                        }
                    }
                }
                
                "smartPing" -> {
                    val host = call.argument<String>("host") ?: ""
                    val port = call.argument<Int>("port") ?: 80
                    val timeout = call.argument<Int>("timeout") ?: 1000
                    
                    CoroutineScope(Dispatchers.Main).launch {
                        try {
                            val pingResult = pingService.smartPing(host, port, timeout)
                            
                            // Convert to JSON for Flutter
                            val jsonResult = JSONObject().apply {
                                put("time", pingResult.time)
                                put("method", pingResult.method.name)
                                put("success", pingResult.success)
                            }
                            
                            result.success(jsonResult.toString())
                        } catch (e: Exception) {
                            result.error("SMART_PING_ERROR", e.message, null)
                        }
                    }
                }
                
                else -> result.notImplemented()
            }
        }
    }
    
    override fun onDestroy() {
        super.onDestroy()
        if (::pingService.isInitialized) {
            pingService.shutdown()
        }
    }
}
