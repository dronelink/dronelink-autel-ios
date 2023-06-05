Pod::Spec.new do |s|
  s.name = "DronelinkAutel"
  s.version = "1.0.0"
  s.summary = "Dronelink vendor implementation for Autel"
  s.homepage = "https://dronelink.com/"
  s.license = { :type => "MIT", :file => "LICENSE" }
  s.author = { "Dronelink" => "dev@dronelink.com" }
  s.swift_version = "5.0"
  s.platform = :ios
  s.ios.deployment_target  = "12.0"
  s.source = { :git => "https://github.com/dronelink/dronelink-autel-ios.git", :tag => "#{s.version}" }
  s.source_files  = "DronelinkAutel/**/*.swift"
  s.vendored_frameworks = "DronelinkAutel/Resources/AUTELSDK.xcframework"
  s.resources = "DronelinkAutel/**/*.{strings}"
  s.pod_target_xcconfig = { 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64'}
  s.dependency "DronelinkCore", "~> 4.6.0"
end
