package io.agora.scene.common.net.interceptor

import io.agora.scene.common.BuildConfig
import io.agora.scene.common.util.CommonLogger
import okhttp3.Interceptor
import okhttp3.Request
import okhttp3.Response
import okhttp3.HttpUrl
import okio.Buffer
import org.json.JSONArray
import org.json.JSONObject
import java.nio.charset.Charset
import java.util.concurrent.TimeUnit

class HttpLogger : Interceptor {
    companion object {
        private val SENSITIVE_HEADERS = setOf(
            "auth",
            "token",
            "cert",
            "secret",
            "appId",
            "app_id"
        )

        private val SENSITIVE_PARAMS = setOf(
            "auth",
            "token",
            "password",
            "cert",
            "secret",
            "phone",
            "appId",
            "app_id"
        )

        // Excluded API paths
        private val EXCLUDE_PATHS = setOf(
            "/heartbeat",  // Heartbeat API
            "/ping"       // Ping API
        )

        // Excluded Content-Types
        private val EXCLUDE_CONTENT_TYPES = setOf(
            "multipart/form-data",    // File upload
            "application/octet-stream", // Binary stream
            "image/*",
            "file",
            "audio/*",                // Audio files
            "video/*"                 // Video files
        )
        
        // Paths containing these keywords will also be checked for content type exclusion
        private val SENSITIVE_PATH_KEYWORDS = setOf(
            "upload",
            "file",
            "media"
        )
    }

    override fun intercept(chain: Interceptor.Chain): Response {
        val request = chain.request()
        val url = request.url
        val requestId = java.util.UUID.randomUUID().toString().substring(0, 8)

        // Check if should completely skip logging or only log results
        val shouldSkipCompletely = shouldSkipLoggingCompletely(request)
        val logResultOnly = shouldLogResultOnly(request)
        
        // If not completely skipped and not only logging results, log the request
        if (!shouldSkipCompletely && !logResultOnly) {
            val logContent = buildLogContent(request)
            CommonLogger.d("[$requestId]-Request", logContent)
        } else if (logResultOnly) {
            CommonLogger.d("[$requestId]-Request", "Large file upload request: ${request.method} ${request.url}")
        }

        // Execute request
        val startNs = System.nanoTime()
        val response = chain.proceed(request)
        
        // If not completely skipping logging, log the response
        if (!shouldSkipCompletely) {
            logResponse(response, startNs, url, requestId)
        }

        return response
    }

    private fun buildLogContent(request: Request): String {
        val logContent = StringBuilder()

        // Start request info
        logContent.append("curl -X ${request.method}")

        // Add headers
        val headers = mutableListOf<Pair<String, String>>()
        request.body?.contentType()?.let { contentType ->
            headers.add("Content-Type" to contentType.toString())
        }
        request.headers.forEach { (name, value) ->
            if (name.lowercase() != "content-type") {
                headers.add(name to value)
            }
        }

        if (headers.isNotEmpty()) {
            logContent.append(" -H \"")
            headers.forEachIndexed { index, (name, value) ->
                if (index > 0) {
                    logContent.append(";")
                }
                val safeValue = if (!BuildConfig.DEBUG && SENSITIVE_HEADERS.any { name.lowercase().contains(it) }) "***" else value
                logContent.append("$name:$safeValue")
            }
            logContent.append("\"")
        }

        // Add request body
        request.body?.let { body ->
            val buffer = Buffer()
            body.writeTo(buffer)
            val charset = body.contentType()?.charset() ?: Charset.defaultCharset()
            var bodyString = buffer.readString(charset)
            
            if (!BuildConfig.DEBUG) {
                SENSITIVE_PARAMS.forEach { param ->
                    bodyString = bodyString.replace(
                        Regex(""""([^"]*$param[^"]*)"\s*:\s*"([^"]*)""", RegexOption.IGNORE_CASE),
                        """"$1":"***"""
                    )
                }
            }
            
            // Format JSON body
            val formattedBody = formatJsonString(bodyString)
            logContent.append(" -d '${formattedBody}'")
        }

        // Add URL
        val urlString = if (BuildConfig.DEBUG) {
            buildUrlString(request.url)
        } else {
            buildMaskedUrlString(request.url)
        }
        logContent.append(" \"$urlString\"")

        return logContent.toString()
    }

