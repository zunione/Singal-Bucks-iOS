// KitchenView.swift
// 주방용 관리 화면 - Python의 kitchen.py와 동일한 기능
// 실시간 주문 모니터링 및 상태 업데이트

import SwiftUI
import Firebase

// MARK: - 주방 관리 메인 화면
struct KitchenView: View {
    
    // MARK: - State 변수들
    
    // Firebase 연결 관리
    @StateObject private var firebaseManager = FirebaseManager.shared
    
    // 주문 데이터 - Python의 orders 딕셔너리와 동일
    @State private var orders: [OrderModel] = []
    
    // UI 상태
    @State private var showingOrderDetails: OrderModel?
    @State private var isRefreshing = false
    @State private var lastUpdateTime = Date()
    
    // 필터링된 주문들 (상태별로 분류)
    private var pendingOrders: [OrderModel] {
        orders.filter { $0.status == .pending }.sorted { $0.orderNumber < $1.orderNumber }
    }
    
    private var madeOrders: [OrderModel] {
        orders.filter { $0.status == .made }.sorted { $0.orderNumber < $1.orderNumber }
    }
    
    private var servedOrders: [OrderModel] {
        orders.filter { $0.status == .served }.sorted { $0.orderNumber > $1.orderNumber }
    }
    
    // MARK: - Body (UI 구성)
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                
                // 상단 헤더
                headerSection
                
                // 주문 현황 카드들 - iPad 최적화: 3열 그리드
                orderStatusGrid
                
            }
            .navigationTitle("🍳 주방 관리")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    refreshButton
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        
        // 주문 상세 정보 시트
        .sheet(item: $showingOrderDetails) { order in
            OrderDetailSheet(order: order) {
                // 상태 업데이트 후 새로고침
                Task {
                    await refreshOrders()
                }
            }
        }
        
        // 화면 로드 시 실시간 리스너 설정
        .onAppear {
            setupRealtimeListener()
        }
        
        // 화면 사라질 때 리스너 정리
        .onDisappear {
            firebaseManager.removeAllObservers()
        }
    }
}

// MARK: - UI 컴포넌트들
extension KitchenView {
    
    // 상단 헤더 섹션
    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                // Firebase 연결 상태
                HStack(spacing: 8) {
                    Circle()
                        .fill(firebaseManager.isConnected ? Color.green : Color.red)
                        .frame(width: 10, height: 10)
                    
                    Text(firebaseManager.connectionStatus)
                        .font(.caption)
                        .foregroundColor(firebaseManager.isConnected ? .green : .red)
                }
                
                Spacer()
                
                // 마지막 업데이트 시간
                Text("업데이트: \(lastUpdateTime, formatter: timeFormatter)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // 전체 주문 통계
            HStack(spacing: 20) {
                StatisticCard(title: "대기", count: pendingOrders.count, color: .red)
                StatisticCard(title: "제조완료", count: madeOrders.count, color: .orange)
                StatisticCard(title: "서빙완료", count: servedOrders.count, color: .green)
            }
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }
    
    // 새로고침 버튼
    private var refreshButton: some View {
        Button(action: {
            Task {
                await refreshOrders()
            }
        }) {
            Image(systemName: isRefreshing ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                .foregroundColor(.blue)
                .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                .animation(.linear(duration: 1).repeatCount(isRefreshing ? .max : 1, autoreverses: false), value: isRefreshing)
        }
        .disabled(isRefreshing)
    }
    
    // 주문 상태별 그리드
    private var orderStatusGrid: some View {
        ScrollView {
            HStack(alignment: .top, spacing: 16) {
                
                // 제조 전 (빨간색)
                OrderColumnView(
                    title: "🔴 제조 전",
                    orders: pendingOrders,
                    backgroundColor: Color.red.opacity(0.1),
                    titleColor: .red
                ) { order in
                    showingOrderDetails = order
                }
                
                // 제조 완료 (노란색)
                OrderColumnView(
                    title: "🟡 제조 완료",
                    orders: madeOrders,
                    backgroundColor: Color.orange.opacity(0.1),
                    titleColor: .orange
                ) { order in
                    showingOrderDetails = order
                }
                
                // 서빙 완료 (초록색)
                OrderColumnView(
                    title: "🟢 서빙 완료",
                    orders: servedOrders,
                    backgroundColor: Color.green.opacity(0.1),
                    titleColor: .green
                ) { order in
                    showingOrderDetails = order
                }
            }
            .padding()
        }
    }
    
    // 시간 포맷터
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }
}

// MARK: - 메서드들
extension KitchenView {
    
    // 실시간 Firebase 리스너 설정 - Python의 start_firebase_listener()와 동일
    private func setupRealtimeListener() {
        firebaseManager.observeOrders { [self] ordersData in
            DispatchQueue.main.async {
                self.processOrdersData(ordersData)
                self.lastUpdateTime = Date()
            }
        }
    }
    
    // Firebase 데이터를 OrderModel 배열로 변환
    private func processOrdersData(_ data: [String: Any]) {
        var newOrders: [OrderModel] = []
        
        for (orderNumber, orderData) in data {
            if let orderDict = orderData as? [String: Any],
               let order = OrderModel(id: orderNumber, data: orderDict) {
                newOrders.append(order)
            }
        }
        
        // 새 주문 알림 (기존 주문과 비교)
        let newOrderNumbers = Set(newOrders.map { $0.orderNumber })
        let oldOrderNumbers = Set(orders.map { $0.orderNumber })
        let addedOrders = newOrderNumbers.subtracting(oldOrderNumbers)
        
        if !addedOrders.isEmpty {
            for orderNumber in addedOrders {
                print("🔔 새 주문 도착: \(orderNumber)번")
                // 필요시 알림 소리나 진동 추가 가능
            }
        }
        
        orders = newOrders
    }
    
