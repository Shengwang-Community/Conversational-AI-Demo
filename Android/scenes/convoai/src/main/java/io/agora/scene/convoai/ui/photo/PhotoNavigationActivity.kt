package io.agora.scene.convoai.ui.photo

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.net.Uri
import android.os.Environment
import io.agora.scene.common.ui.BaseActivity
import io.agora.scene.common.util.toast.ToastUtil
import io.agora.scene.convoai.R
import io.agora.scene.convoai.databinding.CovPhotoNavigationActivityBinding
import java.io.File
import java.io.FileOutputStream
import java.io.IOException

class PhotoNavigationActivity : BaseActivity<CovPhotoNavigationActivityBinding>() {
    
    private var completion: ((PhotoResult?) -> Unit)? = null
    
    companion object {
        private const val EXTRA_CALLBACK_ID = "callback_id"
        private const val REQUEST_GALLERY = 1001
        private val callbacks = mutableMapOf<String, (PhotoResult?) -> Unit>()
        
        fun start(context: Context, completion: (PhotoResult?) -> Unit) {
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
                R.anim.slide_out_left,
                R.anim.slide_in_left,
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
                        ToastUtil.show(getString(R.string.cov_photo_format_tips))
                    }
                }
            } catch (e: Exception) {
                runOnUiThread {
                    ToastUtil.show("Failed to process image: ${e.message}")
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
                    R.anim.slide_out_left,
                    R.anim.slide_in_left,
                    R.anim.slide_out_right
                )
                .replace(R.id.fragment_container, fragment, "photo_edit")
                .addToBackStack("photo_edit") 
                .commitAllowingStateLoss()
        }
    }
    
    private fun completeFlow(bitmap: Bitmap?) {
        if (bitmap != null) {
            // Save file and generate result in background thread
            Thread {
                try {
                    val photoResult = saveBitmapAndCreateResult(bitmap)
                    runOnUiThread {
                        completion?.invoke(photoResult)
                        finish()
                        overridePendingTransition(0, 0)
                    }
                } catch (e: Exception) {
                    runOnUiThread {
                        ToastUtil.show("Failed to save photo: ${e.message}")
                        completion?.invoke(null)
                        finish()
                        overridePendingTransition(0, 0)
                    }
                }
            }.start()
        } else {
            completion?.invoke(null)
            finish()
            overridePendingTransition(0, 0)
        }
    }
    
    private fun dismissFlow() {
        completion?.invoke(null)
        finish()
        overridePendingTransition(0, 0)
    }
    
    /**
     * Get app-specific photo output directory
     */
    private fun getPhotoOutputDirectory(): File {
        val picturesDir = getExternalFilesDir(Environment.DIRECTORY_PICTURES)
        return File(picturesDir, "edited_photos").apply {
            if (!exists()) mkdirs()
        }
    }
    
    /**
     * Generate unique photo file name
     */
    private fun generatePhotoFileName(): String {
        return "photo_${System.currentTimeMillis()}.jpg"
    }
    
    /**
     * Save Bitmap to file and create PhotoResult object
     */
    private fun saveBitmapAndCreateResult(bitmap: Bitmap): PhotoResult {
        val photoFile = File(getPhotoOutputDirectory(), generatePhotoFileName())
        
        // Save bitmap to file
        FileOutputStream(photoFile).use { out ->
            bitmap.compress(Bitmap.CompressFormat.JPEG, 90, out)
        }
        
        // Create and return PhotoResult object
        return PhotoResult(
            bitmap = bitmap,
            filePath = photoFile.absolutePath,
            fileUri = Uri.fromFile(photoFile),
            file = photoFile
        )
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