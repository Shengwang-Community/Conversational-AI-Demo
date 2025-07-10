package io.agora.scene.convoai.ui.photo

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.MediaStore
import android.provider.Settings
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.ContextCompat
import androidx.fragment.app.Fragment
import io.agora.scene.common.ui.CommonDialog
import io.agora.scene.common.util.toast.ToastUtil
import io.agora.scene.convoai.R
import io.agora.scene.convoai.databinding.CovPhotoPickTypeFragmentBinding

class PhotoPickTypeFragment : Fragment() {
    
    private var _binding: CovPhotoPickTypeFragmentBinding? = null
    private val binding get() = _binding!!
    
    private var onPickPhoto: (() -> Unit)? = null
    private var onTakePhoto: (() -> Unit)? = null
    private var onCancel: (() -> Unit)? = null
    
    // Permission types for different scenarios
    private enum class PermissionType {
        STORAGE_GALLERY,
        CAMERA,
        STORAGE_CAMERA
    }
    
    private val galleryLauncher = registerForActivityResult(
        ActivityResultContracts.StartActivityForResult()
    ) { result ->
        if (result.resultCode == android.app.Activity.RESULT_OK) {
            result.data?.data?.let { uri ->
                handleGalleryResult(uri)
            }
        }
    }
    
    private val storagePermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { isGranted ->
        if (isGranted) {
            openGallery()
        } else {
            showPermissionDialog(PermissionType.STORAGE_GALLERY)
        }
    }
    
    private val cameraPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { isGranted ->
        if (isGranted) {
            checkStoragePermissionForCamera()
        } else {
            showPermissionDialog(PermissionType.CAMERA)
        }
    }
    
    private val storageForCameraLauncher = registerForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { isGranted ->
        if (isGranted) {
            onTakePhoto?.invoke()
        } else {
            showPermissionDialog(PermissionType.STORAGE_CAMERA)
        }
    }
    
