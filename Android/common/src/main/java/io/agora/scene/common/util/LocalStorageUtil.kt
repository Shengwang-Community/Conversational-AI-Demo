package io.agora.scene.common.util

import android.os.Parcelable
import com.tencent.mmkv.MMKV

object LocalStorageUtil {

    val mmkv by lazy {
        MMKV.defaultMMKV()
    }

    fun putStringSet(key: String, set: Set<String>) {
        mmkv.putStringSet(key, set)
    }

    fun getStringSet(key: String): MutableSet<String>? {
        return mmkv.getStringSet(key, emptySet())
    }

    fun putBoolean(key: String, value: Boolean) {
        mmkv.putBoolean(key, value)
    }

    fun getBoolean(key: String, default: Boolean = false): Boolean {
        return mmkv.getBoolean(key, default)
    }

    fun putString(key: String, value: String) {
        mmkv.putString(key, value)
    }

    fun getString(key: String, default: String = ""): String {
        return mmkv.getString(key, default) ?: default
    }

    // Parcelable
    inline fun <reified T : Parcelable> putParcelable(key: String, obj: T) {
        mmkv.encode(key, obj)
    }

    //  Parcelable
    inline fun <reified T : Parcelable> getParcelable(key: String): T? {
        return mmkv.decodeParcelable(key, T::class.java)
    }

    //  Parcelable
    inline fun <reified T : Parcelable> getParcelable(key: String, defaultValue: T): T {
        return mmkv.decodeParcelable(key, T::class.java) ?: defaultValue
    }

    fun containsKey(key: String): Boolean {
        return mmkv.containsKey(key)
    }

    fun remove(key: String) {
        mmkv.removeValueForKey(key)
    }

    fun clear(){
        mmkv.clearAll()
    }
}