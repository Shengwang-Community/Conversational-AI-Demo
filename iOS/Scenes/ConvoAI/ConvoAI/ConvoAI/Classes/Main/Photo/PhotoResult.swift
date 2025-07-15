import UIKit
import Foundation

/**
 * Photo processing result object
 */
struct PhotoResult {
    let image: UIImage
    let filePath: String
    let fileURL: URL
    
    var fileName: String {
        return fileURL.lastPathComponent
    }
    
    var fileSize: UInt64 {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: filePath)
            return attributes[.size] as? UInt64 ?? 0
        } catch {
            return 0
        }
    }
    
    /**
     * Get file extension
     */
    func getFileExtension() -> String {
        return fileURL.pathExtension
    }
    
    /**
     * Get formatted file size
     */
    func getFormattedFileSize() -> String {
        let kb = Double(fileSize) / 1024.0
        let mb = kb / 1024.0
        
        if mb >= 1 {
            return String(format: "%.2f MB", mb)
        } else if kb >= 1 {
            return String(format: "%.2f KB", kb)
        } else {
            return "\(fileSize) B"
        }
    }
} 