//
//  Logger.swift
//  VoiceAgent
//
//  Created by qinhui on 2025/2/16.
//

import Foundation

public class CommonLogger: NSObject {
    static let kLogKey = "Common"

    public static func info(_ text: String, context: String? = nil) {
        agoraDoMainThreadTask {
            AgoraEntLog.getSceneLogger(with: kLogKey).info(text, context: context)
        }
    }

    public static func warn(_ text: String, context: String? = nil) {
        agoraDoMainThreadTask {
            AgoraEntLog.getSceneLogger(with: kLogKey).warning(text, context: context)
        }
    }

    public static func error(_ text: String, context: String? = nil) {
        agoraDoMainThreadTask {
            AgoraEntLog.getSceneLogger(with: kLogKey).error(text, context: context)
        }
    }
}
