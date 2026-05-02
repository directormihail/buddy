import Foundation

struct Message: Identifiable, Codable, Hashable {
    enum Role: String, Codable {
        case user
        case buddy
    }

    let id: UUID
    let role: Role
    let text: String
    let date: Date

    init(id: UUID = UUID(), role: Role, text: String, date: Date = Date()) {
        self.id = id
        self.role = role
        self.text = text
        self.date = date
    }

    var isUser: Bool {
        role == .user
    }
}
