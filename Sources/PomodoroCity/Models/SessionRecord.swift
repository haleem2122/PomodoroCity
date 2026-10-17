import Foundation

public enum SessionType: String, Codable {
    case focus
    case breakSession = "break"
}

public struct SessionRecord: Codable, Identifiable, Equatable {
    public var id: UUID
    public var type: SessionType
    public var startTime: Date
    public var endTime: Date
    public var durationSeconds: TimeInterval

    public init(
        id: UUID = UUID(),
        type: SessionType,
        startTime: Date,
        endTime: Date,
        durationSeconds: TimeInterval
    ) {
        self.id = id
        self.type = type
        self.startTime = startTime
        self.endTime = endTime
        self.durationSeconds = durationSeconds
    }

    /// Calendar day identifier in the user's local timezone (e.g. "2026-10-17").
    public var calendarDayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: endTime)
    }
}
