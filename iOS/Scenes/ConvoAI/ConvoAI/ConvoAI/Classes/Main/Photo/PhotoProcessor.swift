//
//  PhotoProcessor.swift
//  ConvoAI
//
//  Created by HeZhengQing on 2025/07/09.
//

import UIKit
import Foundation

/**
 * Photo processor class - handles photo validation and processing
 * Processing flow:
 * 1. Format check -> 2. Resolution check -> 3. Size compression -> 4. Return processed photo
 */
class PhotoProcessor {
    
    private static let TAG = "PhotoProcessor"
    private static let MAX_DIMENSION: CGFloat = 2048 // Maximum width/height
    private static let MAX_FILE_SIZE: Int64 = 5 * 1024 * 1024  // 5MB
    
    // Supported image formats
    private static let SUPPORTED_FORMATS: Set<String> = [
        "image/jpeg",
        "image/jpg",
        "image/png",
        "image/webp"
    ]
    
    /**
     * Process photo from URL
     * @param url Photo URL
     * @return Processed image that meets requirements, or nil if format not supported
     */
    static func processPhoto(url: URL) -> UIImage? {
        print("[\(TAG)] Starting photo processing for URL: \(url)")
        // 1. Format check
        let mimeType = getMimeType(from: url)
        print("[\(TAG)] Detected MIME type: \(mimeType ?? "unknown")")
        
        if let mimeType = mimeType {
            if !SUPPORTED_FORMATS.contains(mimeType.lowercased()) {
                print("[\(TAG)] Unsupported image format: \(mimeType)")
                return nil // Format not supported
            }
        } else {
            print("[\(TAG)] Could not determine MIME type")
            return nil
        }
        
        // Load image from URL
        guard let originalImage = UIImage(contentsOfFile: url.path) else {
            print("[\(TAG)] Failed to load image from URL")
            return nil
        }
        return processImage(originalImage)
    }
    
    /**
     * Process photo from UIImage
     * @param image Original image
     * @return Processed image that meets requirements, or nil if processing fails
     */
    static func processPhoto(_ image: UIImage?) -> UIImage? {
        guard let image = image else {
            print("[\(TAG)] Input image is nil")
            return nil
        }
        
        return processImage(image)
    }
    
    /**
     * Core image processing logic
     */
    private static func processImage(_ originalImage: UIImage) -> UIImage? {
        print("[\(TAG)] Processing image - Original size: \(originalImage.size.width)x\(originalImage.size.height)")
        
        // 2. Resolution check and resize if needed
        let resizedImage = resizeIfNeeded(originalImage)
        print("[\(TAG)] After resize - Size: \(resizedImage.size.width)x\(resizedImage.size.height)")
        
        // 3. Size compression if needed
        let finalImage = compressIfNeeded(resizedImage)
        print("[\(TAG)] After compression - Size: \(finalImage.size.width)x\(finalImage.size.height)")
        
        print("[\(TAG)] Photo processing completed successfully")
        return finalImage
    }
    
    /**
     * Resize image if dimensions exceed MAX_DIMENSION
     * Scale down the longer side to MAX_DIMENSION while maintaining aspect ratio
     */
    private static func resizeIfNeeded(_ image: UIImage) -> UIImage {
        let originalSize = image.size
        
        // Check if resize is needed
        if originalSize.width <= MAX_DIMENSION && originalSize.height <= MAX_DIMENSION {
            print("[\(TAG)] Image size is acceptable, no resize needed")
            return image
        }
        
        // Calculate new size, maintaining aspect ratio
        let aspectRatio = originalSize.width / originalSize.height
        var newSize: CGSize
        
        if originalSize.width > originalSize.height {
            // Width is longer, scale based on width
            newSize = CGSize(width: MAX_DIMENSION, height: MAX_DIMENSION / aspectRatio)
        } else {
            // Height is longer, scale based on height
            newSize = CGSize(width: MAX_DIMENSION * aspectRatio, height: MAX_DIMENSION)
        }
        
        print("[\(TAG)] Resizing from \(originalSize.width)x\(originalSize.height) to \(newSize.width)x\(newSize.height)")
        
        // Create graphics context and draw the resized image
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return resizedImage ?? image
    }
    
