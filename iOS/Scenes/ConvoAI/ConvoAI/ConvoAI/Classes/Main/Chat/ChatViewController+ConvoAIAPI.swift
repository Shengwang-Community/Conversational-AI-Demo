//
//  ChatViewController+ConvoAIAPIHandler.swift
//  ConvoAI
//
//  Created by qinhui on 2025/7/1.
//

import Foundation
import Common

// MARK: - Image Upload Error Models
struct ImageUploadError: Codable {
    let code: Int
    let message: String
}

struct ImageUploadErrorResponse: Codable {
    let uuid: String
    let success: Bool
    let error: ImageUploadError?
}

struct PictureInfo: Codable {
    let uuid: String
}

// MARK: - ConversationalAIAPIEventHandler
extension ChatViewController {
    internal func sendImage(image: UIImage, isResend: Bool = false, uuid: String) {
        // Convert UIImage to Data
        addLog(">>>>[sendImage]")
        guard let imageData = image.jpegData(compressionQuality: 1) else {
            addLog(">>>>[jpegData] Failed to convert image to data")
            return
        }
                
        // Add image message to UI first
        if !isResend {
            self.messageView.viewModel.addImageMessage(uuid: uuid, image: image)
        }
        
        // Upload image
        NetworkManager.shared.uploadImage(
            requestId: uuid,
            channelName: channelName,
            imageData: imageData
        ) { [weak self] imageUrl in
            guard let self = self else { return }
            // Upload success
            self.addLog("<<<<<[uploadImage] Image upload successful, url: \(imageUrl ?? "nil")， uuid: \(uuid)")
            
            let message = ImageMessage(uuid: uuid, url: imageUrl)
            self.convoAIAPI.show(agentUserId: "\(agentUid)", message: message) { [weak self] error in
                if let error = error {
                    self?.addLog("<<<<<[sendImage] send image failed, error: \(error.message)")
                } else {
                    self?.addLog("<<<<<[sendImage] send image success")
                }
            }
        } failure: { [weak self] error in
            // Upload failed
            self?.addLog("<<<<<[uploadImage] Image upload failed: \(error)")
            // Update UI to show error state
            DispatchQueue.main.async {
                self?.messageView.viewModel.updateImageMessage(uuid: uuid, state: .failed)
            }
        }
    }
}

extension ChatViewController: ConversationalAIAPIEventHandler {
    public func onMessageReceiptUpdated(agentUserId: String, messageReceipt: MessageReceipt) {
        if messageReceipt.type == .context {
            guard let messageData = messageReceipt.message.data(using: .utf8) else {
                return
            }
            
            do {
                let imageInfo = try JSONDecoder().decode(PictureInfo.self, from: messageData)
                let uuid = imageInfo.uuid
                addLog("<<<<<onMessageReceiptUpdated: uuid: \(uuid)")
                self.messageView.viewModel.updateImageMessage(uuid: uuid, state: .success)
            } catch {
                addLog("Failed to decode PictureInfo: \(error)")
            }

          ConvoAILogger.error("Failed to parse message string from image info message")
          return
      }
        
    }
    
    public func onAgentStateChanged(agentUserId: String, event: StateChangeEvent) {
        agentStateView.setState(event.state)
        volumeAnimateView.setState(event.state)
    }
    
    public func onAgentInterrupted(agentUserId: String, event: InterruptEvent) {
        
    }
    
    public func onAgentMetrics(agentUserId: String, metrics: Metric) {
        addLog("<<< [onAgentMetrics] metrics: \(metrics)")
    }
    
    public func onAgentError(agentUserId: String, error: ModuleError) {
        if error.type == .context {
            // Parse image upload error from error.message
            if let messageData = error.message.data(using: .utf8) {
                do {
                    let errorResponse = try JSONDecoder().decode(ImageUploadErrorResponse.self, from: messageData)
                    if !errorResponse.success {
                        let errorMessage = errorResponse.error?.message ?? "Unknown error"
                        let errorCode = errorResponse.error?.code ?? 0
                        
                        addLog("<<< [ImageUploadError] Image upload failed: \(errorMessage) (code: \(errorCode))")
                        
                        // Update UI to show error state
                        DispatchQueue.main.async { [weak self] in
                            self?.messageView.viewModel.updateImageMessage(uuid: errorResponse.uuid, state: .failed)
                        }
                    }
                } catch {
                    addLog("<<< [onAgentError] Failed to parse error message JSON: \(error)")
                }
            }
        }
        addLog("<<< [onAgentError] error: \(error)")
    }
    
    public func onTranscriptionUpdated(agentUserId: String, transcription: Transcription) {
        if isSelfSubRender {
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.messageView.viewModel.reduceStandardMessage(turnId: transcription.turnId, message: transcription.text, timestamp: 0, owner: transcription.type, isInterrupted: transcription.status == .interrupted)
        }
    }
    
    public func onDebugLog(_ log: String) {
        addLog(log)
    }
}