    companion object {
        fun newInstance(
            onPickPhoto: () -> Unit,
            onTakePhoto: () -> Unit,
            onCancel: () -> Unit
        ): PhotoPickTypeFragment {
            return PhotoPickTypeFragment().apply {
                this.onPickPhoto = onPickPhoto
                this.onTakePhoto = onTakePhoto
                this.onCancel = onCancel
            }
        }
    }
    
    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = CovPhotoPickTypeFragmentBinding.inflate(inflater, container, false)
        return binding.root
    }
    
    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        setupViews()
        setupAnimations()
    }
    
    private fun setupViews() {
        binding.btnClose.setOnClickListener {
            animateExit { onCancel?.invoke() }
        }
        
        binding.btnPickPhoto.setOnClickListener {
            handlePickPhotoClick()
        }
        
        binding.btnTakePhoto.setOnClickListener {
            handleTakePhotoClick()
        }
        
        binding.backgroundOverlay.setOnClickListener {
            animateExit { onCancel?.invoke() }
        }
    }

    private fun setupAnimations() {
        binding.backgroundOverlay.alpha = 0f
        binding.backgroundOverlay.animate()
            .alpha(1f)
            .setDuration(350)
            .start()
        
        val contentHeight = (180 * resources.displayMetrics.density).toInt()
        binding.contentContainer.translationY = contentHeight.toFloat()
        binding.contentContainer.animate()
            .translationY(0f)
            .setDuration(350)
            .setInterpolator(android.view.animation.DecelerateInterpolator(1.5f))
            .start()
    }
    
    private fun animateExit(callback: () -> Unit) {
        binding.backgroundOverlay.animate()
            .alpha(0f)
            .setDuration(200)
            .start()
        
        val contentHeight = binding.contentContainer.height.toFloat()
        binding.contentContainer.animate()
            .translationY(contentHeight)
            .setDuration(200)
            .setInterpolator(android.view.animation.AccelerateInterpolator())
            .withEndAction(callback)
            .start()
    }
    
    /**
     * Handle pick photo button click with complete permission checking
     */
    private fun handlePickPhotoClick() {
        if (checkStoragePermission()) {
            openGallery()
        } else {
            requestStoragePermission()
        }
    }
    
    /**
     * Handle take photo button click with complete permission checking
     */
    private fun handleTakePhotoClick() {
        if (checkCameraPermission()) {
            checkStoragePermissionForCamera()
        } else {
            requestCameraPermission()
        }
    }
    
    /**
     * Check storage permission for camera functionality
     */
    private fun checkStoragePermissionForCamera() {
        if (checkStoragePermission()) {
            onTakePhoto?.invoke()
        } else {
            requestStoragePermissionForCamera()
        }
    }
    
    /**
     * Check storage permission (Android version adaptive)
     */
    private fun checkStoragePermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
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
    
    /**
     * Check camera permission
     */
    private fun checkCameraPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            requireContext(),
            Manifest.permission.CAMERA
        ) == PackageManager.PERMISSION_GRANTED
    }
    
    /**
     * Request storage permission for gallery access
     */
    private fun requestStoragePermission() {
        val permission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            Manifest.permission.READ_MEDIA_IMAGES
        } else {
            Manifest.permission.READ_EXTERNAL_STORAGE
        }
        storagePermissionLauncher.launch(permission)
    }
    
    /**
     * Request camera permission
     */
    private fun requestCameraPermission() {
        cameraPermissionLauncher.launch(Manifest.permission.CAMERA)
    }
    
    /**
     * Request storage permission for camera preview
     */
    private fun requestStoragePermissionForCamera() {
        val permission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            Manifest.permission.READ_MEDIA_IMAGES
        } else {
            Manifest.permission.READ_EXTERNAL_STORAGE
        }
        storageForCameraLauncher.launch(permission)
    }
    
    private fun openGallery() {
        try {
            val intent = Intent(Intent.ACTION_PICK, MediaStore.Images.Media.EXTERNAL_CONTENT_URI).apply {
                type = "image/*"
                putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("image/jpeg", "image/png", "image/jpg"))
            }
            galleryLauncher.launch(intent)
        } catch (e: Exception) {
            ToastUtil.show("Unable to open gallery: ${e.message}")
        }
    }
    
    private fun handleGalleryResult(uri: Uri) {
        try {
            (activity as? PhotoNavigationActivity)?.handleGallerySelection(uri)
        } catch (e: Exception) {
            ToastUtil.show("Failed to process photo: ${e.message}")
        }
    }
    
    /**
     * Show permission dialog with appropriate content
     */
    private fun showPermissionDialog(permissionType: PermissionType) {
        if (activity?.isFinishing == true || activity?.isDestroyed == true) return
        
        val (title, content, positiveAction) = when (permissionType) {
            PermissionType.STORAGE_GALLERY -> Triple(
                getString(R.string.cov_permission_required),
                getString(R.string.cov_photo_permission_storage_gallery),
                { launchAppSettingsForStorage() }
            )
            PermissionType.CAMERA -> Triple(
                getString(R.string.cov_permission_required),
                getString(R.string.cov_photo_permission_camera),
                { launchAppSettingsForCamera() }
            )
            PermissionType.STORAGE_CAMERA -> Triple(
                getString(R.string.cov_permission_required),
                getString(R.string.cov_photo_permission_storage_camera),
                { launchAppSettingsForStorage() }
            )
        }
        
        val builder = CommonDialog.Builder()
            .setTitle(title)
            .setContent(content)
            .hideTopImage()
            .setCancelable(false)
            .setPositiveButton(getString(R.string.cov_photo_permission_go_settings), onClick = { positiveAction.invoke() })
            .setNegativeButton(getString(R.string.cov_photo_permission_cancel)) {  }
        
        builder.build().show(parentFragmentManager, "permission_dialog")
    }
    
    /**
     * Launch app settings for storage permission
     */
    private fun launchAppSettingsForStorage() {
        try {
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:${requireContext().packageName}")
            }
            startActivity(intent)
        } catch (e: Exception) {
            ToastUtil.show("Unable to open settings")
        }
    }
    
    /**
     * Launch app settings for camera permission
     */
    private fun launchAppSettingsForCamera() {
        try {
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:${requireContext().packageName}")
            }
            startActivity(intent)
        } catch (e: Exception) {
            ToastUtil.show("Unable to open settings")
        }
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
}