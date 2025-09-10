package com.example.my_app

import android.content.Context
import android.util.Log
import com.google.mediapipe.tasks.genai.llminference.LlmInference
import com.google.mediapipe.tasks.genai.llminference.LlmInferenceResult
import com.google.mediapipe.tasks.text.textembedder.TextEmbedder
import com.google.mediapipe.tasks.text.textembedder.TextEmbedderResult
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.nio.file.Files
import java.nio.file.Paths

class GemmaEdgeBridge(private val context: Context) : MethodChannel.MethodCallHandler {
    companion object {
        private const val CHANNEL = "lumara_native"
        private const val TAG = "GemmaEdgeBridge"
    }

    private var chatModel: LlmInference? = null
    private var vlmModel: LlmInference? = null
    private var embedder: TextEmbedder? = null

    fun registerWith(flutterEngine: FlutterEngine) {
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initChatModel" -> {
                val modelPath = call.argument<String>("modelPath")
                val temperature = call.argument<Double>("temperature")
                val topP = call.argument<Double>("topP")
                val repeatPenalty = call.argument<Double>("repeatPenalty")
                val maxTokens = call.argument<Int>("maxTokens")
                val contextLength = call.argument<Int>("contextLength")
                val randomSeed = call.argument<Int>("randomSeed")
                initChatModel(modelPath, temperature, topP, repeatPenalty, maxTokens, contextLength, randomSeed, result)
            }
            "gemmaText" -> {
                val prompt = call.argument<String>("prompt")
                generateText(prompt, result)
            }
            "initVlmModel" -> {
                val modelPath = call.argument<String>("modelPath")
                val temperature = call.argument<Double>("temperature")
                val topP = call.argument<Double>("topP")
                val maxTokens = call.argument<Int>("maxTokens")
                val randomSeed = call.argument<Int>("randomSeed")
                initVlmModel(modelPath, temperature, topP, maxTokens, randomSeed, result)
            }
            "gemmaVision" -> {
                val prompt = call.argument<String>("prompt")
                val imageJpeg = call.argument<ByteArray>("imageJpeg")
                generateVision(prompt, imageJpeg, result)
            }
            "initEmbedder" -> {
                val modelPath = call.argument<String>("modelPath")
                initEmbedder(modelPath, result)
            }
            "embedText" -> {
                val text = call.argument<String>("text")
                embedText(text, result)
            }
            "hasSufficientRam" -> {
                result.success(hasSufficientRam())
            }
            "getAvailableMemory" -> {
                result.success(getAvailableMemory())
            }
            "isModelReady" -> {
                val modelType = call.argument<String>("modelType")
                result.success(isModelReady(modelType))
            }
            "dispose" -> {
                dispose()
                result.success(null)
            }
            "areModelsAvailable" -> {
                result.success(areModelsAvailable())
            }
            "getModelInfo" -> {
                result.success(getModelInfo())
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun initChatModel(modelPath: String?, temperature: Double?, topP: Double?, repeatPenalty: Double?, maxTokens: Int?, contextLength: Int?, randomSeed: Int?, result: MethodChannel.Result) {
        try {
            if (modelPath == null) {
                result.success(false)
                return
            }

            // Handle assets:// paths by loading from assets folder
            val actualPath = if (modelPath.startsWith("assets/")) {
                modelPath.substring(7) // Remove "assets/" prefix
            } else {
                modelPath
            }

            // Try to load from assets first
            try {
                val builder = LlmInference.createFromAsset(context, actualPath)
                
                // Apply parameters
                temperature?.let { builder.setTemperature(it) }
                topP?.let { builder.setTopK(it.toInt()) }
                maxTokens?.let { builder.setMaxTokens(it) }

                chatModel = builder.build()
                Log.d(TAG, "Chat model initialized successfully from assets: $actualPath")
                result.success(true)
                return
            } catch (assetException: Exception) {
                Log.w(TAG, "Failed to load from assets: $assetException")
                
                // Fallback to file system
                val modelFile = File(context.filesDir, actualPath)
                if (!modelFile.exists()) {
                    Log.e(TAG, "Model file not found in assets or filesystem: $modelPath")
                    result.success(false)
                    return
                }

                val builder = LlmInference.createFromFile(context, modelFile.absolutePath)
            
                // Apply parameters
                temperature?.let { builder.setTemperature(it) }
                topP?.let { builder.setTopK(it.toInt()) }
                maxTokens?.let { builder.setMaxTokens(it) }

                chatModel = builder.build()
                Log.d(TAG, "Chat model initialized successfully from filesystem")
                result.success(true)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize chat model", e)
            result.success(false)
        }
    }

    private fun generateText(prompt: String?, result: MethodChannel.Result) {
        try {
            if (prompt == null || chatModel == null) {
                result.success("")
                return
            }

            val inferenceResult = chatModel!!.generateResponse(prompt)
            val response = inferenceResult.response
            Log.d(TAG, "Generated text: $response")
            result.success(response)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to generate text", e)
            result.success("")
        }
    }

    private fun initVlmModel(modelPath: String?, temperature: Double?, topP: Double?, maxTokens: Int?, randomSeed: Int?, result: MethodChannel.Result) {
        try {
            if (modelPath == null) {
                result.success(false)
                return
            }

            // Handle assets:// paths by loading from assets folder
            val actualPath = if (modelPath.startsWith("assets/")) {
                modelPath.substring(7) // Remove "assets/" prefix
            } else {
                modelPath
            }

            // Try to load from assets first
            try {
                val builder = LlmInference.createFromAsset(context, actualPath)
                
                // Apply parameters
                temperature?.let { builder.setTemperature(it) }
                topP?.let { builder.setTopK(it.toInt()) }
                maxTokens?.let { builder.setMaxTokens(it) }

                vlmModel = builder.build()
                Log.d(TAG, "VLM model initialized successfully from assets: $actualPath")
                result.success(true)
                return
            } catch (assetException: Exception) {
                Log.w(TAG, "Failed to load VLM from assets: $assetException")
                
                // Fallback to file system
                val modelFile = File(context.filesDir, actualPath)
                if (!modelFile.exists()) {
                    Log.e(TAG, "VLM model file not found in assets or filesystem: $modelPath")
                    result.success(false)
                    return
                }

                val builder = LlmInference.createFromFile(context, modelFile.absolutePath)
                
                // Apply parameters
                temperature?.let { builder.setTemperature(it) }
                topP?.let { builder.setTopK(it.toInt()) }
                maxTokens?.let { builder.setMaxTokens(it) }

                vlmModel = builder.build()
                Log.d(TAG, "VLM model initialized successfully from filesystem")
                result.success(true)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize VLM model", e)
            result.success(false)
        }
    }

    private fun generateVision(prompt: String?, imageJpeg: ByteArray?, result: MethodChannel.Result) {
        try {
            if (prompt == null || imageJpeg == null || vlmModel == null) {
                result.success("")
                return
            }

            // Convert JPEG bytes to image and generate response
            val inferenceResult = vlmModel!!.generateResponse(prompt, imageJpeg)
            val response = inferenceResult.response
            Log.d(TAG, "Generated vision response: $response")
            result.success(response)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to generate vision response", e)
            result.success("")
        }
    }

    private fun initEmbedder(modelPath: String?, result: MethodChannel.Result) {
        try {
            if (modelPath == null) {
                result.success(false)
                return
            }

            // Handle assets:// paths by loading from assets folder
            val actualPath = if (modelPath.startsWith("assets/")) {
                modelPath.substring(7) // Remove "assets/" prefix
            } else {
                modelPath
            }

            // Try to load from assets first
            try {
                val options = TextEmbedder.TextEmbedderOptions.builder()
                    .setBaseOptions(TextEmbedder.BaseOptions.builder()
                        .setModelAssetPath(actualPath)
                        .build())
                    .build()

                embedder = TextEmbedder.createFromOptions(context, options)
                Log.d(TAG, "Embedder initialized successfully from assets: $actualPath")
                result.success(true)
                return
            } catch (assetException: Exception) {
                Log.w(TAG, "Failed to load embedder from assets: $assetException")
                
                // Fallback to file system
                val modelFile = File(context.filesDir, actualPath)
                if (!modelFile.exists()) {
                    Log.e(TAG, "Embedder model file not found in assets or filesystem: $modelPath")
                    result.success(false)
                    return
                }

                val options = TextEmbedder.TextEmbedderOptions.builder()
                    .setBaseOptions(TextEmbedder.BaseOptions.builder()
                        .setModelAssetPath(modelFile.absolutePath)
                        .build())
                    .build()

                embedder = TextEmbedder.createFromOptions(context, options)
                Log.d(TAG, "Embedder initialized successfully from filesystem")
                result.success(true)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize embedder", e)
            result.success(false)
        }
    }

    private fun embedText(text: String?, result: MethodChannel.Result) {
        try {
            if (text == null || embedder == null) {
                result.success(emptyList<Double>())
                return
            }

            val embedderResult = embedder!!.embed(text)
            val embeddings = embedderResult.embeddingResult.embeddings[0].floatEmbedding
            Log.d(TAG, "Generated embeddings: ${embeddings.size} dimensions")
            result.success(embeddings.toList())
        } catch (e: Exception) {
            Log.e(TAG, "Failed to generate embeddings", e)
            result.success(emptyList<Double>())
        }
    }

    private fun areModelsAvailable(): Boolean {
        return chatModel != null || vlmModel != null || embedder != null
    }

    private fun getModelInfo(): Map<String, Any> {
        val info = mutableMapOf<String, Any>()
        info["chatModelAvailable"] = chatModel != null
        info["vlmModelAvailable"] = vlmModel != null
        info["embedderAvailable"] = embedder != null
        return info
    }

    private fun hasSufficientRam(): Boolean {
        val runtime = Runtime.getRuntime()
        val maxMemory = runtime.maxMemory() / (1024 * 1024) // Convert to MB
        return maxMemory >= 4000 // 4GB minimum for 4B model
    }

    private fun getAvailableMemory(): Int {
        val runtime = Runtime.getRuntime()
        val maxMemory = runtime.maxMemory() / (1024 * 1024) // Convert to MB
        return maxMemory.toInt()
    }

    private fun isModelReady(modelType: String?): Boolean {
        return when (modelType) {
            "chat" -> chatModel != null
            "vlm" -> vlmModel != null
            "embedder" -> embedder != null
            else -> false
        }
    }

    private fun dispose() {
        chatModel = null
        vlmModel = null
        embedder = null
    }
}
