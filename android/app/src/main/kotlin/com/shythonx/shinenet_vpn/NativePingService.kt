package com.shythonx.shinenet_vpn

import android.content.Context
import kotlinx.coroutines.*
import java.io.IOException
import java.net.*
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import kotlin.coroutines.CoroutineContext

/**
 * High-performance native Kotlin ping service supporting both TCP and ICMP ping
 * Replaces Flutter V2Ray implementation for better performance and reliability
 */
class NativePingService : CoroutineScope {
    
    companion object {
        private const val DEFAULT_TCP_TIMEOUT = 1000 // 1 second
        private const val DEFAULT_ICMP_TIMEOUT = 2000 // 2 seconds
        private const val DEFAULT_TCP_PORT = 80
        private const val MAX_CONCURRENT_PINGS = 50
        private const val ICMP_PACKET_SIZE = 32
    }
    
    private val job = SupervisorJob()
    override val coroutineContext: CoroutineContext = Dispatchers.IO + job
    
    private val executor = Executors.newFixedThreadPool(MAX_CONCURRENT_PINGS)
    
    /**
     * Perform ultra-fast TCP ping to check server reachability
     * @param host Target hostname or IP address
     * @param port Target port (default: 80)
     * @param timeoutMs Timeout in milliseconds (default: 1000ms)
     * @return Ping time in milliseconds, -1 for failure, -2 for timeout
     */
    suspend fun tcpPing(host: String, port: Int = DEFAULT_TCP_PORT, timeoutMs: Int = DEFAULT_TCP_TIMEOUT): Int {
        return withContext(Dispatchers.IO) {
            val startTime = System.currentTimeMillis()
            var socket: Socket? = null
            
            try {
                // Validate host format
                if (host.isBlank() || port <= 0 || port > 65535) {
                    return@withContext -1
                }
                
                // Create socket with timeout
                socket = Socket()
                socket.soTimeout = timeoutMs
                socket.tcpNoDelay = true
                
                // Attempt connection
                val address = InetSocketAddress(host, port)
                socket.connect(address, timeoutMs)
                
                val endTime = System.currentTimeMillis()
                val pingTime = (endTime - startTime).toInt()
                
                return@withContext if (pingTime <= timeoutMs) pingTime else -2
                
            } catch (e: SocketTimeoutException) {
                return@withContext -2 // Timeout
            } catch (e: ConnectException) {
                return@withContext -1 // Connection refused
            } catch (e: UnknownHostException) {
                return@withContext -1 // Host not found
            } catch (e: IOException) {
                return@withContext -1 // Other network error
            } finally {
                try {
                    socket?.close()
                } catch (ignored: IOException) {}
            }
        }
    }
    
    /**
     * Perform ICMP ping using system ping command
     * @param host Target hostname or IP address
     * @param timeoutMs Timeout in milliseconds (default: 2000ms)
     * @param packetCount Number of ping packets (default: 1)
     * @return Average ping time in milliseconds, -1 for failure, -2 for timeout
     */
    suspend fun icmpPing(host: String, timeoutMs: Int = DEFAULT_ICMP_TIMEOUT, packetCount: Int = 1): Int {
        return withContext(Dispatchers.IO) {
            try {
                // Validate input
                if (host.isBlank()) return@withContext -1
                
                val timeoutSeconds = (timeoutMs / 1000).coerceAtLeast(1)
                
                // Build ping command for Android
                val command = arrayOf(
                    "ping",
                    "-c", packetCount.toString(),
                    "-w", timeoutSeconds.toString(),
                    "-s", ICMP_PACKET_SIZE.toString(),
                    host
                )
                
                val process = ProcessBuilder(*command)
                    .redirectErrorStream(true)
                    .start()
                
                // Wait for process completion with timeout
                val completed = process.waitFor(timeoutMs.toLong(), TimeUnit.MILLISECONDS)
                
                if (!completed) {
                    process.destroyForcibly()
                    return@withContext -2 // Timeout
                }
                
                if (process.exitValue() != 0) {
                    return@withContext -1 // Ping failed
                }
                
                // Parse ping output to extract average time
                val output = process.inputStream.bufferedReader().readText()
                return@withContext parsePingOutput(output)
                
            } catch (e: Exception) {
                return@withContext -1
            }
        }
    }
    
