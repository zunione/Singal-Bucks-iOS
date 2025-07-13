// SingalBucksApp.swift
// 앱의 메인 진입점 - 안드로이드의 MainActivity와 유사한 역할
// Firebase 초기화 및 앱 라이프사이클 관리

import SwiftUI
import Firebase

// MARK: - 메인 앱 구조체
@main
struct SingalBucksApp: App {
    
    // 앱 델리게이트 연결 (Firebase 설정용)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.light) // 라이트 모드 고정
        }
    }
}

// MARK: - 앱 델리게이트 (Firebase 초기화)
class AppDelegate: NSObject, UIApplicationDelegate {
    
    func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        // Firebase 초기화 - Python의 init_firebase()와 동일
        FirebaseApp.configure()
        
        print("🔥 Firebase 초기화 완료")
        
        return true
    }
}

// MARK: - 메인 콘텐츠 뷰
struct ContentView: View {
    
    // 현재 선택된 앱 모드
    @State private var selectedApp: AppMode? = nil
    
    var body: some View {
        Group {
            if let selectedApp = selectedApp {
                // 선택된 앱 화면 표시
                switch selectedApp {
                case .customer:
                    OrderView()
                        .transition(.slide)
                case .kitchen:
                    KitchenView()
                        .transition(.slide)
                }
            } else {
                // 앱 선택 화면
                AppSelectionView(selectedApp: $selectedApp)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: selectedApp)
    }
}

// MARK: - 앱 모드 열거형
enum AppMode: String, CaseIterable {
    case customer = "customer"
    case kitchen = "kitchen"
    
    var displayName: String {
        switch self {
        case .customer: return "고객용 주문"
        case .kitchen: return "주방 관리"
        }
    }
    
    var icon: String {
        switch self {
        case .customer: return "cup.and.saucer.fill"
        case .kitchen: return "chef.hat.fill"
        }
    }
    
    var description: String {
        switch self {
        case .customer: return "음료와 간식을 주문하세요"
        case .kitchen: return "주문을 확인하고 관리하세요"
        }
    }
    
    var color: Color {
        switch self {
        case .customer: return .blue
        case .kitchen: return .orange
        }
    }
}

// MARK: - 앱 선택 화면
struct AppSelectionView: View {
    @Binding var selectedApp: AppMode?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 40) {
                
                // 앱 로고 및 제목
                VStack(spacing: 20) {
                    // 로고 (이미지가 있다면 교체)
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.brown)
                    
                    Text("Singal Bucks")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("iPad 전용 카페 관리 시스템")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // 앱 모드 선택 카드들
                VStack(spacing: 20) {
                    ForEach(AppMode.allCases, id: \.self) { mode in
                        AppModeCard(mode: mode) {
                            selectedApp = mode
                        }
                    }
                }
                
                Spacer()
                
                // 하단 정보
                VStack(spacing: 8) {
                    Text("개발자: 신갈벅스 팀")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("버전 1.0.0")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .navigationTitle("")
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

// MARK: - 앱 모드 선택 카드
struct AppModeCard: View {
    let mode: AppMode
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            // 햅틱 피드백 (진동)
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
            action()
        }) {
            HStack(spacing: 20) {
                // 아이콘
                Image(systemName: mode.icon)
                    .font(.system(size: 40))
                    .foregroundColor(mode.color)
                    .frame(width: 60, height: 60)
                
                // 텍스트 정보
                VStack(alignment: .leading, spacing: 8) {
                    Text(mode.displayName)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text(mode.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                // 화살표
                Image(systemName: "chevron.right")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(
                        color: mode.color.opacity(0.3),
                        radius: isPressed ? 8 : 4,
                        x: 0,
                        y: isPressed ? 4 : 2
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - Preview
#Preview("앱 선택 화면") {
    AppSelectionView(selectedApp: .constant(nil))
}

#Preview("고객용 앱") {
    OrderView()
}

#Preview("주방용 앱") {
    KitchenView()
}