    // 수동 새로고침
    private func refreshOrders() async {
        isRefreshing = true
        
        // 최소 1초 딜레이 (사용자 경험 향상)
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        DispatchQueue.main.async {
            self.isRefreshing = false
            self.lastUpdateTime = Date()
        }
    }
}

// MARK: - 통계 카드 컴포넌트
struct StatisticCard: View {
    let title: String
    let count: Int
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(minWidth: 60)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - 주문 컬럼 뷰 (각 상태별 주문 목록)
struct OrderColumnView: View {
    let title: String
    let orders: [OrderModel]
    let backgroundColor: Color
    let titleColor: Color
    let onOrderTap: (OrderModel) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            // 컬럼 제목
            Text(title)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(titleColor)
                .padding(.horizontal)
            
            // 주문 카드들
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(orders) { order in
                        OrderCardView(order: order)
                            .onTapGesture {
                                onOrderTap(order)
                            }
                    }
                }
                .padding(.horizontal, 8)
            }
            
            if orders.isEmpty {
                Text("주문이 없습니다")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
        }
        .frame(maxWidth: .infinity)
        .background(backgroundColor)
        .cornerRadius(12)
    }
}

// MARK: - 주문 카드 컴포넌트 (Python의 create_order_card와 동일)
struct OrderCardView: View {
    let order: OrderModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            
            // 주문번호와 시간
            HStack {
                Text("#\(order.orderNumber)번")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
                
                Spacer()
                
                Text(order.formattedTime)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // 주문 항목들
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(order.items.keys.sorted()), id: \.self) { itemName in
                    if let quantity = order.items[itemName] {
                        HStack {
                            Text("• \(itemName)")
                                .font(.body)
                            
                            Spacer()
                            
                            Text("x\(quantity)")
                                .font(.body)
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
            
            // 총 금액
            Text("총 \(order.totalAmount.formatted())원")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.red)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 4)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

// MARK: - 주문 상세 시트 (버튼 포함)
struct OrderDetailSheet: View {
    let order: OrderModel
    let onStatusUpdate: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var isUpdating = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                
                // 주문 정보
                VStack(spacing: 16) {
                    Text("주문 #\(order.orderNumber)")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    
                    Text("주문 시간: \(order.formattedTime)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    // 주문 항목들
                    VStack(alignment: .leading, spacing: 8) {
                        Text("주문 내역:")
                            .font(.headline)
                            .padding(.bottom, 4)
                        
                        ForEach(Array(order.items.keys.sorted()), id: \.self) { itemName in
                            if let quantity = order.items[itemName] {
                                HStack {
                                    Text("• \(itemName)")
                                    Spacer()
                                    Text("x\(quantity)")
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGroupedBackground))
                    .cornerRadius(12)
                    
                    // 총 금액
                    Text("총 금액: \(order.totalAmount.formatted())원")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                        .padding()
                        .background(Color(.systemGroupedBackground))
                        .cornerRadius(12)
                }
                
                Spacer()
                
                // 상태 업데이트 버튼들
                VStack(spacing: 12) {
                    if !order.isMade {
                        // 제조 완료 버튼
                        Button(action: {
                            updateOrderStatus(to: "made")
                        }) {
                            HStack {
                                if isUpdating {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "checkmark.circle.fill")
                                }
                                
                                Text(isUpdating ? "처리 중..." : "🍽️ 제조 완료")
                                    .fontWeight(.bold)
                            }
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(isUpdating ? Color.gray : Color.orange)
                            .cornerRadius(12)
                        }
                        .disabled(isUpdating)
                        
                    } else if !order.isServed {
                        // 서빙 완료 버튼
                        Button(action: {
                            updateOrderStatus(to: "served")
                        }) {
                            HStack {
                                if isUpdating {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "checkmark.circle.fill")
                                }
                                
                                Text(isUpdating ? "처리 중..." : "✅ 서빙 완료")
                                    .fontWeight(.bold)
                            }
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(isUpdating ? Color.gray : Color.green)
                            .cornerRadius(12)
                        }
                        .disabled(isUpdating)
                        
                    } else {
                        // 완료된 주문
                        Text("✅ 서빙 완료된 주문입니다")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                            .padding()
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(12)
                    }
                }
            }
            .padding()
            .navigationTitle("주문 상세")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("닫기") {
                        dismiss()
                    }
                }
            }
        }
        .alert("알림", isPresented: $showingAlert) {
            Button("확인") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    // 주문 상태 업데이트 - Python의 update_order_status와 동일
    private func updateOrderStatus(to status: String) {
        isUpdating = true
        
        Task {
            let success = await FirebaseManager.shared.updateOrderStatus(
                orderNumber: order.id, 
                status: status
            )
            
            DispatchQueue.main.async {
                self.isUpdating = false
                
                if success {
                    self.alertMessage = status == "made" ? "제조 완료 처리되었습니다!" : "서빙 완료 처리되었습니다!"
                    self.showingAlert = true
                    
                    // 0.5초 후 시트 닫기 및 새로고침
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.dismiss()
                        self.onStatusUpdate()
                    }
                } else {
                    self.alertMessage = "상태 업데이트에 실패했습니다. 다시 시도해주세요."
                    self.showingAlert = true
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    KitchenView()
}