    /**
     * Perform concurrent TCP ping on multiple servers
     * @param servers List of host:port pairs
     * @param timeoutMs Timeout per ping in milliseconds
     * @return Map of server to ping result
     */
    suspend fun batchTcpPing(servers: List<String>, timeoutMs: Int = DEFAULT_TCP_TIMEOUT): Map<String, Int> {
        return withContext(Dispatchers.IO) {
            val results = mutableMapOf<String, Int>()
            
            // Process servers in batches to prevent resource exhaustion
            servers.chunked(MAX_CONCURRENT_PINGS).forEach { batch ->
                val jobs = batch.map { server ->
                    async {
                        val (host, port) = parseServerString(server)
                        val result = tcpPing(host, port, timeoutMs)
                        server to result
                    }
                }
                
                // Wait for all jobs in current batch
                jobs.awaitAll().forEach { (server, result) ->
                    results[server] = result
                }
                
                // Small delay between batches
                if (batch.size == MAX_CONCURRENT_PINGS) {
                    delay(10)
                }
            }
            
            results
        }
    }
    
    /**
     * Perform concurrent ICMP ping on multiple servers
     * @param servers List of hostnames or IP addresses
     * @param timeoutMs Timeout per ping in milliseconds
     * @return Map of server to ping result
     */
    suspend fun batchIcmpPing(servers: List<String>, timeoutMs: Int = DEFAULT_ICMP_TIMEOUT): Map<String, Int> {
        return withContext(Dispatchers.IO) {
            val results = mutableMapOf<String, Int>()
            
            // ICMP requires sequential execution to avoid overwhelming the system
            servers.forEach { server ->
                val result = icmpPing(server, timeoutMs)
                results[server] = result
                
                // Small delay between ICMP pings
                delay(50)
            }
            
            results
        }
    }
    
    /**
     * Smart ping that tries TCP first, falls back to ICMP
     * @param host Target hostname
     * @param port TCP port to try (default: 80)
     * @param timeoutMs Timeout in milliseconds
     * @return Ping result with method indication
     */
    suspend fun smartPing(host: String, port: Int = DEFAULT_TCP_PORT, timeoutMs: Int = DEFAULT_TCP_TIMEOUT): PingResult {
        return withContext(Dispatchers.IO) {
            // Try TCP ping first (faster)
            val tcpResult = tcpPing(host, port, timeoutMs)
            
            if (tcpResult > 0) {
                return@withContext PingResult(tcpResult, PingMethod.TCP, true)
            }
            
            // Fallback to ICMP ping
            val icmpResult = icmpPing(host, timeoutMs * 2) // Give ICMP more time
            
            return@withContext PingResult(
                icmpResult,
                PingMethod.ICMP,
                icmpResult > 0
            )
        }
    }
    
    /**
     * Parse server string in format "host:port" or just "host"
     */
    private fun parseServerString(server: String): Pair<String, Int> {
        return if (server.contains(':')) {
            val parts = server.split(':')
            parts[0] to (parts.getOrNull(1)?.toIntOrNull() ?: DEFAULT_TCP_PORT)
        } else {
            server to DEFAULT_TCP_PORT
        }
    }
    
    /**
     * Parse ping command output to extract average time
     */
    private fun parsePingOutput(output: String): Int {
        try {
            // Look for patterns like "min/avg/max/mdev = 1.234/2.345/3.456/0.123 ms"
            val avgPattern = Regex("""min/avg/max/mdev = [\d.]+/([\d.]+)/[\d.]+/[\d.]+ ms""")
            val match = avgPattern.find(output)
            
            if (match != null) {
                val avgTime = match.groupValues[1].toFloat()
                return avgTime.toInt()
            }
            
            // Alternative pattern: "rtt min/avg/max/mdev = 1.234/2.345/3.456/0.123 ms"
            val rttPattern = Regex("""rtt min/avg/max/mdev = [\d.]+/([\d.]+)/[\d.]+/[\d.]+ ms""")
            val rttMatch = rttPattern.find(output)
            
            if (rttMatch != null) {
                val avgTime = rttMatch.groupValues[1].toFloat()
                return avgTime.toInt()
            }
            
            // Look for individual ping times if avg not found
            val timePattern = Regex("""time=([\d.]+) ms""")
            val times = timePattern.findAll(output).map { it.groupValues[1].toFloat() }.toList()
            
            if (times.isNotEmpty()) {
                return (times.average()).toInt()
            }
            
            return -1 // No valid time found
            
        } catch (e: Exception) {
            return -1
        }
    }
    
    /**
     * Clean up resources
     */
    fun shutdown() {
        job.cancel()
        executor.shutdown()
        try {
            if (!executor.awaitTermination(5, TimeUnit.SECONDS)) {
                executor.shutdownNow()
            }
        } catch (e: InterruptedException) {
            executor.shutdownNow()
        }
    }
}

/**
 * Data class representing ping result
 */
data class PingResult(
    val time: Int,
    val method: PingMethod,
    val success: Boolean
)

/**
 * Enum for ping methods
 */
enum class PingMethod {
    TCP, ICMP
}