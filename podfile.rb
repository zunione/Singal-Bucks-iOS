# Podfile - Firebase 연동을 위한 CocoaPods 설정 파일
# 이 파일을 프로젝트 루트 디렉토리에 생성하세요

platform :ios, '15.0'

target 'singalbucks' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # Firebase SDK들 - 안드로이드의 gradle dependencies와 유사
  pod 'Firebase/Analytics'      # Firebase 기본 분석
  pod 'Firebase/Database'       # Realtime Database (Python의 firebase_admin.db와 동일)
  pod 'Firebase/Auth'          # 인증 (필요시)

end

# 빌드 후 스크립트 - 안드로이드의 proguard와 유사한 최적화
post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
    end
  end
end
