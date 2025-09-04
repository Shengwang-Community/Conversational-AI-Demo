package io.agora.scene.common.util.toast

import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.widget.Toast
import androidx.annotation.StringRes
import io.agora.scene.common.AgentApp
import io.agora.scene.common.util.dp

object ToastUtil {

    private val mMainHandler by lazy {
        Handler(Looper.getMainLooper())
    }

    @JvmStatic
    fun show(@StringRes resId: Int, duration: Int = Toast.LENGTH_SHORT, vararg formatArgs: String?) {
        show(AgentApp.instance().getString(resId, *formatArgs), duration)
    }

    @JvmStatic
    fun show(@StringRes resId: Int, vararg formatArgs: String?) {
        show(AgentApp.instance().getString(resId, *formatArgs))
    }

    @JvmStatic
    fun show(
        msg: String,
        duration: Int = Toast.LENGTH_SHORT,
        gravity: Int = Gravity.BOTTOM,
        offsetY: Int = 200.dp.toInt(),
    ) {
        show(
            msg = msg,
            toastType = InternalToast.COMMON,
            duration = duration,
            gravity = gravity,
            offsetY = offsetY
        )
    }

    @JvmStatic
    fun showTips(
        @StringRes resId: Int,
        duration: Int = Toast.LENGTH_SHORT,
        gravity: Int = Gravity.BOTTOM,
        offsetY: Int = 200.dp.toInt(),
    ) {
        show(
            msg = AgentApp.instance().getString(resId),
            toastType = InternalToast.TIPS,
            duration = duration,
            gravity = gravity,
            offsetY = offsetY
        )
    }

    @JvmStatic
    fun showTips(
        msg: String,
        duration: Int = Toast.LENGTH_SHORT,
        gravity: Int = Gravity.BOTTOM,
        offsetY: Int = 200.dp.toInt(),
    ) {
        show(
            msg = msg,
            toastType = InternalToast.TIPS,
            duration = duration,
            gravity = gravity,
            offsetY = offsetY
        )
    }

    @JvmStatic
    fun showError(
        @StringRes resId: Int,
        duration: Int = Toast.LENGTH_SHORT,
        gravity: Int = Gravity.BOTTOM,
        offsetY: Int = 200.dp.toInt()
    ) {
        show(
            msg = AgentApp.instance().getString(resId),
            toastType = InternalToast.ERROR,
            duration = duration,
            gravity = gravity,
            offsetY = offsetY
        )
    }

    @JvmStatic
    fun showError(
        msg: String,
        duration: Int = Toast.LENGTH_SHORT,
        gravity: Int = Gravity.BOTTOM,
        offsetY: Int = 200.dp.toInt()
    ) {
        show(
            msg = msg,
            toastType = InternalToast.ERROR,
            duration = duration,
            gravity = gravity,
            offsetY = offsetY
        )
    }


    @JvmStatic
    fun showNew(
        @StringRes resId: Int,
        duration: Int = Toast.LENGTH_SHORT,
        gravity: Int = Gravity.BOTTOM,
        offsetY: Int = 200.dp.toInt()
    ) {
        show(
            msg = AgentApp.instance().getString(resId),
            toastType = InternalToast.NEW_COMMON,
            duration = duration,
            gravity = gravity,
            offsetY = offsetY
        )
    }

    @JvmStatic
    fun showNew(
        msg: String,
        duration: Int = Toast.LENGTH_SHORT,
        gravity: Int = Gravity.BOTTOM,
        offsetY: Int = 200.dp.toInt()
    ) {
        show(
            msg = msg,
            toastType = InternalToast.NEW_COMMON,
            duration = duration,
            gravity = gravity,
            offsetY = offsetY
        )
    }

    @JvmStatic
    fun showNewTips(
        @StringRes resId: Int,
        duration: Int = Toast.LENGTH_SHORT,
        gravity: Int = Gravity.BOTTOM,
        offsetY: Int = 200.dp.toInt()
    ) {
        show(
            msg = AgentApp.instance().getString(resId),
            toastType = InternalToast.NEW_TIPS,
            duration = duration,
            gravity = gravity,
            offsetY = offsetY
        )
    }

    @JvmStatic
    fun showNewTips(
        msg: String,
        duration: Int = Toast.LENGTH_SHORT,
        gravity: Int = Gravity.BOTTOM,
        offsetY: Int = 200.dp.toInt()
    ) {
        show(
            msg = msg,
            toastType = InternalToast.NEW_TIPS,
            duration = duration,
            gravity = gravity,
            offsetY = offsetY
        )
    }

    @JvmStatic
    private fun show(
        msg: String, toastType: Int = InternalToast.COMMON, duration: Int = Toast.LENGTH_SHORT,
        gravity: Int, offsetY: Int
    ) {
        if (Looper.getMainLooper().thread == Thread.currentThread()) {
            InternalToast.init(AgentApp.instance())
            InternalToast.show(msg, toastType, duration, gravity, offsetY)
        } else {
            mMainHandler.post {
                InternalToast.init(AgentApp.instance())
                InternalToast.show(msg, toastType, duration, gravity, offsetY)
            }
        }
    }
}