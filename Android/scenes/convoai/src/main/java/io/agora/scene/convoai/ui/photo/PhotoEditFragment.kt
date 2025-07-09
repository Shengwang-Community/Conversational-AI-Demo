package io.agora.scene.convoai.ui.photo

import android.graphics.Bitmap
import android.os.Bundle
import android.util.Log
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.fragment.app.Fragment
import io.agora.scene.common.util.toast.ToastUtil
import io.agora.scene.common.util.getStatusBarHeight
import io.agora.scene.common.util.dp
import io.agora.scene.convoai.databinding.CovPhotoEditFragmentBinding

class PhotoEditFragment : Fragment() {
    
    private var _binding: CovPhotoEditFragmentBinding? = null
    private val binding get() = _binding!!
    
    private var originalBitmap: Bitmap? = null
    private var onPhotoEdited: ((Bitmap?) -> Unit)? = null
    
    companion object {
        private const val TAG = "PhotoEditFragment"
        private const val ARG_BITMAP = "bitmap"
        
        fun newInstance(bitmap: Bitmap, onPhotoEdited: (Bitmap?) -> Unit): PhotoEditFragment {
            return PhotoEditFragment().apply {
                arguments = Bundle().apply {
                    putParcelable(ARG_BITMAP, bitmap)
                }
                this.onPhotoEdited = onPhotoEdited
            }
        }
    }
    
    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = CovPhotoEditFragmentBinding.inflate(inflater, container, false)
        return binding.root
    }
    
    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        
        originalBitmap = arguments?.getParcelable(ARG_BITMAP)
        if (originalBitmap != null) {
            setupImageView()
            setupViews()
        } else {
            Log.e(TAG, "No bitmap provided to PhotoEditFragment")
            ToastUtil.show("Failed to load image")
            parentFragmentManager.popBackStack()
        }
    }

    private fun setupImageView() {
        originalBitmap?.let { bitmap ->
            binding.imageView.post {
                binding.imageView.setImageBitmap(bitmap)
                binding.imageView.initializeImage(bitmap)
            }
        }
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
        
        binding.btnRotate.setOnClickListener {
            binding.imageView.rotateImage()
        }
        
        binding.btnDone.setOnClickListener {
            handleDoneClick()
        }
    }

    private fun handleDoneClick() {
        try {
            val editedBitmap = getCurrentBitmap()
            if (editedBitmap != null) {
                onPhotoEdited?.invoke(editedBitmap)
            } else {
                ToastUtil.show("Image processing failed, please retry")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error processing edited image", e)
            ToastUtil.show("Image processing failed: ${e.message}")
        }
    }

    private fun getCurrentBitmap(): Bitmap? {
        return try {
            binding.imageView.getTransformedOriginalBitmap()
        } catch (e: Exception) {
            Log.e(TAG, "Error getting current bitmap", e)
            null
        }
    }
    
    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
} 