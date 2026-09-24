#
# Be sure to run `pod lib lint ShowTo1v1.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'IoT'
  s.version          = '0.1.0'
  s.summary          = 'A short description of IoT.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
TODO: Add long description of the pod here.
                       DESC

  s.homepage         = 'https://github.com/AgoraIO-Community/Agent'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Agora Lab' => 'developer@agora.io' }
  s.source           = { :git => 'https://github.com/AgoraIO-Community/Agent.git', :tag => s.version.to_s }

  s.ios.deployment_target = '15.0'
  
  s.xcconfig = {'ENABLE_BITCODE' => 'NO'}
  
  s.static_framework = true
  s.swift_version = '5.0'

  s.source_files = 'IoT/Classes/**/*'
  s.resource = 'IoT/Resources/*.bundle'
  s.resource_bundles = {
    'IoT' => [
      'IoT/Assets/**/*',
      'IoT/Resources/**/*'
    ]
  }
  
  s.dependency 'SnapKit'
  s.dependency 'SVProgressHUD'
  s.dependency 'ShengwangRtcEngine_iOS'
  s.dependency 'SwifterSwift/UIKit', '6.2.0'
  s.dependency 'Common'
  s.dependency 'Kingfisher'
  s.dependency 'BLEManager'

end
