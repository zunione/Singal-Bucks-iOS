// OrderView.swift
// 고객용 주문 화면 - Python의 order.py와 동일한 기능
// SwiftUI를 사용한 선언적 UI 구성 (안드로이드의 Compose와 유사)

import SwiftUI
import Firebase

// MARK: - 메인 주문 화면
struct OrderView: View {
    
    // MARK: - State 변수들 (안드로이드의 LiveData/StateFlow와 유사)
    
    // Firebase 연결 상태 관찰
    @StateObject private var firebaseManager = FirebaseManager.shared
    
    // 메뉴 데이터 - Python 코드의 drinks, snacks와 동일
    private let drinks = [
        "뜨아": 3000,
        "아아": 3000,
        "레모네이드": 3000,
        "아이스티": 3000
    ]
    
    private let snacks = [
        "핫도그": 3500,
        "컵볶이": 3500
    ]
    
    // 주문 수량 상태 - Python의 order_counts와 동일
    @State private var orderCounts: [String: Int] = [:]
    
    // UI 상태 관리
    @State private var showingOrderConfirmation = false
    @State private var showingSuccessAlert = false
    @State private var showingErrorAlert = false
    @State private var alertMessage = ""
    @State private var lastOrderNumber: Int?
    @State private var isPlacingOrder = false
    
    // 계산된 속성들
    
    // 총 금액 계산 - Python의 calculate_total()과 동일
    private var totalAmount: Int {
        let drinkCount = drinks.keys.reduce(0) { total, drink in
            total + (orderCounts[drink] ?? 0)
        }
        
        let snackCount = snacks.keys.reduce(0) { total, snack in
            total + (orderCounts[snack] ?? 0)
        }
        
        // 세트 할인 계산
        let setCount = min(drinkCount, snackCount)
        let remainingDrinks = drinkCount - setCount
        let remainingSnacks = snackCount - setCount
        
        return (setCount * 5500) + (remainingDrinks * 3000) + (remainingSnacks * 3500)
    }
    
    // 주문 가능 여부 확인
    private var hasItems: Bool {
        orderCounts.values.contains { $0 > 0 }
    }
    
    // MARK: - Body (UI 구성)
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    
                    // 상단 헤더
                    headerSection
                    
                    // Firebase 연결 상태
                    connectionStatusSection
                    
                    // 메뉴 섹션들
                    menuSections
                    
                    // 세트 안내
                    setInfoSection
                    
                    // 총 금액 및 주문 버튼
                    orderSummarySection
                    
                }
                .padding()
            }
            .navigationTitle("☕ Singal Bucks")
            .navigationBarTitleDisplayMode(.large)
        }
        // iPad 최적화 - 세로/가로 모두 지원
        .navigationViewStyle(StackNavigationViewStyle())
        
        // 주문 확인 알럿
        .alert("주문 확인", isPresented: $showingOrderConfirmation) {
            Button("취소", role: .cancel) { }
            Button("주문하기") {
                Task {
                    await placeOrder()
                }
            }
        } message: {
            Text(orderSummaryText)
        }
        
        // 성공 알럿
        .alert("🎉 주문 완료!", isPresented: $showingSuccessAlert) {
            Button("확인") {
                resetOrder()
            }
        } message: {
            if let orderNumber = lastOrderNumber {
                Text("주문번호: \(orderNumber)번\n총 금액: \(totalAmount.formatted())원\n\n주문번호를 기억해주세요!")
            }
        }
        
        // 에러 알럿
        .alert("주문 실패", isPresented: $showingErrorAlert) {
            Button("확인") { }
        } message: {
            Text(alertMessage)
        }
        
        // 화면 로드 시 초기화
        .onAppear {
            initializeOrderCounts()
        }
    }
}

// MARK: - UI 컴포넌트들 (Extension으로 분리하여 가독성 향상)
extension OrderView {
    
