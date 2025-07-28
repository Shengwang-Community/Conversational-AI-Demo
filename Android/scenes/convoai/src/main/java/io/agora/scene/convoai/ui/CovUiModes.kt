package io.agora.scene.convoai.ui

/**
 * Sealed base class for resource error types.
 * Extend this class to represent specific resource errors (e.g., picture, audio, etc.).
 */
sealed class ResourceError

/**
 * Picture error data class, extends ResourceError.
 * Used to represent errors related to image resources.
 * @property uuid Unique identifier for the image
 * @property success Whether the operation was successful
 * @property errorCode Error code if the operation failed
 * @property errorMessage Error message if the operation failed
 */
data class PictureError(
    val uuid: String,
    val success: Boolean,
    val errorCode: Int?,
    val errorMessage: String?
) : ResourceError()


// Base class for all media information types
sealed class MediaInfo

/**
 * Picture information data class, extends MediaInfo
 * @property uuid Unique identifier for the image
 * @property width Image width in pixels
 * @property height Image height in pixels
 * @property sizeBytes Image file size in bytes
 * @property sourceType Source type of the image (e.g., local, remote)
 * @property sourceValue Source value (e.g., file path or URL)
 * @property uploadTime Upload timestamp in milliseconds
 * @property totalUserImages Total number of user images
 */
data class PictureInfo(
    val uuid: String,
    val width: Int,
    val height: Int,
    val sizeBytes: Long,
    val sourceType: String,
    val sourceValue: String,
    val uploadTime: Long,
    val totalUserImages: Int,
) : MediaInfo()