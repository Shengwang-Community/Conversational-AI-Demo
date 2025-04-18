//
//  KeyCenter.swift
//  OpenLive
//
//  Created by GongYuhua on 6/25/16.
//  Copyright © 2016 Agora. All rights reserved.
//

struct KeyCenter {
    /**
     Demo Server
     demo server is only for testing, not for production environment, please use your own server for production
    */
    static var TOOLBOX_SERVER_HOST: String = "https://service.apprtc.cn/toolbox"
    
    /**
     Agora Key
     get from Agora Console
     */
    static let AG_APP_ID: String = ""
    static let AG_APP_CERTIFICATE: String = ""
    
    /**
     Basic Auth
     Get from Agora Console
     */
    static let BASIC_AUTH_KEY: String = ""
    static let BASIC_AUTH_SECRET: String = ""
    
    /**
     LLM
     Get from LLM vendor
     For example:
     static let LLM_URL: String="https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions"
     static let LLM_API_KEY: String="1234567890"
     static let LLM_SYSTEM_MESSAGES: [[String: Any]] = [
        [
         "role": "system",
         "content":  "You are a helpful chatbot."
        ]
     ]
     static let LLM_PARAMS: [String: Any] = [
         "model": "qwen-max"
     ]
     */
    static let LLM_URL: String = ""
    static let LLM_API_KEY: String = ""
    static let LLM_SYSTEM_MESSAGES: [[String: Any]] = []
    static let LLM_PARAMS: [String: Any] = [:]

    /**
     TTS
     Get from TTS vendor
     For example:
     https://github.com/Shengwang-Community/Conversational-AI-Demo/issues/28
     
     static let TTS_VENDOR: String = "bytedance"
     static let TTS_PARAMS: [String : Any] = [
         "token": "***",
         "app_id": "***",
         "cluster": "***",
         "voice_type": "***",
         "speed_ratio": 1.0,
         "volume_ratio": 1.0,
         "pitch_ratio": 1.0,
         "emotion": "happy",
         "rate": 24000
     ]
     */
    static let TTS_VENDOR: String = ""
    static let TTS_PARAMS: [String : Any] = [:]
        
}

