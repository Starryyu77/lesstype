import Foundation

struct PendingDictionaryLearning: Equatable {
    let originalText: String
    let context: ActiveAppContext
    let createdAt: Date

    var isExpired: Bool {
        Date().timeIntervalSince(createdAt) > 10 * 60
    }
}
