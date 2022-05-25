#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint tnexekyc.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'tnexekyc'
  s.version          = '0.0.2'
  s.summary          = 'A new flutter plugin project.'
  s.description      = <<-DESC
A new flutter plugin project.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter' 
  s.dependency 'MLKitVision'
  s.dependency 'GoogleMLKit/FaceDetection', '~> 2.6.0'
  s.static_framework = true
  s.platform = :ios, '11.0'


  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 
	'DEFINES_MODULE' => 'YES',
	'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) PERMISSION_CAMERA=1',
	'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' 
}
  s.swift_version = '5.0'
end
