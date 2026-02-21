package com.example.my_app

import android.content.ContentResolver
import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.ByteArrayOutputStream

class PointerResolverPlugin(
    private val flutterEngine: FlutterEngine,
    private val contentResolver: ContentResolver
) : MethodCallHandler {
    
    companion object {
        private const val CHANNEL = "pointer_resolver"
    }
    
    private val coroutineScope = CoroutineScope(Dispatchers.Main)
    
    init {
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(this)
    }
    
    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "loadBytesFromUri" -> loadBytesFromUri(call, result)
            "openInHostApp" -> openInHostApp(call, result)
            "isSourceAvailable" -> isSourceAvailable(call, result)
            "takePersistablePermission" -> takePersistablePermission(call, result)
            else -> result.notImplemented()
        }
    }
    
    private fun loadBytesFromUri(call: MethodCall, result: Result) {
        val uriString = call.argument<String>("uri")
        val maxBytes = call.argument<Int?>("maxBytes")
        
        if (uriString == null) {
            result.error("INVALID_ARGUMENT", "URI cannot be null", null)
            return
        }
        
        coroutineScope.launch {
            try {
                val bytes = withContext(Dispatchers.IO) {
                    loadBytesFromUriInternal(uriString, maxBytes)
                }
                result.success(bytes)
            } catch (e: Exception) {
                result.error("LOAD_ERROR", "Failed to load bytes: ${e.message}", null)
            }
        }
    }
    
    private fun openInHostApp(call: MethodCall, result: Result) {
        val uriString = call.argument<String>("uri")
        
        if (uriString == null) {
            result.error("INVALID_ARGUMENT", "URI cannot be null", null)
            return
        }
        
        try {
            val uri = Uri.parse(uriString)
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setData(uri)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            
            val context = flutterEngine.getActivity() ?: return
            context.startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("OPEN_ERROR", "Failed to open in host app: ${e.message}", null)
        }
    }
    
    private fun isSourceAvailable(call: MethodCall, result: Result) {
        val uriString = call.argument<String>("uri")
        
        if (uriString == null) {
            result.error("INVALID_ARGUMENT", "URI cannot be null", null)
            return
        }
        
        try {
            val uri = Uri.parse(uriString)
            val isAvailable = checkUriAvailability(uri)
            result.success(isAvailable)
        } catch (e: Exception) {
            result.success(false)
        }
    }
    
    private fun takePersistablePermission(call: MethodCall, result: Result) {
        val uriString = call.argument<String>("uri")
        
        if (uriString == null) {
            result.error("INVALID_ARGUMENT", "URI cannot be null", null)
            return
        }
        
        try {
            val uri = Uri.parse(uriString)
            contentResolver.takePersistableUriPermission(
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION
            )
            result.success(true)
        } catch (e: Exception) {
            result.error("PERMISSION_ERROR", "Failed to take persistable permission: ${e.message}", null)
        }
    }
    
    private fun loadBytesFromUriInternal(uriString: String, maxBytes: Int?): ByteArray? {
        return try {
            val uri = Uri.parse(uriString)
            contentResolver.openInputStream(uri)?.use { inputStream ->
                val outputStream = ByteArrayOutputStream()
                val buffer = ByteArray(8192)
                var totalRead = 0
                var bytesRead: Int
                
                while (inputStream.read(buffer).also { bytesRead = it } != -1) {
                    val bytesToWrite = if (maxBytes != null) {
                        minOf(bytesRead, maxBytes - totalRead)
                    } else {
                        bytesRead
                    }
                    
                    if (bytesToWrite <= 0) break
                    
                    outputStream.write(buffer, 0, bytesToWrite)
                    totalRead += bytesToWrite
                    
                    if (maxBytes != null && totalRead >= maxBytes) break
                }
                
                outputStream.toByteArray()
            }
        } catch (e: Exception) {
            println("Error loading bytes from URI $uriString: ${e.message}")
            null
        }
    }
    
    private fun checkUriAvailability(uri: Uri): Boolean {
        return try {
            when (uri.scheme) {
                "content" -> {
                    contentResolver.openInputStream(uri)?.use { 
                        true 
                    } ?: false
                }
                "file" -> {
                    val file = java.io.File(uri.path ?: return false)
                    file.exists() && file.canRead()
                }
                else -> false
            }
        } catch (e: Exception) {
            false
        }
    }
}