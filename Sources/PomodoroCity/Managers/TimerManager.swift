import Foundation
import Combine
import SwiftUI

public enum TimerState: Equatable {
    case idle
    case runningFocus
    case pausedFocus
    case runningBreak
    case pausedBreak
}

/// Describes the session that just finished so the UI can show a completion state.
/// Purely informational: it never feeds back into rewards or persistence.
public struct SessionCompletion: Equatable, Identifiable {
    public let id = UUID()
    public var isFocus: Bool
    public var minutes: Int
    public var blocksEarned: Int
    public var reward: Resources
}

@MainActor
public class TimerManager: ObservableObject {
    @Published public var gameState: GameState
    @Published public var timerState: TimerState = .idle
    @Published public var timeRemaining: TimeInterval = 25 * 60
    @Published public var totalSessionDuration: TimeInterval = 25 * 60
    @Published public var lastRewardSummary: String? = nil
    @Published public var lastCompletion: SessionCompletion? = nil

    private var timerSubscription: AnyCancellable?
    private var sessionStartTime: Date?
    private var pauseStartTime: Date?
    private var totalPausedSeconds: TimeInterval = 0

    public init() {
        // Load saved state or use fresh
        do {
            self.gameState = try SaveManager.shared.load()
        } catch {
            print("Notice: Starting with default state because: \(error.localizedDescription)")
            self.gameState = GameState()
        }

        // Check if streak was broken since last launch
        checkStreakOnLaunch()

        // Sync initial timer duration with settings
        self.totalSessionDuration = TimeInterval(gameState.settings.focusDurationMinutes * 60)
        self.timeRemaining = self.totalSessionDuration

        // Update notification reminder schedule
        updateReminder()
    }

    // MARK: - Streak & Calendar Handling