    private fun formatJsonString(input: String): String {
        return try {
            if (input.trim().startsWith("{")) {
                JSONObject(input).toString(4)
            } else if (input.trim().startsWith("[")) {
                JSONArray(input).toString(4)
            } else {
                input
            }
        } catch (e: Exception) {
            input
        }
    }

    private fun buildUrlString(url: HttpUrl): String {
        return buildString {
            append(url.scheme).append("://").append(url.host)
            if (url.port != 80 && url.port != 443) {
                append(":").append(url.port)
            }
            append(url.encodedPath)
            
            if (url.queryParameterNames.isNotEmpty()) {
                append("?")
                url.queryParameterNames.forEachIndexed { index, name ->
                    if (index > 0) append("&")
                    val value = url.queryParameter(name)
                    append("$name=$value")
                }
            }
        }
    }

    private fun buildMaskedUrlString(url: HttpUrl): String {
        return buildString {
            append(url.scheme).append("://").append(url.host)
            if (url.port != 80 && url.port != 443) {
                append(":").append(url.port)
            }
            append(url.encodedPath)
            
            if (url.queryParameterNames.isNotEmpty()) {
                append("?")
                url.queryParameterNames.forEachIndexed { index, name ->
                    if (index > 0) append("&")
                    val value = url.queryParameter(name)
                    val safeValue = if (SENSITIVE_PARAMS.any { name.lowercase().contains(it) }) "***" else value
                    append("$name=$safeValue")
                }
            }
        }
    }

    // Determine if logging should be completely skipped
    private fun shouldSkipLoggingCompletely(request: Request): Boolean {
        return EXCLUDE_PATHS.any { path -> request.url.encodedPath.contains(path) }
    }

    // Determine if only results should be logged without request body
    private fun shouldLogResultOnly(request: Request): Boolean {
        val path = request.url.encodedPath.lowercase()
        if (SENSITIVE_PATH_KEYWORDS.any { keyword -> path.contains(keyword) }) {
            request.body?.let { body ->
                if (body.contentLength() > 1024 * 1024) {
                    return true
                }
            }
        }
        
        request.body?.contentType()?.let { contentType ->
            val contentTypeString = contentType.toString()
            if (EXCLUDE_CONTENT_TYPES.any { type ->
                    if (type.endsWith("/*")) {
                        contentTypeString.startsWith(type.removeSuffix("/*"))
                    } else {
                        contentTypeString == type
                    }
                }) {
                return true
            }
        }
        
        return false
    }

    private fun logResponse(response: Response, startNs: Long, url: HttpUrl, requestId: String) {
        val tookMs = TimeUnit.NANOSECONDS.toMillis(System.nanoTime() - startNs)
        val responseBody = response.body ?: return
        val contentLength = responseBody.contentLength()
        val bodySize = if (contentLength != -1L) "$contentLength-byte" else "unknown-length"

        val logContent = buildString {
            append("${response.code} ${response.message} for ${if (BuildConfig.DEBUG) buildUrlString(url) else buildMaskedUrlString(url)}")
            append(" (${tookMs}ms")
            if (response.networkResponse != null && response.networkResponse != response) {
                append(", ${bodySize} body")
            }
            append(")")

            response.headers.forEach { (name, value) ->
                val safeValue = if (!BuildConfig.DEBUG && SENSITIVE_HEADERS.any { name.lowercase().contains(it) }) "***" else value
                append("\n$name: $safeValue")
            }

            responseBody.let { body ->
                val contentType = body.contentType()
                if (contentType?.type == "application" &&
                    (contentType.subtype.contains("json") || contentType.subtype.contains("xml"))
                ) {
                    val source = body.source()
                    source.request(Long.MAX_VALUE)
                    val buffer = source.buffer
                    val charset = contentType.charset() ?: Charset.defaultCharset()
                    if (contentLength != 0L) {
                        append("\n\n")
                        var bodyString = buffer.clone().readString(charset)
                        if (!BuildConfig.DEBUG) {
                            SENSITIVE_PARAMS.forEach { param ->
                                bodyString = bodyString.replace(
                                    Regex(""""([^"]*$param[^"]*)"\s*:\s*"([^"]*)""", RegexOption.IGNORE_CASE),
                                    """"$1":"***"""
                                )
                            }
                        }
                        append(formatJsonString(bodyString))
                    }
                }
            }
        }

        CommonLogger.d("[$requestId]-Response", logContent)
    }
} 