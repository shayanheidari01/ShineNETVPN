package com.shythonx.shinenet_vpn

import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.VpnService
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import org.json.JSONObject
import java.io.File

class MainActivity: FlutterActivity() {
    private val PING_CHANNEL = "com.shythonx.shinenet_vpn/native_ping"
    private val AETHER_CHANNEL = "com.shythonx.shinenet_vpn/aether"
    private val AETHER_STATUS_CHANNEL = "com.shythonx.shinenet_vpn/aether_status"
    private lateinit var pingService: NativePingService
    private var aetherStatusSink: EventChannel.EventSink? = null
    private var receiverRegistered = false
    private var pendingVpnResult: MethodChannel.Result? = null
    private var pendingAetherConfig: String? = null

    private val aetherStatusReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            when (intent.getStringExtra(AetherVpnService.EXTRA_STATUS)) {
                AetherVpnService.STATUS_CONNECTING -> {
                    aetherStatusSink?.success(mapOf("status" to "connecting"))
                }
                AetherVpnService.STATUS_CONNECTED -> {
                    aetherStatusSink?.success(mapOf("status" to "connected"))
                }
                AetherVpnService.STATUS_FAILED -> {
                    val detail = intent.getStringExtra(AetherVpnService.EXTRA_DETAIL) ?: "Unknown error"
                    aetherStatusSink?.success(mapOf("status" to "failed", "detail" to detail))
                }
                AetherVpnService.STATUS_DISCONNECTED -> {
                    aetherStatusSink?.success(mapOf("status" to "disconnected"))
                }
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        pingService = NativePingService()

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            AETHER_STATUS_CHANNEL,
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                aetherStatusSink = events
            }

            override fun onCancel(arguments: Any?) {
                aetherStatusSink = null
            }
        })

        // Ping channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PING_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "tcpPing" -> {
                    val host = call.argument<String>("host") ?: ""
                    val port = call.argument<Int>("port") ?: 80
                    val timeout = call.argument<Int>("timeout") ?: 1000
                    CoroutineScope(Dispatchers.Main).launch {
                        try {
                            result.success(pingService.tcpPing(host, port, timeout))
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
                            result.success(pingService.icmpPing(host, timeout, count))
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
                            val jsonResults = JSONObject()
                            results.forEach { (server, ping) -> jsonResults.put(server, ping) }
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
                            val jsonResults = JSONObject()
                            results.forEach { (server, ping) -> jsonResults.put(server, ping) }
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

        // Aether channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AETHER_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkNativeLibs" -> {
                    try {
                        val aetherLib = try { System.loadLibrary("aether"); true } catch (e: UnsatisfiedLinkError) { false }
                        val jniLib = try { System.loadLibrary("aether_jni"); true } catch (e: UnsatisfiedLinkError) { false }
                        result.success(mapOf("aetherLoaded" to aetherLib, "jniLoaded" to jniLib))
                    } catch (e: Exception) {
                        result.success(mapOf("aetherLoaded" to false, "jniLoaded" to false))
                    }
                }

                "requestVpnPermission" -> {
                    val permissionIntent = VpnService.prepare(this@MainActivity)
                    if (permissionIntent == null) {
                        // Already granted
                        result.success(true)
                    } else {
                        // Need to request permission via activity result
                        pendingVpnResult = result
                        startActivityForResult(permissionIntent, VPN_REQUEST_CODE)
                    }
                }

                "startAether" -> {
                    val protocol = call.argument<String>("protocol") ?: "masque"
                    val scanMode = call.argument<String>("scanMode") ?: "turbo"
                    val ipScan = call.argument<String>("ipScan") ?: "v4"
                    val obfuscation = call.argument<String>("obfuscation") ?: "firewall"
                    // transport is accepted from Flutter for future .so builds, but must NOT be
                    // serialized into the native JSON: the currently shipped libaether.so uses
                    // deny_unknown_fields and rejects `transport`.
                    val socksPort = call.argument<Int>("socksPort") ?: 1819
                    val normalizedProtocol = protocol.trim().lowercase()

                    try {
                        val configFile = File(filesDir, "aether.toml")

                        val config = JSONObject().apply {
                            put("config_path", configFile.absolutePath)
                            put("protocol", normalizedProtocol)
                            put("listen", "127.0.0.1:$socksPort")
                            when (normalizedProtocol) {
                                "wireguard", "wg", "gool", "wiw", "warp-in-warp", "warpinwarp" -> {
                                    put("wireguard_config_path", configFile.absolutePath)
                                }
                                else -> {
                                    put("masque_config_path", configFile.absolutePath)
                                }
                            }
                            put("scan_mode", scanMode)
                            put("ip_scan", ipScan)
                            put("obfuscation_profile", obfuscation)
                            put("retry_obfuscation_profiles", true)
                        }.toString()

                        startForegroundService(Intent(this, AetherVpnService::class.java)
                            .setAction(AetherVpnService.ACTION_CONNECT)
                            .putExtra(AetherVpnService.EXTRA_CONFIG, config))

                        result.success(true)
                    } catch (e: Exception) {
                        result.error("AETHER_START_ERROR", e.message, null)
                    }
                }

                "stopAether" -> {
                    try {
                        startService(Intent(this, AetherVpnService::class.java)
                            .setAction(AetherVpnService.ACTION_DISCONNECT))
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("AETHER_STOP_ERROR", e.message, null)
                    }
                }

                "isRunning" -> {
                    try { result.success(AetherNativeCore.isRunning()) } catch (e: Exception) { result.success(false) }
                }

                "isReady" -> {
                    try { result.success(AetherNativeCore.isReady()) } catch (e: Exception) { result.success(false) }
                }

                "getLastLog" -> {
                    try {
                        val nativeLog = AetherNativeCore.lastLog()
                        val serviceLog = ConnectionLog.snapshot().joinToString("\n")
                        val combined = if (serviceLog.isNotEmpty() && nativeLog.isNotEmpty()) "$serviceLog\n$nativeLog" else serviceLog.ifEmpty { nativeLog }
                        result.success(combined)
                    } catch (e: Exception) { result.success("") }
                }

                "getLastError" -> {
                    try { result.success(AetherNativeCore.lastError()) } catch (e: Exception) { result.success("") }
                }

                else -> result.notImplemented()
            }
        }

    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == VPN_REQUEST_CODE) {
            val granted = resultCode == Activity.RESULT_OK
            pendingVpnResult?.success(granted)
            pendingVpnResult = null
        }
    }

    override fun onStart() {
        super.onStart()
        val filter = IntentFilter(AetherVpnService.ACTION_STATUS)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(aetherStatusReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("DEPRECATION")
            registerReceiver(aetherStatusReceiver, filter)
        }
        receiverRegistered = true

    }

    override fun onStop() {
        if (receiverRegistered) {
            unregisterReceiver(aetherStatusReceiver)
            receiverRegistered = false
        }
        super.onStop()
    }

    override fun onDestroy() {
        super.onDestroy()
        if (::pingService.isInitialized) {
            pingService.shutdown()
        }
    }

    companion object {
        const val EXTRA_OPEN_DISCONNECT = "open_disconnect"
        private const val VPN_REQUEST_CODE = 1001
    }
}
