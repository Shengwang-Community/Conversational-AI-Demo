//
//  KeyCenter.swift
//  OpenLive
//
//  Created by GongYuhua on 6/25/16.
//  Copyright © 2016 Agora. All rights reserved.
//

struct KeyCenter {
    
#if MainLand
    /**
     Agora APP ID.
     Agora assigns App IDs to app developers to identify projects and organizations.
     If you have multiple completely separate apps in your organization, for example built by different teams,
     you should use different App IDs.
     If applications need to communicate with each other, they should use the same App ID.
     In order to get the APP ID, you can open the agora console (https://console.agora.io/) to create a project,
     then the APP ID can be found in the project detail page.
     声网APP ID
     Agora 给应用程序开发人员分配 App ID，以识别项目和组织。如果组织中有多个完全分开的应用程序，例如由不同的团队构建，
     则应使用不同的 App ID。如果应用程序需要相互通信，则应使用同一个App ID。
     进入声网控制台(https://console.agora.io/)，创建一个项目，进入项目配置页，即可看到APP ID。
     */
    static let AppId: String = ""
    
    /**
     Certificate.
     Agora provides App certificate to generate Token. You can deploy and generate a token on your server,
     or use the console to generate a temporary token.
     In order to get the APP ID, you can open the agora console (https://console.agora.io/) to create a project with the App Certificate enabled,
     then the APP Certificate can be found in the project detail page.
     PS: If the project does not have certificates enabled, leave this field blank.
     声网APP证书
     Agora 提供 App certificate 用以生成 Token。您可以在您的服务器部署并生成，或者使用控制台生成临时的 Token。
     进入声网控制台(https://console.agora.io/)，创建一个带证书鉴权的项目，进入项目配置页，即可看到APP证书。
     注意：如果项目没有开启证书鉴权，这个字段留空。
     */
    static let Certificate: String? = ""


    /**
     Worker service address
     To start and stop the agent, please fill in your host address. Can be filled in: http://104.42.227.71:8083 Display the demonstration effect
     Agent的服务地址
     用于启动和停止Agent，请填写您的主机地址。demo演示地址：http://104.42.227.71:8083
     */

    static var DebugHostUrl: String = "https://toolbox-staging.sh3t.agoralab.co/v2"

    static var ReleaseHostUrl: String = "https://service.agora.io/toolbox"
    static var BaseHostUrl: String = DebugHostUrl
    static var TermsOfService: String = "https://www.agora.io/en/terms-of-service/"
#else
    /**
     Agora APP ID.
     Agora assigns App IDs to app developers to identify projects and organizations.
     If you have multiple completely separate apps in your organization, for example built by different teams,
     you should use different App IDs.
     If applications need to communicate with each other, they should use the same App ID.
     In order to get the APP ID, you can open the agora console (https://console.agora.io/) to create a project,
     then the APP ID can be found in the project detail page.
     声网APP ID
     Agora 给应用程序开发人员分配 App ID，以识别项目和组织。如果组织中有多个完全分开的应用程序，例如由不同的团队构建，
     则应使用不同的 App ID。如果应用程序需要相互通信，则应使用同一个App ID。
     进入声网控制台(https://console.agora.io/)，创建一个项目，进入项目配置页，即可看到APP ID。
     */
    static let AppId: String = ""
    
    /**
     Certificate.
     Agora provides App certificate to generate Token. You can deploy and generate a token on your server,
     or use the console to generate a temporary token.
     In order to get the APP ID, you can open the agora console (https://console.agora.io/) to create a project with the App Certificate enabled,
     then the APP Certificate can be found in the project detail page.
     PS: If the project does not have certificates enabled, leave this field blank.
     声网APP证书
     Agora 提供 App certificate 用以生成 Token。您可以在您的服务器部署并生成，或者使用控制台生成临时的 Token。
     进入声网控制台(https://console.agora.io/)，创建一个带证书鉴权的项目，进入项目配置页，即可看到APP证书。
     注意：如果项目没有开启证书鉴权，这个字段留空。
     */
    static let Certificate: String? = ""


    static var DebugHostUrl: String = "https://toolbox-global-staging.la3d.agoralab.co/v2"

    static var ReleaseHostUrl: String = "https://service.agora.io/toolbox-overseas"
    static var BaseHostUrl: String = DebugHostUrl
    static var TermsOfService: String = "https://www.agora.io/en/terms-of-service/"
#endif
}
