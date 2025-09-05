package io.agora.scene.convoai.ui.mine

import android.app.Activity
import android.content.Intent
import android.view.ViewGroup
import io.agora.scene.common.ui.BaseActivity
import io.agora.scene.common.util.dp
import io.agora.scene.common.util.getStatusBarHeight
import io.agora.scene.convoai.databinding.CovActivityProfileNicknameBinding

class CovProfileNicknameActivity : BaseActivity<CovActivityProfileNicknameBinding>() {

    companion object Companion {
        fun startActivity(activity: Activity) {
            val intent = Intent(activity, CovProfileNicknameActivity::class.java)
            activity.startActivity(intent)
        }
    }

    override fun getViewBinding(): CovActivityProfileNicknameBinding {
        return CovActivityProfileNicknameBinding.inflate(layoutInflater)
    }

    override fun initView() {
        mBinding?.apply {
            // Adjust top margin for status bar
            val statusBarHeight = getStatusBarHeight() ?: 25.dp.toInt()
            val layoutParams = layoutTitle.layoutParams as ViewGroup.MarginLayoutParams
            layoutParams.topMargin = statusBarHeight
            layoutTitle.layoutParams = layoutParams

            ivBackIcon.setOnClickListener {
                onHandleOnBackPressed()
            }
        }
    }
}