    // 상단 헤더 섹션
    private var headerSection: some View {
        VStack(spacing: 10) {
            Text("☕ Singal Bucks 주문하기 ☕")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            Text("맛있는 음료와 간식을 주문하세요!")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
    }
    
    // Firebase 연결 상태 섹션
    private var connectionStatusSection: some View {
        HStack {
            Circle()
                .fill(firebaseManager.isConnected ? Color.green : Color.red)
                .frame(width: 8, height: 8)
            
            Text(firebaseManager.connectionStatus)
                .font(.caption)
                .foregroundColor(firebaseManager.isConnected ? .green : .red)
        }
    }
    
    // 메뉴 섹션들
    private var menuSections: some View {
        VStack(spacing: 30) {
            // 음료 섹션
            MenuSectionView(
                title: "🥤 음료 (3,000원)",
                items: drinks,
                orderCounts: $orderCounts
            )
            
            // 간식 섹션
            MenuSectionView(
                title: "🍽️ 간식 (3,500원)",
                items: snacks,
                orderCounts: $orderCounts
            )
        }
    }
    
    // 세트 안내 섹션
    private var setInfoSection: some View {
        VStack(spacing: 8) {
            Text("💡 세트 메뉴 안내")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("음료 + 간식 세트: 5,500원")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.green)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .cornerRadius(12)
    }
    
    // 주문 요약 및 버튼 섹션
    private var orderSummarySection: some View {
        VStack(spacing: 20) {
            // 총 금액 표시
            Text("총 금액: \(totalAmount.formatted())원")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.red)
                .padding()
                .background(Color(.systemGroupedBackground))
                .cornerRadius(12)
            
            // 주문 버튼
            Button(action: {
                if hasItems {
                    showingOrderConfirmation = true
                }
            }) {
                HStack {
                    if isPlacingOrder {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "cart.fill")
                    }
                    
                    Text(isPlacingOrder ? "주문 중..." : "🛒 주문하기")
                        .fontWeight(.bold)
                }
                .font(.title2)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .background(hasItems && firebaseManager.isConnected && !isPlacingOrder ? Color.blue : Color.gray)
                .cornerRadius(12)
            }
            .disabled(!hasItems || !firebaseManager.isConnected || isPlacingOrder)
        }
    }
    
    // 주문 요약 텍스트
    private var orderSummaryText: String {
        var summary = "주문 내역:\n\n"
        
        for (item, count) in orderCounts where count > 0 {
            summary += "• \(item) x\(count)\n"
        }
        
        summary += "\n총 금액: \(totalAmount.formatted())원"
        return summary
    }
}

// MARK: - 메서드들
extension OrderView {
    
    // 주문 수량 초기화
    private func initializeOrderCounts() {
        var counts: [String: Int] = [:]
        
        for drink in drinks.keys {
            counts[drink] = 0
        }
        for snack in snacks.keys {
            counts[snack] = 0
        }
        
        orderCounts = counts
    }
    
    // 주문 실행 - Python의 place_order()와 동일
    private func placeOrder() async {
        guard firebaseManager.isConnected else {
            alertMessage = "Firebase 연결이 되지 않았습니다.\n인터넷 연결을 확인해주세요."
            showingErrorAlert = true
            return
        }
        
        // 주문 항목 필터링
        let orderItems = orderCounts.filter { $0.value > 0 }
        
        guard !orderItems.isEmpty else {
            alertMessage = "주문할 상품을 선택해주세요!"
            showingErrorAlert = true
            return
        }
        
        isPlacingOrder = true
        
        // Firebase에 전송할 데이터 구성
        let orderData: [String: Any] = [
            "items": orderItems,
            "total_amount": totalAmount
        ]
        
        // Firebase에 주문 전송
        let result = await firebaseManager.placeOrder(orderData: orderData)
        
        DispatchQueue.main.async {
            self.isPlacingOrder = false
            
            if result.success {
                self.lastOrderNumber = result.orderNumber
                self.showingSuccessAlert = true
            } else {
                self.alertMessage = result.error ?? "알 수 없는 오류가 발생했습니다."
                self.showingErrorAlert = true
            }
        }
    }
    
    // 주문 초기화 - Python의 reset_order()와 동일
    private func resetOrder() {
        for key in orderCounts.keys {
            orderCounts[key] = 0
        }
    }
}

// MARK: - 메뉴 섹션 컴포넌트
// 재사용 가능한 메뉴 섹션 뷰 (안드로이드의 RecyclerView Item과 유사)
struct MenuSectionView: View {
    let title: String
    let items: [String: Int]
    @Binding var orderCounts: [String: Int]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            // 섹션 제목
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal)
            
            // 메뉴 아이템들 - iPad 최적화: 2열 그리드
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 15) {
                ForEach(Array(items.keys.sorted()), id: \.self) { itemName in
                    MenuItemView(
                        name: itemName,
                        price: items[itemName] ?? 0,
                        count: Binding(
                            get: { orderCounts[itemName] ?? 0 },
                            set: { orderCounts[itemName] = $0 }
                        )
                    )
                }
            }
            .padding(.horizontal)
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .cornerRadius(12)
    }
}

// MARK: - 메뉴 아이템 컴포넌트
// 개별 메뉴 아이템 뷰 (안드로이드의 ViewHolder와 유사)
struct MenuItemView: View {
    let name: String
    let price: Int
    @Binding var count: Int
    
    var body: some View {
        VStack(spacing: 12) {
            // 상품명과 가격
            VStack(spacing: 4) {
                Text(name)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("\(price.formatted())원")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // 수량 조절 버튼들
            HStack(spacing: 15) {
                // 감소 버튼
                Button(action: {
                    if count > 0 {
                        count -= 1
                    }
                }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundColor(count > 0 ? .red : .gray)
                }
                .disabled(count <= 0)
                
                // 수량 표시
                Text("\(count)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .frame(minWidth: 30)
                
                // 증가 버튼
                Button(action: {
                    count += 1
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Int Extension (숫자 포맷팅)
extension Int {
    func formatted() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}

// MARK: - Preview
// SwiftUI 미리보기 (안드로이드 Studio의 Preview와 유사)
#Preview {
    OrderView()
}