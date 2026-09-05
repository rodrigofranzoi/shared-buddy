import Foundation

public struct FavoriteShortcut: Identifiable, Codable, Sendable, Equatable {
    public var id: UUID
    public var name: String
    public var content: String
    public var createdAt: Date

    public init(id: UUID = UUID(), name: String, content: String, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.content = content
        self.createdAt = createdAt
    }
}

public struct ClipboardHistoryItem: Identifiable, Codable, Sendable, Equatable {
    public var id: UUID
    public var text: String?
    public var imageData: Data?
    public var tags: [ContentTag]
    public var isSensitive: Bool
    public var createdAt: Date
    public var isFavorite: Bool

    public init(
        id: UUID = UUID(),
        text: String? = nil,
        imageData: Data? = nil,
        tags: [ContentTag] = [],
        isSensitive: Bool = false,
        createdAt: Date = Date(),
        isFavorite: Bool = false
    ) {
        self.id = id
        self.text = text
        self.imageData = imageData
        self.tags = tags
        self.isSensitive = isSensitive
        self.createdAt = createdAt
        self.isFavorite = isFavorite
    }

    public var preview: String {
        if let text, !text.isEmpty {
            return String(text.prefix(80))
        }
        if imageData != nil { return "Image" }
        return "Empty"
    }
}

public struct ScreenshotItem: Identifiable, Codable, Sendable, Equatable {
    public var id: UUID
    public var imageData: Data
    public var title: String
    public var notes: String
    public var tags: [ContentTag]
    public var createdAt: Date
    public var redactionRects: [RedactionRect]

    public init(
        id: UUID = UUID(),
        imageData: Data,
        title: String = "Screenshot",
        notes: String = "",
        tags: [ContentTag] = [.image],
        createdAt: Date = Date(),
        redactionRects: [RedactionRect] = []
    ) {
        self.id = id
        self.imageData = imageData
        self.title = title
        self.notes = notes
        self.tags = tags
        self.createdAt = createdAt
        self.redactionRects = redactionRects
    }
}

public struct RedactionRect: Codable, Sendable, Equatable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var style: RedactionStyle

    public init(x: Double, y: Double, width: Double, height: Double, style: RedactionStyle = .blackBox) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.style = style
    }
}

public enum RedactionStyle: String, Codable, Sendable {
    case blackBox
    case blur
}

public enum BuddySettingsKey {
    public static let analyticsOptIn = "buddy.analyticsOptIn"
    public static let autoCopyOTP = "buddy.otp.autoCopy"
    public static let clipboardRetentionDays = "buddy.clipboard.retentionDays"
    public static let launchAtLogin = "buddy.launchAtLogin"
}
