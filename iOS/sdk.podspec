Pod::Spec.new do |spec|
   spec.name          = "ShengwangRtcEngine_iOS"
   spec.version       = "4.6.4"
   spec.summary       = "Shengwang iOS video SDK"
   spec.description   = "iOS library for shengwang A/V communication, broadcasting and data channel service."
   spec.homepage      = "https://docs.agora.io/en/Agora%20Platform/downloads"
   spec.license       = { "type" => "Copyright", "text" => "Copyright 2018 agora.io. All rights reserved.\n"}
   spec.author        = { "Agora Lab" => "developer@agora.io" }
   spec.platform      = :ios
   spec.source        = { :git => "" }
   spec.vendored_frameworks = "libs/*.xcframework"
   spec.requires_arc  = true
   spec.ios.deployment_target  = '15.0'
 end
