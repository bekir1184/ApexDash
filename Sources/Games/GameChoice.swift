import Foundation

/// The games a player can pick on the connection screen. The raw value is the
/// game's `TelemetryGame.id`, stored in settings.
enum GameChoice: String, CaseIterable, Identifiable {
    case f1 = "f1"
    case acc = "acc"

    var id: String { rawValue }

    /// Short label for the picker.
    var title: String {
        switch self {
        case .f1: return "F1 25 / 26"
        case .acc: return "ACC"
        }
    }

    static func resolve(_ id: String) -> GameChoice {
        GameChoice(rawValue: id) ?? .f1
    }

    /// The game to decode, built from the stored settings.
    @MainActor
    func make(f1Format: Int, accPassword: String) -> TelemetryGame {
        switch self {
        case .f1: return F1Game(format: PacketFormat(rawValue: UInt16(f1Format)) ?? .f126)
        case .acc: return ACCGame(password: accPassword)
        }
    }
}
