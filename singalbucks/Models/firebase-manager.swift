// FirebaseManager.swift
// Firebase 연동을 관리하는 싱글톤 클래스
// 안드로이드의 Firebase 헬퍼 클래스와 유사한 역할

import Foundation
import Firebase
import FirebaseDatabase

// MARK: - Firebase Manager 싱글톤 클래스
// 앱 전체에서 Firebase 기능을 관리하는 중앙 관리자
class FirebaseManager: ObservableObject {
    
    // 싱글톤 인스턴스 - 안드로이드의 static instance와 동일
    static let shared = FirebaseManager()
    
    // Firebase Database 참조 - Python의 db.reference()와 동일
    private var database: DatabaseReference
    
    // 연결 상태 추적 - UI에서 관찰 가능
    @Published var isConnected: Bool = false
    @Published var connectionStatus: String = "연결 중..."
    
    // private 생성자 - 싱글톤 패턴 구현
    private init() {
        // Firebase 초기화 - Python의 firebase_admin.initialize_app()와 동일
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        
        // Database 참조 초기화
        self.database = Database.database().reference()
        
        // 연결 상태 모니터링 설정
        self.setupConnectionMonitoring()
    }
    
    // MARK: - 연결 상태 모니터링
    // Firebase 연결 상태를 실시간으로 감시
    private func setupConnectionMonitoring() {
        let connectedRef = Database.database().reference(withPath: ".info/connected")
        
        connectedRef.observe(.value) { [weak self] snapshot in
            DispatchQueue.main.async {
                if let connected = snapshot.value as? Bool, connected {
                    self?.isConnected = true
                    self?.connectionStatus = "Firebase 연결됨 ✅"
                    print("🔥 Firebase 연결 성공")
                } else {
                    self?.isConnected = false
                    self?.connectionStatus = "Firebase 연결 실패 ❌"
                    print("❌ Firebase 연결 실패")
                }
            }
        }
    }
    
    // MARK: - 주문 관련 메서드들
    
    /// 새 주문을 Firebase에 저장
    /// - Parameter orderData: 주문 데이터
    /// - Returns: 성공/실패 결과와 주문번호
    func placeOrder(orderData: [String: Any]) async -> (success: Bool, orderNumber: Int?, error: String?) {
        do {
            // 다음 주문번호 가져오기 - Python의 get_next_order_number()와 동일
            let orderNumber = try await getNextOrderNumber()
            
            // 주문 데이터에 추가 정보 포함
            var completeOrderData = orderData
            completeOrderData["order_number"] = orderNumber
            completeOrderData["timestamp"] = ServerValue.timestamp()
            completeOrderData["is_made"] = false
            completeOrderData["is_served"] = false
            
            // Firebase에 주문 저장 - Python의 ref.child().set()와 동일
            try await database.child("orders").child("\(orderNumber)").setValue(completeOrderData)
            
            print("✅ 주문 저장 성공: \(orderNumber)번")
            return (true, orderNumber, nil)
            
        } catch {
            print("❌ 주문 저장 실패: \(error.localizedDescription)")
            return (false, nil, error.localizedDescription)
        }
    }
    
    /// 다음 주문번호 생성 및 업데이트
    /// - Returns: 새로운 주문번호
    private func getNextOrderNumber() async throws -> Int {
        // 주문번호 카운터 참조
        let counterRef = database.child("order_counter")
        
        // 현재 카운터 값 가져오기
        let snapshot = try await counterRef.getData()
        let currentNumber = snapshot.value as? Int ?? 0
        
        // 다음 번호로 업데이트
        let nextNumber = currentNumber + 1
        try await counterRef.setValue(nextNumber)
        
        return nextNumber
    }
    
    /// 주문 상태 업데이트 (제조완료/서빙완료)
    /// - Parameters:
    ///   - orderNumber: 주문번호
    ///   - status: 업데이트할 상태 ("made" 또는 "served")
    func updateOrderStatus(orderNumber: String, status: String) async -> Bool {
        do {
            let orderRef = database.child("orders").child(orderNumber)
            
            switch status {
            case "made":
                try await orderRef.child("is_made").setValue(true)
                print("✅ \(orderNumber)번 주문 제조 완료 처리")
            case "served":
                try await orderRef.child("is_served").setValue(true)
                print("✅ \(orderNumber)번 주문 서빙 완료 처리")
            default:
                print("❌ 알 수 없는 상태: \(status)")
                return false
            }
            
            return true
        } catch {
            print("❌ 상태 업데이트 실패: \(error.localizedDescription)")
            return false
        }
    }
    
    /// 모든 주문 실시간 리스너 설정
    /// - Parameter completion: 주문 데이터 변경 시 호출되는 콜백
    func observeOrders(completion: @escaping ([String: Any]) -> Void) {
        database.child("orders").observe(.value) { snapshot in
            var orders: [String: Any] = [:]
            
            // Firebase 스냅샷을 딕셔너리로 변환
            if let data = snapshot.value as? [String: Any] {
                orders = data
            }
            
            // 메인 스레드에서 UI 업데이트
            DispatchQueue.main.async {
                completion(orders)
            }
        }
    }
    
    /// Firebase 리스너 정리
    func removeAllObservers() {
        database.removeAllObservers()
        print("🧹 Firebase 리스너 정리 완료")
    }
}

// MARK: - 주문 데이터 모델
// 안드로이드의 data class와 유사한 구조체
struct OrderModel: Identifiable, Codable {
    let id: String                    // 주문번호 (문자열)
    let orderNumber: Int              // 주문번호 (숫자)
    let items: [String: Int]          // 주문 항목 {상품명: 수량}
    let totalAmount: Int              // 총 금액
    let timestamp: TimeInterval       // 주문 시간
    var isMade: Bool                  // 제조 완료 여부
    var isServed: Bool               // 서빙 완료 여부
    
    // Firebase 데이터를 OrderModel로 변환하는 초기화 메서드
    init?(id: String, data: [String: Any]) {
        guard 
            let orderNumber = data["order_number"] as? Int,
            let items = data["items"] as? [String: Int],
            let totalAmount = data["total_amount"] as? Int,
            let timestamp = data["timestamp"] as? TimeInterval
        else {
            return nil
        }
        
        self.id = id
        self.orderNumber = orderNumber
        self.items = items
        self.totalAmount = totalAmount
        self.timestamp = timestamp
        self.isMade = data["is_made"] as? Bool ?? false
        self.isServed = data["is_served"] as? Bool ?? false
    }
    
    // 주문 시간을 포맷된 문자열로 반환
    var formattedTime: String {
        let date = Date(timeIntervalSince1970: timestamp / 1000)
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    // 주문 상태 반환
    var status: OrderStatus {
        if isServed {
            return .served
        } else if isMade {
            return .made
        } else {
            return .pending
        }
    }
}

// MARK: - 주문 상태 열거형
enum OrderStatus: String, CaseIterable {
    case pending = "pending"    // 제조 전
    case made = "made"         // 제조 완료
    case served = "served"     // 서빙 완료
    
    var displayName: String {
        switch self {
        case .pending: return "🔴 제조 전"
        case .made: return "🟡 제조 완료"
        case .served: return "🟢 서빙 완료"
        }
    }
    
    var color: String {
        switch self {
        case .pending: return "red"
        case .made: return "orange"
        case .served: return "green"
        }
    }
}