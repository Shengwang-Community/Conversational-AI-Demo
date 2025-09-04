package io.agora.scene.convoai.ui.mine

import android.app.Activity
import android.content.Intent
import android.graphics.Color
import android.os.Build
import android.text.TextUtils
import android.view.View
import android.view.ViewGroup
import android.webkit.WebChromeClient
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import io.agora.scene.common.ui.BaseActivity
import io.agora.scene.common.util.dp
import io.agora.scene.common.util.getStatusBarHeight
import io.agora.scene.convoai.databinding.CovTermsActivityBinding

class TermsActivity : BaseActivity<CovTermsActivityBinding>() {

    companion object {
        private const val URL_KEY = "url_key"

        fun startActivity(activity: Activity, url: String) {
            val intent = Intent(activity, TermsActivity::class.java).apply {
                putExtra(URL_KEY, url)
            }
            activity.startActivity(intent)
        }
    }

    override fun getViewBinding(): CovTermsActivityBinding {
        return CovTermsActivityBinding.inflate(layoutInflater)
    }

    override fun initView() {
        mBinding?.apply {
            val statusBarHeight = getStatusBarHeight() ?: 25.dp.toInt()
            val layoutParams = layoutTitle.layoutParams as ViewGroup.MarginLayoutParams
            layoutParams.topMargin = statusBarHeight
            layoutTitle.layoutParams = layoutParams

            ivBackIcon.setOnClickListener {
                onHandleOnBackPressed()
            }

            webView.setBackgroundColor(Color.BLACK)

            webView.settings.apply {
                javaScriptEnabled = true
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    // Android 10-11
                    @Suppress("DEPRECATION")
                    setForceDark(WebSettings.FORCE_DARK_ON)
                }
            }

            webView.webViewClient = object : WebViewClient() {
                override fun onPageFinished(view: WebView?, url: String?) {
                    super.onPageFinished(view, url)
                    val js = "javascript:(function() { " +
                            "document.body.style.backgroundColor = 'black'; " +
                            "document.body.style.color = 'white'; " +
                            "})()"
                    webView.evaluateJavascript(js, null)
                }
            }

            intent.getStringExtra(URL_KEY)?.let {
                webView.loadUrl(it)
            }

            webView.webChromeClient = object : WebChromeClient() {
                override fun onProgressChanged(view: WebView, newProgress: Int) {
                    super.onProgressChanged(view, newProgress)
                    progressBar.progress = newProgress
                    if (newProgress == 100) {
                        progressBar.visibility = View.GONE
                    } else {
                        progressBar.visibility = View.VISIBLE
                    }
                }

                override fun onReceivedTitle(view: WebView, title: String) {
                    super.onReceivedTitle(view, title)
                    if (!TextUtils.isEmpty(title) && view.url?.contains(title) == false) {
                        mBinding?.tvTitle?.text = title
                    }
                }
            }
        }
    }

    override fun onHandleOnBackPressed() {
        mBinding?.let {
            if (it.webView.canGoBack()) {
                it.webView.goBack()
            } else {
                super.onHandleOnBackPressed()
            }
        }
    }
}