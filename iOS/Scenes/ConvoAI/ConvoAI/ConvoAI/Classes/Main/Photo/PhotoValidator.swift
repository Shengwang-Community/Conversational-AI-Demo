//
//  PhotoValidator.swift
//  ConvoAI
//
//  Created by HeZhengQing on 2025/07/03.
//

import UIKit
import Foundation

/**
 * 照片验证工具类
 * 支持格式：JPG、PNG、WEBP、JPEG
 * 最大单图限制：小于5MB
 * 最大尺寸限制：2048×2048
 */
class PhotoValidator {
    
    private static let TAG = "PhotoValidator"
    private static let MAX_FILE_SIZE: Int64 = 5 * 1024 * 1024  // 5MB
    private static let MAX_WIDTH: CGFloat = 2048
    private static let MAX_HEIGHT: CGFloat = 2048
    
    // 支持的图片格式
    private static let SUPPORTED_FORMATS: Set<String> = [
        "image/jpeg",
        "image/jpg",
        "image/png",
        "image/webp"
    ]
    
    struct ValidationResult {
        let isValid: Bool
        let errorMessage: String?
        let fileSize: Int64
        let width: CGFloat
        let height: CGFloat
        let mimeType: String?
        
        init(isValid: Bool, errorMessage: String? = nil, fileSize: Int64 = 0, width: CGFloat = 0, height: CGFloat = 0, mimeType: String? = nil) {
            self.isValid = isValid
            self.errorMessage = errorMessage
            self.fileSize = fileSize
            self.width = width
            self.height = height
            self.mimeType = mimeType
        }
    }
    
    /**
     * 验证照片是否符合所有要求（基于UIImage）
     */
    static func validatePhoto(_ image: UIImage?) -> ValidationResult {
        print("[\(TAG)] Starting image validation")
        
        guard let image = image else {
            print("[\(TAG)] Image is nil")
            return ValidationResult(
                isValid: false,
                errorMessage: "图片为空或无法加载"
            )
        }
        
        let width = image.size.width
        let height = image.size.height
        print("[\(TAG)] Image info - Width: \(width), Height: \(height)")
        
        // 检查图片尺寸
        if width > MAX_WIDTH || height > MAX_HEIGHT {
            print("[\(TAG)] Image dimensions exceed limit: \(width)x\(height) > \(MAX_WIDTH)x\(MAX_HEIGHT)")
            return ValidationResult(
                isValid: false,
                errorMessage: "图片尺寸过大，请使用尺寸不超过\(Int(MAX_WIDTH))×\(Int(MAX_HEIGHT))的图片",
                width: width,
                height: height
            )
        }
        
        // 估算文件大小
        let estimatedSize = estimateImageSize(image)
        print("[\(TAG)] Estimated image size: \(formatFileSize(estimatedSize)) (\(estimatedSize) bytes), Max allowed: \(formatFileSize(MAX_FILE_SIZE))")
        
        if estimatedSize > MAX_FILE_SIZE {
            print("[\(TAG)] Estimated image size exceeds limit: \(formatFileSize(estimatedSize)) > \(formatFileSize(MAX_FILE_SIZE))")
            return ValidationResult(
                isValid: false,
                errorMessage: "图片文件过大，请使用小于\(MAX_FILE_SIZE / (1024 * 1024))MB的图片",
                fileSize: estimatedSize,
                width: width,
                height: height
            )
        }
        
        // 所有验证通过
        print("[\(TAG)] Image validation passed - Dimensions: \(width)x\(height), Estimated size: \(formatFileSize(estimatedSize))")
        return ValidationResult(
            isValid: true,
            fileSize: estimatedSize,
            width: width,
            height: height,
            mimeType: "image/uiimage" // UIImage对象无法确定具体格式
        )
    }
    
