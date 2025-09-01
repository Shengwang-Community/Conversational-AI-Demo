package io.agora.agent

import android.content.Intent
import android.os.Build
import android.os.Bundle
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import io.agora.agent.databinding.WelcomeActivityBinding
import io.agora.scene.common.ui.BaseActivity
import androidx.annotation.RequiresApi
import io.agora.scene.common.constant.SSOUserManager
import io.agora.scene.convoai.ui.CovLoginActivity
import io.agora.scene.convoai.ui.CovMainActivity

class WelcomeActivity : BaseActivity<WelcomeActivityBinding>() {

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

    override fun immersiveMode(): ImmersiveMode  = ImmersiveMode.FULLY_IMMERSIVE

    override fun supportOnBackPressed(): Boolean = false

    override fun initView() {
    }

    private fun goScene() {
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
    private fun handleSplashScreenExit() {
        val splashScreen = installSplashScreen()
        var keepSplashOnScreen = true

        splashScreen.setOnExitAnimationListener { provider ->
            provider.iconView.animate()
                .alpha(0f)
                .setDuration(300L)
                .scaleX(1f)
                .scaleY(1f)
                .withEndAction {
                    provider.remove()
                    goScene()
                }.start()
        }

        val handler = android.os.Handler(mainLooper)
        handler.postDelayed({
            keepSplashOnScreen = false
        }, SPLASH_DURATION)

        splashScreen.setKeepOnScreenCondition { keepSplashOnScreen }
    }
}