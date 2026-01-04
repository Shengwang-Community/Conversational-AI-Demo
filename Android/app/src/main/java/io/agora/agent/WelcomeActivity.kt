package io.agora.agent

import android.content.Intent
import android.os.Build
import android.os.Bundle
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import io.agora.agent.databinding.WelcomeActivityBinding
import io.agora.scene.common.ui.BaseActivity
import androidx.annotation.RequiresApi
import io.agora.scene.common.constant.SSOUserManager
import io.agora.scene.convoai.ui.auth.CovLoginActivity
import io.agora.scene.convoai.ui.main.CovMainActivity

class WelcomeActivity : BaseActivity<WelcomeActivityBinding>() {

    private var hasNavigated = false

    override fun getViewBinding(): WelcomeActivityBinding {
        return WelcomeActivityBinding.inflate(layoutInflater)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        // Android S+: installSplashScreen() must be called before super.onCreate()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val splashScreen = installSplashScreen()
            handleSplashScreenExit(splashScreen)
        }

        super.onCreate(savedInstanceState)

        // Android < S: Navigate after super.onCreate() to ensure Activity is fully initialized
        // This ensures Context is available and follows Android lifecycle best practices
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            goScene()
        }
    }

    override fun immersiveMode(): ImmersiveMode  = ImmersiveMode.FULLY_IMMERSIVE

    override fun supportOnBackPressed(): Boolean = false

    override fun initView() {
    }

    private fun goScene() {
        if (hasNavigated) return
        hasNavigated = true

        if (SSOUserManager.getToken().isNotEmpty()) {
            initBugly()
            startActivity(Intent(this@WelcomeActivity, CovMainActivity::class.java))
        } else {
            startActivity(Intent(this, CovLoginActivity::class.java))
        }
        finish()
    }

    private val SPLASH_DURATION = 300L

    @RequiresApi(Build.VERSION_CODES.S)
    private fun handleSplashScreenExit(splashScreen: androidx.core.splashscreen.SplashScreen) {
        var keepSplashOnScreen = true

        splashScreen.setOnExitAnimationListener { provider ->
            provider.iconView.animate()
                .alpha(0f)
                .setDuration(300L)
                .scaleX(1f)
                .scaleY(1f)
                .withEndAction {
                    provider.remove()
                }.start()
        }

        // Set condition to keep splash screen visible
        splashScreen.setKeepOnScreenCondition { keepSplashOnScreen }

        // After delay, allow splash screen to exit and navigate directly
        val handler = android.os.Handler(mainLooper)
        handler.postDelayed({
            keepSplashOnScreen = false
            // Navigate directly here, don't rely on animation listener
            goScene()
        }, SPLASH_DURATION)
    }
}