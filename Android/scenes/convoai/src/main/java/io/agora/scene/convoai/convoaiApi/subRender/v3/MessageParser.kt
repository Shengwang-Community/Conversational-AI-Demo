package io.agora.scene.convoai.convoaiApi.subRender.v3

import com.google.gson.GsonBuilder
import com.google.gson.ToNumberPolicy
import com.google.gson.TypeAdapter
import com.google.gson.reflect.TypeToken
import com.google.gson.stream.JsonReader
import com.google.gson.stream.JsonWriter
import org.json.JSONObject
import java.io.IOException

class MessageParser {

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

    var onError: ((message: String) -> Unit)? = null

    /**
     * Parse JSON string directly to Map (for RTM messages)
     * @param jsonString JSON string to parse
     * @return Parsed Map or null if parsing fails
     */
    fun parseJsonToMap(jsonString: String): Map<String, Any>? {
        return try {
            gson.fromJson(jsonString, Map::class.java) as Map<String, Any>
        } catch (e: Exception) {
            onError?.invoke("[MessageParser] parseJsonToMap: ${e.message}")
            null
        }
    }
}