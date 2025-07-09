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
import io.agora.scene.common.util.getStatusBarHeight
import io.agora.scene.common.util.dp
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
        // Adapt status bar height to prevent close button being obscured by notch screens
        val statusBarHeight = requireContext().getStatusBarHeight() ?: 25.dp.toInt()
        val layoutParams = binding.topBar.layoutParams as ViewGroup.MarginLayoutParams
        layoutParams.topMargin = statusBarHeight
        binding.topBar.layoutParams = layoutParams
        
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
            
            // Set preview parameters with smaller resolution
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
                            
                            // Apply camera flip if front camera
                            val flippedBitmap = if (lensFacing == CameraSelector.LENS_FACING_FRONT) {
                                PhotoProcessor.flipBitmap(bitmap)
                            } else {
                                bitmap
                            }
                            
                            // Use PhotoProcessor to process the image
                            val processedBitmap = PhotoProcessor.processPhoto(flippedBitmap)
                            
                            withContext(Dispatchers.Main) {
                                binding.shutterButton.isEnabled = true
                                if (processedBitmap != null) {
                                    onPhotoTaken?.invoke(processedBitmap)
                                } else {
                                    ToastUtil.show("只支持格式为JPG、PNG、WEBP、JPEG的图片")
                                }
                            }
                        } catch (e: Exception) {
                            Log.e(TAG, "Error processing captured image", e)
                            withContext(Dispatchers.Main) {
                                binding.shutterButton.isEnabled = true
                                ToastUtil.show("图片处理失败: ${e.message}")
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
            PhotoProcessor.rotateBitmap(bitmap, rotationDegrees.toFloat())
        } else {
            bitmap
        }
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
} 