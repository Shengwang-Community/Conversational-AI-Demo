package io.agora.agent

import android.content.Intent
import android.os.Build
import android.os.Bundle
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import io.agora.agent.databinding.WelcomeActivityBinding
import io.agora.scene.common.constant.AgentScenes
import io.agora.scene.common.ui.BaseActivity
import io.agora.scene.common.util.toast.ToastUtil
import io.agora.scene.convoai.ui.CovLivingActivity
import androidx.annotation.RequiresApi


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

    override fun immersiveMode(): ImmersiveMode {
        return ImmersiveMode.FULLY_IMMERSIVE
    }

    override fun initView() {
    }

    private fun goScene() {
        startActivity(Intent(this, CovLivingActivity::class.java))
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