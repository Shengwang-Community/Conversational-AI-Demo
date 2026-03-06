package io.agora.scene.common.util

import android.annotation.SuppressLint
import android.app.Application
import android.content.Context
import android.content.res.Configuration
import android.os.Build
import androidx.appcompat.app.AppCompatDelegate
import androidx.core.os.LocaleListCompat
import java.util.Locale

/**
 * Manages application localization and language settings
 */
class LocaleManager private constructor(private val application: Application) {

    companion object {
        private const val PREFS_NAME = "locale_preferences"
        private const val KEY_LANGUAGE = "selected_language"
        private const val KEY_FOLLOW_SYSTEM = "follow_system_language"
        const val KEY_LOCAL_DEBUG = "local_debug"
        
        @Volatile
        private var instance: LocaleManager? = null
        
        fun init(application: Application) {
            if (instance == null) {
                synchronized(this) {
                    if (instance == null) {
                        instance = LocaleManager(application)
                    }
                }
            }
        }
        
        fun getInstance(): LocaleManager {
            return instance ?: throw IllegalStateException("LocaleManager not initialized")
        }
        
        /**
         * Wraps the context to ensure application locale is applied
         * Should be used in attachBaseContext() of activities and application
         */
        fun wrapContext(context: Context): Context {
            return getInstance().updateContextLocale(context, 
                getInstance().getLocaleFromPreferences(context))
        }
    }
    
    /**
     * Sets the application locale based on user preference or default setting
     * @param isMainland Whether the app is running in mainland China
     * @param forceRefresh Whether to refresh locale even if already set
     */
    fun setupLocale(context: Context, isMainland: Boolean, forceRefresh: Boolean = false) {
        // Get saved language or default based on region
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val savedLang = prefs.getString(KEY_LANGUAGE, null)
        val followSystem = prefs.getBoolean(KEY_FOLLOW_SYSTEM, false)
        
        // If following system, use system language
        if (followSystem) {
            val systemLocale = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                context.resources.configuration.locales.get(0)
            } else {
                @Suppress("DEPRECATION")
                context.resources.configuration.locale
            }
            
            // Update preference with system language
            prefs.edit().putString(KEY_LANGUAGE, systemLocale.language).apply()
            applyLocale(context, systemLocale)
            return
        }
        
        val lang = savedLang ?: if (isMainland) "zh" else "en"
        val locale = Locale(lang)
        
        // Save language preference if not already saved
        if (savedLang == null) {
            prefs.edit().putString(KEY_LANGUAGE, lang).apply()
        }
        
        applyLocale(context, locale)
    }
    
    /**
     * Apply locale to context and app delegate
     */
    private fun applyLocale(context: Context, locale: Locale) {
        // Set application-wide locale via AppCompatDelegate
        AppCompatDelegate.setApplicationLocales(LocaleListCompat.create(locale))
        
        // Set locale override flag to ensure system changes don't affect app
        AppCompatDelegate.setDefaultNightMode(AppCompatDelegate.MODE_NIGHT_FOLLOW_SYSTEM)

        // Update context configuration for backward compatibility
        updateContextLocale(context, locale)
        
        CommonLogger.d("LocaleManager", "Locale set to: ${locale.language}")
    }
    
    /**
     * Changes the application language
     * @param context Application context
     * @param language Language code ("en", "zh", etc.)
     * @param followSystem Whether to follow system language
     */
    fun setLanguage(context: Context, language: String, followSystem: Boolean = false) {
        // Save user selection
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_LANGUAGE, language)
            .putBoolean(KEY_FOLLOW_SYSTEM, followSystem)
            .apply()
        
        // If followSystem is true, this will be overridden in setupLocale
        val locale = Locale(language)
        applyLocale(context, locale)
    }
    
    /**
     * Gets the currently selected language code
     * @return The language code (e.g., "en", "zh")
     */
    fun getCurrentLanguage(context: Context): String {
        return context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getString(KEY_LANGUAGE, Locale.getDefault().language) ?: Locale.getDefault().language
    }
    
    /**
     * Checks if app is set to follow system language
     */
    fun isFollowingSystemLanguage(context: Context): Boolean {
        return context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getBoolean(KEY_FOLLOW_SYSTEM, false)
    }
    
    /**
     * Gets the locale from saved preferences
     */
    private fun getLocaleFromPreferences(context: Context): Locale {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val lang = prefs.getString(KEY_LANGUAGE, null) ?: "zh"
        return Locale(lang)
    }
    
    /**
     * Gets the debug mode state from saved preferences
     */
    fun getDebugMode(context: Context): Boolean {
        return context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getBoolean(KEY_LOCAL_DEBUG, false)
    }
    
    /**
     * Sets the debug mode state in preferences
     */
    fun setDebugMode(context: Context, isDebug: Boolean) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(KEY_LOCAL_DEBUG, isDebug)
            .apply()
    }
    
    /**
     * Updates the configuration of a specific context
     */
    @SuppressLint("ObsoleteSdkInt")
    private fun updateContextLocale(context: Context, locale: Locale): Context {
        Locale.setDefault(locale)
        
        val config = Configuration(context.resources.configuration)
        config.setLocale(locale)
        
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            context.createConfigurationContext(config)
        } else {
            @Suppress("DEPRECATION")
            context.resources.updateConfiguration(config, context.resources.displayMetrics)
            context
        }
    }
} 