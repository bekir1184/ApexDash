import Foundation

/// A racing game whose UDP telemetry Apex Dash can read.
///
/// `TelemetryClient` owns the network side: it listens on a UDP port and hands
/// every datagram to the active game. A game only decodes bytes and writes the
/// result into the shared `DashboardModel`, so every dashboard works with every
/// game. See `docs/ADDING_A_GAME.md` for a walkthrough, and `F1Game` for a
/// complete example.
@MainActor
protocol TelemetryGame: AnyObject {
    /// Stable identifier, stored in settings. Never change it once released.
    static var id: String { get }
    /// Name shown in the app, for example "F1 25 / F1 26".
    static var displayName: String { get }
    /// Port the game sends to unless the player changes it.
    static var defaultPort: UInt16 { get }

    /// Decodes one datagram and applies it through `sink`.
    /// - Returns: `true` when the datagram was recognised as this game's
    ///   telemetry. Unrecognised datagrams do not count as a live connection.
    func consume(_ data: Data, sink: TelemetrySink) -> Bool

    /// Called once a second while listening, for time based clean-up such as
    /// hiding a sector banner after a few seconds.
    func tick(sink: TelemetrySink)

    /// Forgets laps, timing and other session state.
    func reset()

    /// A simulated session that produces this game's datagrams, for trying the
    /// app without the game. Return `nil` if the game has no demo.
    func makeDemo() -> TelemetryDemo?
}

extension TelemetryGame {
    func tick(sink: TelemetrySink) {}
    func makeDemo() -> TelemetryDemo? { nil }
}

/// Produces datagrams for a demo drive. Called 60 times a second.
@MainActor
protocol TelemetryDemo: AnyObject {
    func nextDatagrams() -> [Data]
}

/// What a game can publish. Implemented by `TelemetryClient`.
@MainActor
protocol TelemetrySink: AnyObject {
    /// The model every dashboard draws. Mutate it in place.
    var dash: DashboardModel { get set }
    /// Replaces the list of completed lap traces shown on the analysis page.
    func publish(lapTraces: [LapTrace])
    /// Updates track and weather information.
    func publish(session: SessionInfo)
    /// Warns the player that the game sends a format they did not select,
    /// for example `"F1 25"`. Pass `nil` once the right format arrives.
    func reportUnexpectedFormat(_ description: String?)
}
