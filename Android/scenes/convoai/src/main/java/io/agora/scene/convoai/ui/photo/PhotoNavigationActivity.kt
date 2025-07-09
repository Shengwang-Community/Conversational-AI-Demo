package io.agora.scene.convoai.ui.photo

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.net.Uri
import io.agora.scene.common.ui.BaseActivity
import io.agora.scene.convoai.R
import io.agora.scene.convoai.databinding.CovPhotoNavigationActivityBinding

class PhotoNavigationActivity : BaseActivity<CovPhotoNavigationActivityBinding>() {
    
    private var completion: ((Bitmap?) -> Unit)? = null
    
    companion object {
        private const val EXTRA_CALLBACK_ID = "callback_id"
        private const val REQUEST_GALLERY = 1001
        private val callbacks = mutableMapOf<String, (Bitmap?) -> Unit>()
        
        fun start(context: Context, completion: (Bitmap?) -> Unit) {
            val callbackId = System.currentTimeMillis().toString()
            callbacks[callbackId] = completion
            
            val intent = Intent(context, PhotoNavigationActivity::class.java)
            intent.putExtra(EXTRA_CALLBACK_ID, callbackId)
            context.startActivity(intent)
            
            if (context is Activity) {
                context.overridePendingTransition(0, 0)
            }
        }
    }

    override fun getViewBinding(): CovPhotoNavigationActivityBinding = 
        CovPhotoNavigationActivityBinding.inflate(layoutInflater)

    override fun initView() {
        val callbackId = intent.getStringExtra(EXTRA_CALLBACK_ID)
        completion = callbackId?.let { callbacks[it] }
        
        showPhotoPickType()
    }
    
    override fun onDestroy() {
        super.onDestroy()
        val callbackId = intent.getStringExtra(EXTRA_CALLBACK_ID)
        callbackId?.let { callbacks.remove(it) }
    }
    
    private fun showPhotoPickType() {
        val fragment = PhotoPickTypeFragment.newInstance(
            onPickPhoto = { openGallery() },
            onTakePhoto = { pushTakePhoto() },
            onCancel = { dismissFlow() }
        )
        
        supportFragmentManager.beginTransaction()
            .replace(R.id.fragment_container, fragment, "photo_pick_type")
            .commit()
    }
    
    private fun pushTakePhoto() {
        val fragment = TakePhotoFragment.newInstance { bitmap ->
            if (bitmap != null) {
                pushPhotoEdit(bitmap)
            }
        }
        
        supportFragmentManager.beginTransaction()
            .setCustomAnimations(
                R.anim.slide_in_right,
                0,
                0,
                R.anim.slide_out_right
            )
            .replace(R.id.fragment_container, fragment, "take_photo")
            .addToBackStack("take_photo")
            .commit()
    }
    
    fun openGallery() {
        val intent = Intent(Intent.ACTION_PICK, android.provider.MediaStore.Images.Media.EXTERNAL_CONTENT_URI).apply {
            type = "image/*"
            putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("image/jpeg", "image/png", "image/jpg"))
        }
        startActivityForResult(intent, REQUEST_GALLERY)
    }

    fun handleGallerySelection(uri: Uri) {
        // Process photo using PhotoProcessor
        Thread {
            try {
                val processedBitmap = PhotoProcessor.processPhoto(this, uri)
                
                runOnUiThread {
                    if (processedBitmap != null) {
                        // Successfully processed, proceed to edit page
                        pushPhotoEdit(processedBitmap)
                    } else {
                        // Format not supported or processing failed
                        android.widget.Toast.makeText(this, "只支持格式为JPG、PNG、WEBP、JPEG的图片", android.widget.Toast.LENGTH_LONG).show()
                    }
                }
            } catch (e: Exception) {
                runOnUiThread {
                    android.widget.Toast.makeText(this, "图片处理失败: ${e.message}", android.widget.Toast.LENGTH_LONG).show()
                }
            }
        }.start()
    }
    
    private fun pushPhotoEdit(bitmap: Bitmap) {
        // Bitmap should already be processed and ready for editing
        val fragment = PhotoEditFragment.newInstance(bitmap) { editedBitmap ->
            completeFlow(editedBitmap)
        }
        
        runOnUiThread {
            supportFragmentManager.beginTransaction()
                .setCustomAnimations(
                    R.anim.slide_in_right,
                    0,
                    0,
                    R.anim.slide_out_right
                )
                .replace(R.id.fragment_container, fragment, "photo_edit")
                .addToBackStack("photo_edit") 
                .commitAllowingStateLoss()
        }
    }
    
    private fun completeFlow(bitmap: Bitmap?) {
        completion?.invoke(bitmap)
        finish()
        overridePendingTransition(0, 0)
    }
    
    private fun dismissFlow() {
        completion?.invoke(null)
        finish()
        overridePendingTransition(0, 0)
    }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        super.onBackPressed()
        val fragmentManager = supportFragmentManager
        
        if (fragmentManager.backStackEntryCount > 0) {
            fragmentManager.popBackStack()
        } else {
            dismissFlow()
        }
    }
    
    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        
        when (requestCode) {
            REQUEST_GALLERY -> {
                if (resultCode == Activity.RESULT_OK && data?.data != null) {
                    val imageUri = data.data!!
                    handleGallerySelection(imageUri)
                }
            }
        }
    }
    
    private fun convertUriToBitmap(uri: Uri, callback: (Bitmap?) -> Unit) {
        try {
            val inputStream = contentResolver.openInputStream(uri)
            val bitmap = android.graphics.BitmapFactory.decodeStream(inputStream)
            inputStream?.close()
            callback(bitmap)
        } catch (e: Exception) {
            android.util.Log.e("PhotoNavigationActivity", "Error converting URI to bitmap", e)
            callback(null)
        }
    }
} 