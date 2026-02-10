package io.agora.agent

import android.content.Intent
import android.os.Build
import android.os.Bundle
import androidx.annotation.RequiresApi
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import androidx.lifecycle.lifecycleScope
import io.agora.agent.databinding.WelcomeActivityBinding
import io.agora.scene.common.constant.SSOUserManager
import io.agora.scene.common.ui.BaseActivity
import io.agora.scene.convoai.ui.auth.CovLoginActivity
import io.agora.scene.convoai.ui.main.CovMainActivity
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

class WelcomeActivity : BaseActivity<WelcomeActivityBinding>() {

    companion object {
        private const val SPLASH_DURATION = 300L
        private const val SPLASH_TIMEOUT = 800L
    }

    private var hasNavigated = false

    override fun getViewBinding(): WelcomeActivityBinding {
        return WelcomeActivityBinding.inflate(layoutInflater)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            handleSplashScreenExit()
        } else {
            goScene()
        }
        super.onCreate(savedInstanceState)
    }

    override fun immersiveMode(): ImmersiveMode = ImmersiveMode.FULLY_IMMERSIVE

    override fun supportOnBackPressed(): Boolean = false

    override fun initView() {}

    private fun goScene() {
        if (hasNavigated) return
        hasNavigated = true
        
        if (SSOUserManager.getToken().isNotEmpty()) {
            initBugly()
            startActivity(Intent(this, CovMainActivity::class.java))
        } else {
            startActivity(Intent(this, CovLoginActivity::class.java))
        }
        finish()
    }

    @RequiresApi(Build.VERSION_CODES.S)
    private fun handleSplashScreenExit() {
        val splashScreen = installSplashScreen()
        var keepSplashOnScreen = true

        splashScreen.setOnExitAnimationListener { provider ->
            provider.iconView.animate()
                .alpha(0f)
                .setDuration(SPLASH_DURATION)
                .scaleX(1f)
                .scaleY(1f)
                .withEndAction {
                    provider.remove()
                    goScene()
                }.start()
        }

        lifecycleScope.launch {
            delay(SPLASH_DURATION)
            keepSplashOnScreen = false
            // Timeout fallback: ensure navigation if animation callback doesn't trigger
            delay(SPLASH_TIMEOUT - SPLASH_DURATION)
            goScene()
        }

        splashScreen.setKeepOnScreenCondition { keepSplashOnScreen }
    }
}