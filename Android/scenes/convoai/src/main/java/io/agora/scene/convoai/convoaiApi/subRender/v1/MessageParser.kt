package io.agora.scene.convoai.convoaiApi.subRender.v1

import com.google.gson.GsonBuilder
import com.google.gson.ToNumberPolicy
import com.google.gson.TypeAdapter
import com.google.gson.reflect.TypeToken
import com.google.gson.stream.JsonReader
import com.google.gson.stream.JsonWriter
import org.json.JSONObject
import java.io.IOException

class MessageParser {
    // Change message storage structure to Map<Int, String> for more intuitive partIndex and content storage
    private val messageMap = mutableMapOf<String, MutableMap<Int, String>>()
    private val gson = GsonBuilder()
        .setDateFormat("yyyy-MM-dd HH:mm:ss")
        .setObjectToNumberStrategy(ToNumberPolicy.LONG_OR_DOUBLE)
        .registerTypeAdapter(TypeToken.get(JSONObject::class.java).type, object : TypeAdapter<JSONObject>() {
            @Throws(IOException::class)
            override fun write(jsonWriter: JsonWriter, value: JSONObject) {
                jsonWriter.jsonValue(value.toString())
            }

            @Throws(IOException::class)
            override fun read(jsonReader: JsonReader): JSONObject? {
                return null
            }
        })
        .enableComplexMapKeySerialization()
        .create()
    private val maxMessageAge = 5 * 60 * 1000 // 5 minutes
    private val lastAccessMap = mutableMapOf<String, Long>()

    fun parseStreamMessage(string: String): Map<String, Any>? {
        try {
            // Clean up expired messages
            cleanExpiredMessages()

            val parts = string.split("|")
            if (parts.size != 4) {
                throw IllegalArgumentException("Invalid message format")
            }

            val messageId = parts[0]
            val partIndex = parts[1].toIntOrNull() ?: throw NumberFormatException("Invalid partIndex")
            val totalParts = parts[2].toIntOrNull() ?: throw NumberFormatException("Invalid totalParts")
            val base64Content = parts[3]

            // Validate partIndex and totalParts
            if (partIndex < 1 || partIndex > totalParts) {
                throw IllegalArgumentException("partIndex out of range")
            }

            // Update last access time
            lastAccessMap[messageId] = System.currentTimeMillis()

            // Use Map to store message parts for more intuitive partIndex and content management
            val messageParts = messageMap.getOrPut(messageId) { mutableMapOf() }
            messageParts[partIndex] = base64Content

            // Check if all parts are received
            if (messageParts.size == totalParts) {
                // All parts received, merge in order and decode
                val completeMessage = (1..totalParts).joinToString("") {
                    messageParts[it] ?: throw IllegalStateException("Missing part $it")
                }
                val decodedBytes = try {
                    android.util.Base64.decode(completeMessage, android.util.Base64.DEFAULT)
                } catch (e: IllegalArgumentException) {
                    throw IllegalArgumentException("Invalid Base64 content", e)
                }

                val jsonString = String(decodedBytes, Charsets.UTF_8)
                val result = try {
                    gson.fromJson(jsonString, Map::class.java) as Map<String, Any>
                } catch (e: Exception) {
                    throw IllegalArgumentException("Invalid JSON format", e)
                }

                // Clean up processed message
                messageMap.remove(messageId)
                lastAccessMap.remove(messageId)

                return result
            }
        } catch (e: Exception) {
            // Handle exception, can log or throw
            println("Error parsing message: ${e.message}")
        }
        return null
    }

    private fun cleanExpiredMessages() {
        val currentTime = System.currentTimeMillis()
        val expiredIds = lastAccessMap.filter { currentTime - it.value > maxMessageAge }.keys
        expiredIds.forEach {
            messageMap.remove(it)
            lastAccessMap.remove(it)
        }
    }
}
