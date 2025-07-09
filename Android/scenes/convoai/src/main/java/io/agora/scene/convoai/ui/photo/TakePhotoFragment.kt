package io.agora.scene.convoai.ui.photo

import android.Manifest
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.os.Bundle
import android.provider.MediaStore
import android.util.Log
import android.view.*
import androidx.activity.result.contract.ActivityResultContracts
import androidx.camera.core.*
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.content.ContextCompat
import androidx.fragment.app.Fragment
import androidx.lifecycle.lifecycleScope
import io.agora.scene.common.util.toast.ToastUtil
import io.agora.scene.convoai.databinding.CovTakePhotoFragmentBinding
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class TakePhotoFragment : Fragment() {
    
    private var _binding: CovTakePhotoFragmentBinding? = null
    private val binding get() = _binding!!
    
    private var onPhotoTaken: ((Bitmap?) -> Unit)? = null
    
    private var cameraProvider: ProcessCameraProvider? = null
    private var preview: Preview? = null
    private var imageCapture: ImageCapture? = null
    private var camera: Camera? = null
    private var cameraExecutor: ExecutorService? = null
    
    private var lensFacing: Int = CameraSelector.LENS_FACING_BACK
    
    private val cameraPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { isGranted ->
        if (isGranted) {
            startCamera()
        } else {
            ToastUtil.show("Camera permission required to take photos")
            parentFragmentManager.popBackStack()
        }
    }
    
    private val storagePermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { isGranted ->
        if (isGranted) {
            loadGalleryPreview()
        } else {
            Log.d(TAG, "Storage permission denied - gallery preview disabled")
        }
    }
    
    companion object {
        private const val TAG = "TakePhotoFragment"
        
        fun newInstance(onPhotoTaken: (Bitmap?) -> Unit): TakePhotoFragment {
            return TakePhotoFragment().apply {
                this.onPhotoTaken = onPhotoTaken
            }
        }
    }
    
    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = CovTakePhotoFragmentBinding.inflate(inflater, container, false)
        return binding.root
    }
    
    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        setupViews()
        cameraExecutor = Executors.newSingleThreadExecutor()
        checkCameraPermissionAndInit()
        loadGalleryPreview()
    }
    
    override fun onDestroyView() {
        super.onDestroyView()
        cameraExecutor?.shutdown()
        _binding = null
    }
    
    private fun setupViews() {
        binding.btnClose.setOnClickListener {
            parentFragmentManager.popBackStack()
        }
        
        binding.shutterButton.setOnClickListener {
            takePhoto()
        }
        
        binding.btnSwitchCamera.setOnClickListener {
            switchCamera()
        }
        
        binding.previewImage.setOnClickListener {
            openGallery()
        }
        
        binding.shutterButton.setOnTouchListener { _, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    binding.shutterButton.animate()
                        .scaleX(0.85f)
                        .scaleY(0.85f)
                        .alpha(0.8f)
                        .setDuration(100)
                        .start()
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    binding.shutterButton.animate()
                        .scaleX(1.0f)
                        .scaleY(1.0f)
                        .alpha(1.0f)
                        .setDuration(100)
                        .start()
                }
            }
            false
        }
    }
    
    private fun checkCameraPermissionAndInit() {
        if (allPermissionsGranted()) {
            startCamera()
        } else {
            requestCameraPermission()
        }
    }
    
    private fun allPermissionsGranted() = ContextCompat.checkSelfPermission(
        requireContext(), Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED
    
    private fun requestCameraPermission() {
        cameraPermissionLauncher.launch(Manifest.permission.CAMERA)
    }
    
    private fun startCamera() {
        val cameraProviderFuture = ProcessCameraProvider.getInstance(requireContext())
        
        cameraProviderFuture.addListener({
            cameraProvider = cameraProviderFuture.get()
            
            // 设置预览参数，使用较小分辨率
            preview = Preview.Builder()
                .setTargetRotation(binding.previewView.display.rotation)
                .build()
                .also {
                    it.setSurfaceProvider(binding.previewView.surfaceProvider)
                }
            
            imageCapture = ImageCapture.Builder()
                .setCaptureMode(ImageCapture.CAPTURE_MODE_MAXIMIZE_QUALITY)
                .setTargetRotation(binding.previewView.display.rotation)
                .setTargetResolution(android.util.Size(960, 1280))
                .setJpegQuality(50)
                .build()
            
            val cameraSelector = CameraSelector.Builder()
                .requireLensFacing(lensFacing)
                .build()
            
            try {
                cameraProvider?.unbindAll()
                
                camera = cameraProvider?.bindToLifecycle(
                    this, cameraSelector, preview, imageCapture
                )
                
                Log.d(TAG, "Camera started successfully")
                
            } catch (exc: Exception) {
                Log.e(TAG, "Use case binding failed", exc)
                ToastUtil.show("Camera failed to start: ${exc.message}")
            }
        }, ContextCompat.getMainExecutor(requireContext()))
    }
    
    private fun takePhoto() {
        val imageCapture = imageCapture ?: run {
            ToastUtil.show("Camera not ready")
            return
        }
        
        binding.shutterButton.isEnabled = false
        
        imageCapture.takePicture(
            cameraExecutor!!,
            object : ImageCapture.OnImageCapturedCallback() {
                override fun onError(exception: ImageCaptureException) {
                    Log.e(TAG, "Photo capture failed: ${exception.message}", exception)
                    activity?.runOnUiThread {
                        binding.shutterButton.isEnabled = true
                        ToastUtil.show("Photo capture failed, please retry")
                    }
                }
                
                override fun onCaptureSuccess(image: ImageProxy) {
                    lifecycleScope.launch(Dispatchers.IO) {
                        try {
                            val bitmap = imageProxyToBitmap(image)
                            
                            // 应用相机翻转
                            val flippedBitmap = if (lensFacing == CameraSelector.LENS_FACING_FRONT) {
                                flipBitmap(bitmap)
                            } else {
                                bitmap
                            }
                            
                            // 最终安全检查：确保图片符合5MB限制
                            val finalBitmap = ensureSizeCompliance(flippedBitmap)
                            
                            withContext(Dispatchers.Main) {
                                binding.shutterButton.isEnabled = true
                                onPhotoTaken?.invoke(finalBitmap)
                            }
                        } catch (e: Exception) {
                            Log.e(TAG, "Error processing captured image", e)
                            withContext(Dispatchers.Main) {
                                binding.shutterButton.isEnabled = true
                                ToastUtil.show("Image processing failed: ${e.message}")
                            }
                        } finally {
                            image.close()
                        }
                    }
                }
            }
        )
    }
    
    private fun imageProxyToBitmap(image: ImageProxy): Bitmap {
        val buffer = image.planes[0].buffer
        val bytes = ByteArray(buffer.remaining())
        buffer.get(bytes)
        val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
        
        val rotationDegrees = image.imageInfo.rotationDegrees
        Log.d(TAG, "Image rotation degrees: $rotationDegrees")
        
        return if (rotationDegrees != 0) {
            rotateBitmap(bitmap, rotationDegrees.toFloat())
        } else {
            bitmap
        }
    }
    
    private fun rotateBitmap(bitmap: Bitmap, degrees: Float): Bitmap {
        val matrix = Matrix().apply {
            postRotate(degrees)
        }
        return Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
    }
    
    private fun flipBitmap(bitmap: Bitmap): Bitmap {
        val matrix = Matrix().apply {
            postScale(-1f, 1f, bitmap.width / 2f, bitmap.height / 2f)
        }
        return Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
    }
    
    private fun switchCamera() {
        lensFacing = if (lensFacing == CameraSelector.LENS_FACING_FRONT) {
            CameraSelector.LENS_FACING_BACK
        } else {
            CameraSelector.LENS_FACING_FRONT
        }
        
        startCamera()
    }
    
    private fun openGallery() {
        (activity as? PhotoNavigationActivity)?.openGallery()
    }
    
    private fun hasStoragePermission(): Boolean {
        return if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
            ContextCompat.checkSelfPermission(
                requireContext(),
                Manifest.permission.READ_MEDIA_IMAGES
            ) == PackageManager.PERMISSION_GRANTED
        } else {
            ContextCompat.checkSelfPermission(
                requireContext(),
                Manifest.permission.READ_EXTERNAL_STORAGE
            ) == PackageManager.PERMISSION_GRANTED
        }
    }
    
    private fun requestStoragePermission() {
        val permission = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
            Manifest.permission.READ_MEDIA_IMAGES
        } else {
            Manifest.permission.READ_EXTERNAL_STORAGE
        }
        storagePermissionLauncher.launch(permission)
    }
    
    private fun loadGalleryPreview() {
        if (!hasStoragePermission()) {
            requestStoragePermission()
            return
        }
        
        lifecycleScope.launch(Dispatchers.IO) {
            try {
                val projection = arrayOf(
                    MediaStore.Images.Media._ID,
                    MediaStore.Images.Media.DISPLAY_NAME,
                    MediaStore.Images.Media.DATE_MODIFIED
                )
                
                val sortOrder = "${MediaStore.Images.Media.DATE_MODIFIED} DESC"
                val selection = "${MediaStore.Images.Media.MIME_TYPE} IN (?, ?, ?)"
                val selectionArgs = arrayOf("image/jpeg", "image/png", "image/jpg")
                
                val cursor = requireContext().contentResolver.query(
                    MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                    projection,
                    selection,
                    selectionArgs,
                    sortOrder
                )
                
                cursor?.use {
                    if (it.moveToFirst()) {
                        val imageId = it.getLong(it.getColumnIndexOrThrow(MediaStore.Images.Media._ID))
                        val imageUri = android.content.ContentUris.withAppendedId(
                            MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                            imageId
                        )
                        
                        val thumbnail = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.Q) {
                            requireContext().contentResolver.loadThumbnail(
                                imageUri,
                                android.util.Size(200, 200),
                                null
                            )
                        } else {
                            MediaStore.Images.Thumbnails.getThumbnail(
                                requireContext().contentResolver,
                                imageId,
                                MediaStore.Images.Thumbnails.MINI_KIND,
                                null
                            )
                        }
                        
                        withContext(Dispatchers.Main) {
                            if (thumbnail != null && _binding != null) {
                                binding.previewImage.setImageBitmap(thumbnail)
                                Log.d(TAG, "Gallery preview loaded successfully")
                            } else {
                                Log.d(TAG, "Failed to load gallery thumbnail")
                            }
                        }
                    } else {
                        Log.d(TAG, "No images found in gallery")
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error loading gallery preview", e)
                loadGalleryPreviewFallback()
            }
        }
    }
    
    private fun loadGalleryPreviewFallback() {
        if (!hasStoragePermission()) {
            Log.d(TAG, "No storage permission for fallback gallery preview")
            return
        }
        
        lifecycleScope.launch(Dispatchers.IO) {
            try {
                val projection = arrayOf(
                    MediaStore.Images.Media._ID,
                    MediaStore.Images.Media.DATA
                )
                
                val cursor = requireContext().contentResolver.query(
                    MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                    projection,
                    null,
                    null,
                    "${MediaStore.Images.Media.DATE_MODIFIED} DESC LIMIT 1"
                )
                
                cursor?.use {
                    if (it.moveToFirst()) {
                        val imagePath = it.getString(it.getColumnIndexOrThrow(MediaStore.Images.Media.DATA))
                        if (imagePath != null) {
                            val options = BitmapFactory.Options().apply {
                                inSampleSize = 8
                                inJustDecodeBounds = false
                            }
                            val bitmap = BitmapFactory.decodeFile(imagePath, options)
                            
                            withContext(Dispatchers.Main) {
                                if (bitmap != null && _binding != null) {
                                    binding.previewImage.setImageBitmap(bitmap)
                                    Log.d(TAG, "Gallery preview loaded via fallback")
                                }
                            }
                        }
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error in gallery preview fallback", e)
            }
        }
    }
    
    /**
     * 最终安全检查：确保图片文件大小符合5MB限制
     * 如果估算大小超过限制，会逐步缩小尺寸直到符合要求
     */
    private fun ensureSizeCompliance(bitmap: Bitmap): Bitmap {
        val maxFileSize = 5 * 1024 * 1024L // 5MB
        var currentBitmap = bitmap
        
        // 估算当前大小（按JPEG压缩后的大小估算）
        var estimatedSize = estimateJpegSize(currentBitmap, 50) // 使用50%质量估算
        
        Log.d(TAG, "Original bitmap: ${bitmap.width}x${bitmap.height}, estimated JPEG size: ${estimatedSize / 1024}KB")
        
        // 如果大小超限，逐步缩小
        var scaleFactor = 1.0f
        while (estimatedSize > maxFileSize && scaleFactor > 0.1f) {
            scaleFactor *= 0.8f // 每次缩小到80%
            val newWidth = (bitmap.width * scaleFactor).toInt()
            val newHeight = (bitmap.height * scaleFactor).toInt()
            
            if (newWidth > 0 && newHeight > 0) {
                currentBitmap = Bitmap.createScaledBitmap(bitmap, newWidth, newHeight, true)
                estimatedSize = estimateJpegSize(currentBitmap, 50)
                Log.d(TAG, "Scaled to: ${currentBitmap.width}x${currentBitmap.height}, estimated size: ${estimatedSize / 1024}KB")
            } else {
                break
            }
        }
        
        Log.i(TAG, "Final bitmap: ${currentBitmap.width}x${currentBitmap.height}, estimated JPEG size: ${estimatedSize / 1024}KB")
        return currentBitmap
    }
    
    /**
     * 估算JPEG压缩后的文件大小
     */
    private fun estimateJpegSize(bitmap: Bitmap, quality: Int): Long {
        // 根据质量和像素数估算JPEG文件大小
        val pixels = bitmap.width * bitmap.height.toLong()
        val baseSize = pixels * 3 // RGB基础大小
        
        val compressionRatio = when {
            quality >= 90 -> 0.1f
            quality >= 80 -> 0.08f
            quality >= 70 -> 0.06f
            quality >= 60 -> 0.05f
            quality >= 50 -> 0.04f
            quality >= 40 -> 0.03f
            quality >= 30 -> 0.025f
            quality >= 20 -> 0.02f
            quality >= 10 -> 0.015f
            else -> 0.01f
        }
        
        return (baseSize * compressionRatio).toLong()
    }
} 