    /**
     * 验证照片是否符合所有要求（基于URL）
     */
    static func validatePhoto(url: URL) -> ValidationResult {
        print("[\(TAG)] Starting photo validation for URL: \(url)")
        
        do {
            // 1. 检查文件格式
            let mimeType = getMimeType(from: url)
            print("[\(TAG)] Detected MIME type: \(mimeType ?? "unknown")")
            
            if let mimeType = mimeType {
                if !SUPPORTED_FORMATS.contains(mimeType.lowercased()) {
                    print("[\(TAG)] Unsupported image format: \(mimeType). Supported formats: \(SUPPORTED_FORMATS)")
                    return ValidationResult(
                        isValid: false,
                        errorMessage: "不支持的图片格式。支持格式：JPG、PNG、WEBP、JPEG",
                        mimeType: mimeType
                    )
                }
            }
            
            // 2. 检查文件大小
            let fileSize = try getFileSize(url: url)
            print("[\(TAG)] File size: \(formatFileSize(fileSize)) (\(fileSize) bytes), Max allowed: \(formatFileSize(MAX_FILE_SIZE))")
            
            if fileSize > MAX_FILE_SIZE {
                print("[\(TAG)] File size exceeds limit: \(formatFileSize(fileSize)) > \(formatFileSize(MAX_FILE_SIZE))")
                return ValidationResult(
                    isValid: false,
                    errorMessage: "图片文件过大，请选择小于\(MAX_FILE_SIZE / (1024 * 1024))MB的图片",
                    fileSize: fileSize,
                    mimeType: mimeType
                )
            }
            
            // 3. 检查图片尺寸
            let dimensions = getImageDimensions(url: url)
            print("[\(TAG)] Image dimensions: \(dimensions.width)x\(dimensions.height), Max allowed: \(MAX_WIDTH)x\(MAX_HEIGHT)")
            
            if dimensions.width > MAX_WIDTH || dimensions.height > MAX_HEIGHT {
                print("[\(TAG)] Image dimensions exceed limit: \(dimensions.width)x\(dimensions.height) > \(MAX_WIDTH)x\(MAX_HEIGHT)")
                return ValidationResult(
                    isValid: false,
                    errorMessage: "图片尺寸过大，请选择尺寸不超过\(Int(MAX_WIDTH))×\(Int(MAX_HEIGHT))的图片",
                    fileSize: fileSize,
                    width: dimensions.width,
                    height: dimensions.height,
                    mimeType: mimeType
                )
            }
            
            // 所有验证通过
            print("[\(TAG)] Photo validation passed - Type: \(mimeType ?? "unknown"), Size: \(formatFileSize(fileSize)), Dimensions: \(dimensions.width)x\(dimensions.height)")
            return ValidationResult(
                isValid: true,
                fileSize: fileSize,
                width: dimensions.width,
                height: dimensions.height,
                mimeType: mimeType
            )
            
        } catch {
            print("[\(TAG)] Error occurred during URL photo validation: \(error.localizedDescription)")
            return ValidationResult(
                isValid: false,
                errorMessage: "验证图片时发生错误：\(error.localizedDescription)"
            )
        }
    }
    
    /**
     * 估算UIImage的文件大小
     */
    private static func estimateImageSize(_ image: UIImage) -> Int64 {
        let width = image.size.width
        let height = image.size.height
        let scale = image.scale
        
        // 计算实际像素数
        let pixelWidth = width * scale
        let pixelHeight = height * scale
        let totalPixels = Int64(pixelWidth * pixelHeight)
        
        // 根据图片特征估算字节数（JPEG压缩率约为原始RGBA的5-15%）
        let bytesPerPixel: Int64 = 4 // RGBA
        let rawSize = totalPixels * bytesPerPixel
        let compressionRatio: Double = 0.1 // 10%压缩率，比较保守的估算
        
        let estimatedSize = Int64(Double(rawSize) * compressionRatio)
        print("[\(TAG)] Image size estimation - Pixels: \(pixelWidth)x\(pixelHeight), Scale: \(scale), Raw size: \(formatFileSize(rawSize)), Estimated compressed: \(formatFileSize(estimatedSize))")
        return estimatedSize
    }
    
    /**
     * 获取文件MIME类型
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
     * 获取文件大小
     */
    private static func getFileSize(url: URL) throws -> Int64 {
        let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey])
        return Int64(resourceValues.fileSize ?? 0)
    }
    
    /**
     * 获取图片尺寸
     */
    private static func getImageDimensions(url: URL) -> CGSize {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            print("[\(TAG)] Failed to create image source from URL")
            return CGSize.zero
        }
        
        guard let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any] else {
            print("[\(TAG)] Failed to get image properties")
            return CGSize.zero
        }
        
        let width = imageProperties[kCGImagePropertyPixelWidth] as? CGFloat ?? 0
        let height = imageProperties[kCGImagePropertyPixelHeight] as? CGFloat ?? 0
        
        print("[\(TAG)] Image dimensions retrieved: \(width)x\(height)")
        return CGSize(width: width, height: height)
    }
    
    /**
     * 格式化文件大小显示
     */
    static func formatFileSize(_ bytes: Int64) -> String {
        if bytes < 1024 {
            return "\(bytes)B"
        } else if bytes < 1024 * 1024 {
            return "\(bytes / 1024)KB"
        } else {
            return String(format: "%.1fMB", Double(bytes) / (1024.0 * 1024.0))
        }
    }
} 