    private func localTodayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: Date())
    }

    private func localYesterdayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        if let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) {
            return formatter.string(from: yesterday)
        }
        return ""
    }

    public var hasCompletedSessionToday: Bool {
        return gameState.lastFocusDate == localTodayString()
    }

    private func checkStreakOnLaunch() {
        guard let lastDate = gameState.lastFocusDate else { return }
        let today = localTodayString()
        let yesterday = localYesterdayString()

        // If last active was before yesterday, streak resets to 0 (never drops below 0)
        if lastDate != today && lastDate != yesterday {
            gameState.currentStreakDays = 0
            persistState()
        }
    }

    private func registerCompletedDayForStreak() {
        let today = localTodayString()
        let yesterday = localYesterdayString()

        if gameState.lastFocusDate == today {
            // Already counted today
            return
        }

        if gameState.lastFocusDate == yesterday {
            gameState.currentStreakDays += 1
        } else {
            // New streak started today
            gameState.currentStreakDays = 1
        }

        gameState.lastFocusDate = today
        if gameState.currentStreakDays > gameState.bestStreakDays {
            gameState.bestStreakDays = gameState.currentStreakDays
        }

        // Check milestone rewards (3, 7, 14, 30 days)
        let milestones = [3, 7, 14, 30]
        for milestone in milestones {
            if gameState.currentStreakDays >= milestone && !gameState.milestonesUnlocked.contains(milestone) {
                gameState.milestonesUnlocked.append(milestone)
                NotificationManager.shared.sendStreakMilestoneNotification(days: milestone)
            }
        }
    }

    // MARK: - Timer Controls

    public func startFocus() {
        lastCompletion = nil
        totalSessionDuration = TimeInterval(gameState.settings.focusDurationMinutes * 60)
        timeRemaining = totalSessionDuration
        sessionStartTime = Date()
        pauseStartTime = nil
        totalPausedSeconds = 0
        timerState = .runningFocus
        startTicker()
    }

    public func startBreak() {
        lastCompletion = nil
        totalSessionDuration = TimeInterval(gameState.settings.breakDurationMinutes * 60)
        timeRemaining = totalSessionDuration
        sessionStartTime = Date()
        pauseStartTime = nil
        totalPausedSeconds = 0
        timerState = .runningBreak
        startTicker()
    }

    public func pause() {
        guard timerState == .runningFocus || timerState == .runningBreak else { return }
        pauseStartTime = Date()
        if timerState == .runningFocus {
            timerState = .pausedFocus
        } else {
            timerState = .pausedBreak
        }
        stopTicker()
    }

    public func resume() {
        guard timerState == .pausedFocus || timerState == .pausedBreak else { return }
        if let pauseStart = pauseStartTime {
            totalPausedSeconds += Date().timeIntervalSince(pauseStart)
            pauseStartTime = nil
        }
        if timerState == .pausedFocus {
            timerState = .runningFocus
        } else {
            timerState = .runningBreak
        }
        startTicker()
    }

    public func reset() {
        stopTicker()
        sessionStartTime = nil
        pauseStartTime = nil
        totalPausedSeconds = 0
        timerState = .idle
        totalSessionDuration = TimeInterval(gameState.settings.focusDurationMinutes * 60)
        timeRemaining = totalSessionDuration
    }

    private func startTicker() {
        timerSubscription?.cancel()
        timerSubscription = Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
    }

    private func stopTicker() {
        timerSubscription?.cancel()
        timerSubscription = nil
    }

    private func tick() {
        guard let start = sessionStartTime else { return }
        let now = Date()
        let elapsed = now.timeIntervalSince(start) - totalPausedSeconds
        let remaining = max(0, totalSessionDuration - elapsed)
        self.timeRemaining = remaining

        if remaining <= 0 {
            handleSessionCompleted()
        }
    }

    private func handleSessionCompleted() {
        stopTicker()
        let isFocus = (timerState == .runningFocus || timerState == .pausedFocus)
        let actualDuration = totalSessionDuration
        let session = SessionRecord(
            type: isFocus ? .focus : .breakSession,
            startTime: sessionStartTime ?? Date().addingTimeInterval(-actualDuration),
            endTime: Date(),
            durationSeconds: actualDuration
        )

        gameState.sessionHistory.insert(session, at: 0)

        var completionReward = Resources()
        var completionBlocks = 0

        if isFocus {
            // Update lifetime focus time
            gameState.totalLifetimeFocusSeconds += actualDuration

            // Add to accumulated focus time for 25-minute blocks
            gameState.completedFocusSeconds += actualDuration
            let blockDuration: TimeInterval = 25.0 * 60.0

            var newBlocksEarned = 0
            while gameState.completedFocusSeconds >= TimeInterval(gameState.completedFocusBlocks + 1) * blockDuration {
                gameState.completedFocusBlocks += 1
                newBlocksEarned += 1

                // Base reward: 2 wood, 1 stone
                var addedWood = 2
                var addedStone = 1
                var addedMetal = 0

                // Every 2nd completed focus block grants +1 metal
                if gameState.completedFocusBlocks % 2 == 0 {
                    addedMetal += 1
                }

                // Check building bonuses
                let currentBlock = gameState.completedFocusBlocks
                for building in gameState.buildings {
                    if let bonus = building.type.bonusForBlock(currentBlock: currentBlock, placedAtBlock: building.placedAtFocusBlocks) {
                        addedWood += bonus.wood
                        addedStone += bonus.stone
                        addedMetal += bonus.metal
                    }
                }

                gameState.resources.add(Resources(wood: addedWood, stone: addedStone, metal: addedMetal))
                completionReward.add(Resources(wood: addedWood, stone: addedStone, metal: addedMetal))
            }
            completionBlocks = newBlocksEarned

            // Update streak
            registerCompletedDayForStreak()

            // Update notifications
            NotificationManager.shared.sendFocusCompleteNotification()
            updateReminder()

            if newBlocksEarned > 0 {
                lastRewardSummary = "Earned rewards for completing \(newBlocksEarned) focus block\(newBlocksEarned > 1 ? "s" : "")!"
            }
        } else {
            NotificationManager.shared.sendBreakCompleteNotification()
        }

        // Reset timer to idle
        sessionStartTime = nil
        pauseStartTime = nil
        totalPausedSeconds = 0
        timerState = .idle
        totalSessionDuration = TimeInterval(
            isFocus ? gameState.settings.breakDurationMinutes * 60 : gameState.settings.focusDurationMinutes * 60
        )
        timeRemaining = totalSessionDuration

        lastCompletion = SessionCompletion(
            isFocus: isFocus,
            minutes: Int(actualDuration / 60),
            blocksEarned: completionBlocks,
            reward: completionReward
        )
        persistState()
    }

    // MARK: - Building Placement & Movement

    public func placeBuilding(type: BuildingType, atX x: Int, y: Int) -> Bool {
        guard gameState.canPlace(atX: x, y: y) else { return false }
        guard gameState.resources.canAfford(type.cost) else { return false }

        gameState.resources.deduct(type.cost)
        let building = PlacedBuilding(
            type: type,
            gridX: x,
            gridY: y,
            placedAtFocusBlocks: gameState.completedFocusBlocks
        )
        gameState.buildings.append(building)
        persistState()
        return true
    }

    public func moveBuilding(buildingID: UUID, toX x: Int, y: Int) -> Bool {
        guard let index = gameState.buildings.firstIndex(where: { $0.id == buildingID }) else { return false }
        guard gameState.canPlace(atX: x, y: y, excludingBuildingID: buildingID) else { return false }

        // Free movement: preserving placedAtFocusBlocks so bonus progress is preserved!
        gameState.buildings[index].gridX = x
        gameState.buildings[index].gridY = y
        persistState()
        return true
    }

    public func removeBuilding(buildingID: UUID) -> Bool {
        guard let index = gameState.buildings.firstIndex(where: { $0.id == buildingID }) else { return false }
        guard !gameState.buildings[index].type.isPermanent else { return false }
        gameState.buildings.remove(at: index)
        persistState()
        return true
    }

    // MARK: - State Persistence

    public func persistState() {
        do {
            try SaveManager.shared.save(state: gameState)
        } catch {
            print("Error persisting game state: \(error.localizedDescription)")
        }
    }

    public func updateSettings(_ newSettings: AppSettings) {
        gameState.settings = newSettings
        if timerState == .idle {
            totalSessionDuration = TimeInterval(newSettings.focusDurationMinutes * 60)
            timeRemaining = totalSessionDuration
        }
        updateReminder()
        persistState()
    }

    public func updateReminder() {
        NotificationManager.shared.updateEveningReminder(
            enabled: gameState.settings.eveningReminderEnabled,
            hour: gameState.settings.eveningReminderHour,
            minute: gameState.settings.eveningReminderMinute,
            sessionCompletedToday: hasCompletedSessionToday,
            currentStreak: gameState.currentStreakDays
        )
    }

    public func restoreFromBackup(url: URL) throws {
        let restored = try SaveManager.shared.importBackup(from: url)
        self.gameState = restored
        self.reset()
        self.updateReminder()
    }
}
