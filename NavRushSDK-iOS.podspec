#
# Be sure to run `pod lib lint NavRushSDK.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'NavRushSDK-iOS'
  s.version          = '0.1.0'
  s.summary          = 'iOS-SDK for NavRush - localisation framework'

  s.description      = <<-DESC
NavRush SDK is cross-platform unified localisation Indoor-Outdoor solution. Please read more at http://www.navrush.com
                       DESC

  s.homepage         = 'https://www.navrush.com/'
  s.license          = { :type => 'Commercial', :file => 'LICENSE' }
  s.author           = { 'Bullrush Apps' => 'developers@bullrush.app' }
  s.source           = { :git => 'https://github.com/bullrush-apps/NAVRushSDK-iOS.git', :tag => s.version.to_s }
  s.swift_version = '4.2'
  s.ios.deployment_target = '10.0'
  s.source_files = 'NavRushSDK-iOS/Classes/**/*'

  s.dependency 'Alamofire', '4.8.1'
  s.dependency 'AlamofireObjectMapper', '~> 5.2'
  s.dependency 'thenPromise', '4.2.1'
  s.dependency 'SwifterSwift/SwiftStdlib'
  s.dependency 'SwifterSwift/Foundation'
  s.dependency 'Starscream', '~> 3.0.2'
  s.dependency 'Disk', '~> 0.4.0'
  s.dependency 'NavRushFramework', '1.0.1'
end
