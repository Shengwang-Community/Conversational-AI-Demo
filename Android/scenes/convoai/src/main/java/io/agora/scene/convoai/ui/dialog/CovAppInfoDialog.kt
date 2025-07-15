package io.agora.scene.convoai.ui.dialog

import android.annotation.SuppressLint
import android.app.Dialog
import android.content.DialogInterface
import android.graphics.PorterDuff
import android.os.Bundle
import android.view.GestureDetector
import android.view.Gravity
import android.view.LayoutInflater
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.view.animation.Animation
import android.view.animation.AnimationUtils
import io.agora.scene.common.constant.ServerConfig
import io.agora.scene.common.ui.BaseDialogFragment
import io.agora.scene.common.ui.OnFastClickListener
import io.agora.scene.convoai.R
import io.agora.scene.convoai.convoaiApi.ConversationalAIAPI_VERSION
import io.agora.scene.convoai.databinding.CovAppInfoDialogBinding
import io.agora.scene.convoai.iot.manager.CovIotDeviceManager
import kotlin.math.abs

class CovAppInfoDialog : BaseDialogFragment<CovAppInfoDialogBinding>() {
    private var onDismissCallback: (() -> Unit)? = null
    private var onLogout: (() -> Unit)? = null
    private var onIotDeviceClick: (() -> Unit)? = null
    companion object {
        fun newInstance(
            onDismissCallback: () -> Unit,
            onLogout: () -> Unit,
            onIotDeviceClick: () -> Unit
        ): CovAppInfoDialog {
            return CovAppInfoDialog().apply {
                this.onDismissCallback = onDismissCallback
                this.onLogout = onLogout
                this.onIotDeviceClick = onIotDeviceClick
            }
        }
    }

    private lateinit var gestureDetector: GestureDetector

    override fun onDismiss(dialog: DialogInterface) {
        super.onDismiss(dialog)
        onDismissCallback?.invoke()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setStyle(STYLE_NO_FRAME, R.style.LeftSideSheetDialog)
    }

    override fun onCreateDialog(savedInstanceState: Bundle?): Dialog {
        return super.onCreateDialog(savedInstanceState).apply {
            window?.apply {
                setGravity(Gravity.START)
                setLayout(
                    WindowManager.LayoutParams.WRAP_CONTENT,
                    WindowManager.LayoutParams.MATCH_PARENT
                )
            }
        }
    }

    private var uploadAnimation: Animation? = null

    @SuppressLint("ClickableViewAccessibility")
    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        context?.let { cxt->
            uploadAnimation = AnimationUtils.loadAnimation(cxt, R.anim.cov_rotate_loading)

            gestureDetector = GestureDetector(cxt, object : GestureDetector.SimpleOnGestureListener() {
                override fun onFling(e1: MotionEvent?, e2: MotionEvent, velocityX: Float, velocityY: Float): Boolean {
                    if (e1 == null) return false

                    if (e2.x - e1.x < -100 && abs(velocityX) > 100) {
                        dismiss()
                        return true
                    }
                    return false
                }
            })
        }

        view.setOnTouchListener { _, event ->
            gestureDetector.onTouchEvent(event)
            false
        }

        mBinding?.apply {
            btnClose.setOnClickListener(object : OnFastClickListener() {
                override fun onClickJacking(view: View) {
                    dismiss()
                }
            })
            flDeviceContent.setOnClickListener {
                onIotDeviceClick?.invoke()
            }
            layoutLogout.setOnClickListener {
                onLogout?.invoke()
            }
            updateDeviceCount()

            tvVersionName.text =
                getString(io.agora.scene.common.R.string.common_app_version, ConversationalAIAPI_VERSION)
            tvBuild.text = getString(io.agora.scene.common.R.string.common_app_build_no, ServerConfig.appBuildNo)
        }
    }

    override fun onResume() {
        super.onResume()
        updateDeviceCount()
    }

    override fun getViewBinding(inflater: LayoutInflater, container: ViewGroup?): CovAppInfoDialogBinding? {
        return CovAppInfoDialogBinding.inflate(inflater, container, false)
    }

    override fun onHandleOnBackPressed() {
//        super.onHandleOnBackPressed()
    }

    private fun updateDeviceCount() {
        val count = CovIotDeviceManager.Companion.getInstance(requireContext()).getDeviceCount()
        mBinding?.tvDeviceCount?.text = getString(R.string.cov_iot_devices_num, count)
    }
}