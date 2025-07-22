package io.agora.scene.common.ui;

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.text.TextUtils
import android.view.View
import android.view.ViewGroup
import android.webkit.JavascriptInterface
import android.webkit.WebChromeClient
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.Toast
import androidx.core.view.isVisible
import io.agora.scene.common.constant.ServerConfig.toolBoxUrl
import io.agora.scene.common.databinding.CommonActivitySsoBinding
import io.agora.scene.common.util.CommonLogger
import io.agora.scene.common.util.dp
import io.agora.scene.common.util.getStatusBarHeight
import io.agora.scene.common.util.toast.ToastUtil

class SSOWebViewActivity : BaseActivity<CommonActivitySsoBinding>() {

    override fun getViewBinding(): CommonActivitySsoBinding {
        return CommonActivitySsoBinding.inflate(layoutInflater)
    }

    private val mainHandler by lazy { Handler(Looper.getMainLooper()) }

    companion object {
        private const val TAG = "SSOWebViewActivity"

        private val ssoUrl: String get() = "$toolBoxUrl/v1/convoai/sso/login"

        private const val ssoCallbackPath = "v1/convoai/sso/callback"
    }

    private var mLoadingDialog: LoadingDialog? = null

    override fun initView() {
        mBinding?.apply {
            val statusBarHeight = getStatusBarHeight() ?: 25.dp.toInt()
            val layoutParams = layoutTitle.layoutParams as ViewGroup.MarginLayoutParams
            layoutParams.topMargin = statusBarHeight
            layoutTitle.layoutParams = layoutParams

            mLoadingDialog = LoadingDialog(this@SSOWebViewActivity)
            ivBackIcon.setOnClickListener {
                onHandleOnBackPressed()
            }
            webView.settings.apply {
                setJavaScriptEnabled(true)
                useWideViewPort = false
                domStorageEnabled = true
                allowFileAccess = true
                databaseEnabled = true
                saveFormData = true
                loadWithOverviewMode = true
                setSupportZoom(false)
                defaultTextEncodingName = "UTF-8"
                userAgentString = "Mozilla/5.0 (Linux; Android10) AppleWebKit/537.36 (KHTML, likeGecko) Chrome/110.0.0.0 Mobile Safari/537.36"
            }
            webView.setWebChromeClient(object : WebChromeClient() {
                override fun onProgressChanged(view: WebView, newProgress: Int) {
                    if (newProgress == 100) {
                        mBinding?.progressBar?.visibility = View.GONE
                    } else {
                        if (mBinding?.progressBar?.visibility == View.GONE) {
                            mBinding?.progressBar?.visibility = View.VISIBLE
                        }
                        mBinding?.progressBar?.progress = newProgress
                    }
                    super.onProgressChanged(view, newProgress)
                }

                override fun onReceivedTitle(view: WebView, title: String) {
                    super.onReceivedTitle(view, title)
                    if (!TextUtils.isEmpty(title) && view.url?.contains(title) == false) {
                        mBinding?.tvTitle?.text = title
                    }
                }
            })
            webView.webViewClient = object : WebViewClient() {
                override fun shouldOverrideUrlLoading(view: WebView?, request: WebResourceRequest?): Boolean {
                    val url = request?.url.toString()
                    CommonLogger.d(TAG, "shouldOverrideUrlLoading url = $url")

                    // Only handle callback URL without redirect_uri parameter
                    if (url.contains(ssoCallbackPath) && !url.contains("redirect_uri=")) {
                        CommonLogger.d(TAG, "start login url = $url")
                        runOnUiThread {
                            mLoadingDialog?.show()
                            mBinding?.emptyView?.isVisible = true
                        }
                        return false
                    }
                    return super.shouldOverrideUrlLoading(view, request)
                }

                override fun onPageFinished(view: WebView, url: String) {
                    super.onPageFinished(view, url)
                    CommonLogger.d(TAG, "onPageFinished url = $url")
                    // Only inject JavaScript for callback URL without redirect_uri parameter
                    if (url.contains(ssoCallbackPath) && !url.contains("redirect_uri=")) {
                        CommonLogger.d(TAG, "inject JavaScript for url = $url")
                        injectJavaScript()
                    }
                }

                override fun onReceivedError(view: WebView?, request: WebResourceRequest?, error: WebResourceError?) {
                    super.onReceivedError(view, request, error)
                    runOnUiThread {
                        mLoadingDialog?.dismiss()
                        mBinding?.emptyView?.isVisible = false
                    }
                    CommonLogger.e(TAG, "onReceivedError ${error?.description}")
                }
            }

            webView.addJavascriptInterface(WebAppInterface(this@SSOWebViewActivity), "Android")
            webView.loadUrl(ssoUrl)
        }
    }

    private fun injectJavaScript() {
        // Inject JavaScript code to retrieve JSON data
        val jsCode = """
        (function() {
             // Get the text content of the page
            var jsonResponse = document.body.innerText; // Assume JSON data is in the body of the page
             // Parse the JSON data
            try {
                var jsonData = JSON.parse(jsonResponse); // Parse it into a JSON object
                // Check if the code is 0
                if (jsonData.code === 0) {
                    // Call the Android interface and pass the token
                    Android.handleResponse(jsonData.data.token);
                } else {
                    // If the code is not 0, return the error message
                    Android.handleResponse("Error " + jsonData.msg);
                }
            } catch (e) {
                 // Handle JSON parsing errors
                Android.handleResponse("Error " + e.message);
            }
        })();
    """
        mBinding?.webView?.evaluateJavascript(jsCode, null)
    }

    inner class WebAppInterface(private val context: Context) {

        @JavascriptInterface
        fun handleResponse(response: String) {
            // If it's a token, perform the corresponding action
            if (!response.startsWith("Error")) {
                // Process the token, e.g., save it to SharedPreferences
                // Here you can save the token or perform other actions
                runOnUiThread {
                    setResult(Activity.RESULT_OK, Intent().putExtra("token", response))
                    finish()
                }
            } else {
                // Handle error messages
                runOnUiThread {
                    CommonLogger.e(TAG, "SSO Error: $response")
                    ToastUtil.show(response, Toast.LENGTH_LONG)
                    mLoadingDialog?.dismiss()
                    mBinding?.emptyView?.isVisible = false

                    // Add a delay before clearing cookies and reloading
                    mainHandler.postDelayed({
                        // Clear cookies and reload to allow re-login
                        cleanCookie()
                        mBinding?.webView?.loadUrl(ssoUrl)
                    }, 1500) // 1.5-second delay
                }
            }
        }
    }

    override fun onDestroy() {
        mainHandler.removeCallbacksAndMessages(null)
        mLoadingDialog?.dismiss()
        mBinding?.emptyView?.isVisible = false
        super.onDestroy()
    }

    override fun onHandleOnBackPressed() {
        mBinding?.let {
            if (it.webView.canGoBack()) {
                it.webView.goBack()
            } else {
                super.onHandleOnBackPressed()
            }
        } ?: run {
            super.onHandleOnBackPressed()
        }
    }
}