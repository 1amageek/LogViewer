import Foundation

/// A single rendered log line with a stable identity.
public struct LogLine: Identifiable, Sendable, Equatable, Hashable {
    public let id: String
    public let text: String

    public init(id: String, text: String) {
        self.id = id
        self.text = text
    }
}
