package io.agora.scene.convoai.ui.main

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import io.agora.scene.common.ui.BaseDialogFragment
import io.agora.scene.common.util.GsonTools
import io.agora.scene.convoai.CovLogger
import io.agora.scene.convoai.api.VersionInfo
import io.agora.scene.convoai.R
import io.agora.scene.convoai.databinding.AppVersionTestDialogLayoutBinding

class AppVersionTestDialog : BaseDialogFragment<AppVersionTestDialogLayoutBinding>() {

    companion object {
        private const val TAG = "AppVersionTestDialog"
        private const val ARG_CURRENT_VERSION = "arg_current_version"
        private const val ARG_CURRENT_VERSION_CODE = "arg_current_version_code"
        private const val ARG_VERSION_INFO = "arg_version_info"

        fun newInstance(
            currentVersion: String = "",
            currentVersionCode: Int = 0,
            latestVersionInfo: VersionInfo,
            onUpdateCallback: ((Boolean) -> Unit)? = null,
        ): AppVersionTestDialog {
            return AppVersionTestDialog().apply {
                arguments = Bundle().apply {
                    putString(ARG_CURRENT_VERSION, currentVersion)
                    putInt(ARG_CURRENT_VERSION_CODE, currentVersionCode)
                    putString(ARG_VERSION_INFO, GsonTools.beanToString(latestVersionInfo))
                }
                this.onUpdateCallback = onUpdateCallback
            }
        }
    }

    private var onUpdateCallback: ((Boolean) -> Unit)? = null
    private var currentVersionName: String = ""
    private var currentVersionCode: Int = 0
    private var latestVersionInfo: VersionInfo? = null

    override fun getViewBinding(
        inflater: LayoutInflater,
        container: ViewGroup?
    ): AppVersionTestDialogLayoutBinding? {
        return AppVersionTestDialogLayoutBinding.inflate(inflater, container, false)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Prevent dialog from being dismissed by clicking outside or pressing back button
        isCancelable = false
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        // Prevent dialog from being dismissed by clicking outside
        dialog?.setCanceledOnTouchOutside(false)

        // Get arguments
        arguments?.let {
            currentVersionName = it.getString(ARG_CURRENT_VERSION, "")
            currentVersionCode = it.getInt(ARG_CURRENT_VERSION_CODE, 0)
            val versionInfoJson = it.getString(ARG_VERSION_INFO, "")
            latestVersionInfo = GsonTools.toBean(versionInfoJson, VersionInfo::class.java)
        }

        setupDialog()
    }

    private fun setupDialog() {
        mBinding?.apply {
            // Set dialog width to 84% of screen width using extension function
            root.setDialogWidth(0.84f)
            setupVersionContent()
            setupClickListeners()
        }
    }

    private fun AppVersionTestDialogLayoutBinding.setupVersionContent() {
        val versionInfo = latestVersionInfo ?: return

        // Set version info text with current and latest version (format: versionName(versionCode))
        if (currentVersionName.isNotEmpty() && versionInfo.app_version.isNotEmpty()) {
            val currentVersionText = "$currentVersionName($currentVersionCode)"
            val latestVersionText = "${versionInfo.app_version}(${versionInfo.build_version})"
            tvInfo.text = getString(R.string.cov_version_update_info, currentVersionText, latestVersionText)
        }

        // Set description text (left aligned)
        if (versionInfo.description.isNotEmpty()) {
            tvContent.text = versionInfo.description
            tvContent.visibility = View.VISIBLE
        } else {
            tvContent.visibility = View.GONE
        }
    }

    override fun onHandleOnBackPressed() {
        // Override to prevent dismissing dialog by pressing back button
        // Only allow dismissing through cancel button
    }

    private fun AppVersionTestDialogLayoutBinding.setupClickListeners() {
        btnPositive.setOnClickListener {
            // Open download URL in browser
            val downloadUrl = latestVersionInfo?.download_url ?: ""
            if (downloadUrl.isNotEmpty()) {
                try {
                    val intent = Intent(Intent.ACTION_VIEW, Uri.parse(downloadUrl))
                    startActivity(intent)
                } catch (e: Exception) {
                    CovLogger.e(TAG, "Failed to open browser: ${e.message}")
                }
            }
            onUpdateCallback?.invoke(true)
            dismiss()
        }

        btnNegative.setOnClickListener {
            onUpdateCallback?.invoke(false)
            dismiss()
        }
    }
}