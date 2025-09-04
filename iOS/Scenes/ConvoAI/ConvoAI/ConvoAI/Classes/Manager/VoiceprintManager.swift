//
//  VoiceprintManager.swift
//  ConvoAI
//
//  Created by HeZhengQing on 2025/08/28.
//

import Foundation

enum VoiceprintMode: Int, CaseIterable, Codable {
    case off = 0
    case seamless = 1
    case aware = 2
}

/// Voiceprint information model
class VoiceprintInfo: Codable {
    /// Remote resource URL
    var remoteUrl: String?
    /// Local resource URL
    var localUrl: String?
    /// Resource update timestamp
    var timestamp: TimeInterval?
    
    /// Voiceprint update strategy configuration
    private static let updateInterval: TimeInterval = 2.5 * 24 * 60 * 60 // 2.5 days
    
    /// Check if voiceprint needs to be updated
    func needToUpdate() -> Bool {
        guard let timestamp = timestamp else { return true }
        let currentTime = Date().timeIntervalSince1970
        return currentTime - timestamp > VoiceprintInfo.updateInterval
    }
}

/// Voiceprint manager
class VoiceprintManager {
    // MARK: - Singleton
     
    static let shared = VoiceprintManager()
     
    private init() {}
    
    let voiceprintDirectory: URL = {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("Voiceprints", isDirectory: true)
    }()
    
    private let fileManager = FileManager.default
    
    // MARK: - Public Methods
     
    /// Save audio file to local storage with user ID as filename
    /// - Parameters:
    ///   - data: Audio data
    ///   - userId: User ID to use as filename
    ///   - fileExtension: File extension (default: "pcm")
    /// - Returns: Returns file URL if save successful, nil if failed
    func saveAudioFile(data: Data, userId: String, fileExtension: String = "pcm") -> URL? {
        do {
            // Create directory
            if !fileManager.fileExists(atPath: voiceprintDirectory.path) {
                try fileManager.createDirectory(at: voiceprintDirectory, withIntermediateDirectories: true)
            }
             
            // Use userId as filename with specified extension
            let fileName = "\(userId).\(fileExtension)"
            let fileURL = voiceprintDirectory.appendingPathComponent(fileName)
            
            // Remove existing file if it exists
            if fileManager.fileExists(atPath: fileURL.path) {
                try fileManager.removeItem(at: fileURL)
            }
            
            try data.write(to: fileURL)
            print("Audio file saved for user \(userId) at: \(fileURL.path)")
            return fileURL
        } catch {
            print("Failed to save audio file for user \(userId): \(error)")
            return nil
        }
    }
    
    /// Get audio file URL by user ID
    /// - Parameters:
    ///   - userId: User ID
    ///   - fileExtension: File extension (default: "pcm")
    /// - Returns: File URL if exists, nil if not found
    func getAudioFileURL(userId: String, fileExtension: String = "pcm") -> URL? {
        let fileName = "\(userId).\(fileExtension)"
        let fileURL = voiceprintDirectory.appendingPathComponent(fileName)
        
        if fileManager.fileExists(atPath: fileURL.path) {
            return fileURL
        } else {
            return nil
        }
    }
     
    /// Delete audio file by user ID
    /// - Parameters:
    ///   - userId: User ID
    ///   - fileExtension: File extension (default: "pcm")
    /// - Returns: Returns true if delete successful, false if failed
    func deleteAudioFile(userId: String, fileExtension: String = "pcm") -> Bool {
        let fileName = "\(userId).\(fileExtension)"
        let fileURL = voiceprintDirectory.appendingPathComponent(fileName)
        return deleteAudioFile(fileURL: fileURL)
    }
    
    private func deleteAudioFile(fileURL: URL) -> Bool {
        do {
            try fileManager.removeItem(at: fileURL)
            return true
        } catch {
            return false
        }
    }
 
 
    /// Save voiceprint information to file
    /// - Parameters:
    ///   - voiceprint: Voiceprint information
    ///   - userId: User ID
    /// - Returns: Whether save was successful
    @discardableResult
    func saveVoiceprint(_ voiceprint: VoiceprintInfo, forUserId userId: String) -> Bool {
        do {
            // Ensure directory exists
            createVoiceprintDirectory()
            
            // Create file path using userId as filename
            let fileName = "\(userId).json"
            let fileURL = voiceprintDirectory.appendingPathComponent(fileName)
            
            // Encode voiceprint info to JSON
            let data = try JSONEncoder().encode(voiceprint)
            
            // Write to file
            try data.write(to: fileURL)
            
            print("Voiceprint info saved for user \(userId) at: \(fileURL.path)")
            return true
        } catch {
            print("Failed to save voiceprint info for user \(userId): \(error)")
            return false
        }
    }
     
    /// Get voiceprint information from file
    /// - Parameter userId: User ID
    /// - Returns: Voiceprint information, returns nil if failed to get
    func getVoiceprint(forUserId userId: String) -> VoiceprintInfo? {
        do {
            // Create file path using userId as filename
            let fileName = "\(userId).json"
            let fileURL = voiceprintDirectory.appendingPathComponent(fileName)
            
            // Check if file exists
            guard fileManager.fileExists(atPath: fileURL.path) else {
                print("Voiceprint file not found for user \(userId)")
                return nil
            }
            
            // Read data from file
            let data = try Data(contentsOf: fileURL)
            
            // Decode voiceprint info from JSON
            let voiceprint = try JSONDecoder().decode(VoiceprintInfo.self, from: data)
            
            print("Voiceprint info loaded for user \(userId) from: \(fileURL.path)")
            return voiceprint
        } catch {
            print("Failed to get voiceprint info for user \(userId): \(error)")
            return nil
        }
    }
     
    // MARK: - Private Methods
    
    /// Create voiceprint directory if it doesn't exist
    private func createVoiceprintDirectory() {
        do {
            if !fileManager.fileExists(atPath: voiceprintDirectory.path) {
                try fileManager.createDirectory(at: voiceprintDirectory, withIntermediateDirectories: true, attributes: nil)
                print("Voiceprint directory created at: \(voiceprintDirectory.path)")
            }
        } catch {
            print("Failed to create voiceprint directory: \(error)")
        }
    }
    
    /// Delete voiceprint information file for specific user
    /// - Parameter userId: User ID
    /// - Returns: Whether deletion was successful
    func deleteVoiceprint(forUserId userId: String) -> Bool {
        do {
            let fileName = "\(userId).json"
            let fileURL = voiceprintDirectory.appendingPathComponent(fileName)
            
            if fileManager.fileExists(atPath: fileURL.path) {
                try fileManager.removeItem(at: fileURL)
                print("Voiceprint file deleted for user \(userId)")
                return true
            } else {
                print("Voiceprint file not found for user \(userId)")
                return false
            }
        } catch {
            print("Failed to delete voiceprint file for user \(userId): \(error)")
            return false
        }
    }
    
    /// Check if user has voiceprint file
    /// - Parameter userId: User ID
    /// - Returns: Whether user has voiceprint file
    func hasVoiceprint(forUserId userId: String) -> Bool {
        let fileName = "\(userId).json"
        let fileURL = voiceprintDirectory.appendingPathComponent(fileName)
        return fileManager.fileExists(atPath: fileURL.path)
    }
}