    /**
     * Compress image if estimated file size exceeds MAX_FILE_SIZE
     * Gradually reduce size until it meets the size requirement
     */
    private static func compressIfNeeded(_ image: UIImage) -> UIImage {
        var currentImage = image
        var estimatedSize = estimateImageSize(currentImage)
        
        print("[\(TAG)] Initial estimated size: \(formatFileSize(estimatedSize))")
        
        // If size is within limit, return as is
        if estimatedSize <= MAX_FILE_SIZE {
            print("[\(TAG)] Image size is within limit, no compression needed")
            return currentImage
        }
        
        // Gradually reduce size until it meets the requirement
        var scaleFactor: CGFloat = 1.0
        while estimatedSize > MAX_FILE_SIZE && scaleFactor > 0.1 {
            scaleFactor *= 0.8 // Reduce to 80% each iteration
            let newSize = CGSize(
                width: image.size.width * scaleFactor,
                height: image.size.height * scaleFactor
            )
            
            if newSize.width > 0 && newSize.height > 0 {
                UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
                image.draw(in: CGRect(origin: .zero, size: newSize))
                if let scaledImage = UIGraphicsGetImageFromCurrentImageContext() {
                    currentImage = scaledImage
                    estimatedSize = estimateImageSize(currentImage)
                    print("[\(TAG)] Compressed to: \(currentImage.size.width)x\(currentImage.size.height), estimated size: \(formatFileSize(estimatedSize))")
                }
                UIGraphicsEndImageContext()
            } else {
                break
            }
        }
        
        print("[\(TAG)] Final compressed size: \(currentImage.size.width)x\(currentImage.size.height), estimated size: \(formatFileSize(estimatedSize))")
        return currentImage
    }
    
    /**
     * Estimate the file size of UIImage
     */
    private static func estimateImageSize(_ image: UIImage) -> Int64 {
        let width = image.size.width
        let height = image.size.height
        let scale = image.scale
        
        // Calculate actual pixel count
        let pixelWidth = width * scale
        let pixelHeight = height * scale
        let totalPixels = Int64(pixelWidth * pixelHeight)
        
        // Estimate bytes based on image characteristics (JPEG compression ratio is about 5-15% of original RGBA)
        let bytesPerPixel: Int64 = 4 // RGBA
        let rawSize = totalPixels * bytesPerPixel
        let compressionRatio: Double = 0.1 // 10% compression ratio, conservative estimate
        
        let estimatedSize = Int64(Double(rawSize) * compressionRatio)
        return estimatedSize
    }
    
    /**
     * Get file MIME type
     */
    private static func getMimeType(from url: URL) -> String? {
        let pathExtension = url.pathExtension.lowercased()
        
        switch pathExtension {
        case "jpg", "jpeg":
            return "image/jpeg"
        case "png":
            return "image/png"
        case "webp":
            return "image/webp"
        default:
            return nil
        }
    }
    
    /**
     * Format file size display
     */
    private static func formatFileSize(_ bytes: Int64) -> String {
        if bytes < 1024 {
            return "\(bytes)B"
        } else if bytes < 1024 * 1024 {
            return "\(bytes / 1024)KB"
        } else {
            return String(format: "%.1fMB", Double(bytes) / (1024.0 * 1024.0))
        }
    }
    
    /**
     * Rotate image by specified degrees
     */
    static func rotateImage(_ image: UIImage, degrees: CGFloat) -> UIImage {
        let radians = degrees * .pi / 180
        let rotatedSize = CGRect(origin: .zero, size: image.size)
            .applying(CGAffineTransform(rotationAngle: radians))
            .integral.size
        
        UIGraphicsBeginImageContextWithOptions(rotatedSize, false, image.scale)
        if let context = UIGraphicsGetCurrentContext() {
            let origin = CGPoint(x: rotatedSize.width / 2, y: rotatedSize.height / 2)
            context.translateBy(x: origin.x, y: origin.y)
            context.rotate(by: radians)
            image.draw(in: CGRect(
                x: -image.size.width / 2,
                y: -image.size.height / 2,
                width: image.size.width,
                height: image.size.height
            ))
        }
        let rotatedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return rotatedImage ?? image
    }
    
    /**
     * Flip image horizontally (for front camera)
     */
    static func flipImage(_ image: UIImage) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        if let context = UIGraphicsGetCurrentContext() {
            context.translateBy(x: image.size.width, y: 0)
            context.scaleBy(x: -1, y: 1)
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
        let flippedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return flippedImage ?? image
    }
} 
