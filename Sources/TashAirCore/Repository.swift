import Foundation

public struct RefreshState: Sendable {
    public var snapshot: EnvironmentSnapshot
    public var errors: [Feed: String]
}

public actor EnvironmentRepository {
    public typealias Loader = @Sendable (URL) async throws -> Data
    private struct Envelope: Codable { var version = 1; var fetchedAt: Date; var data: Data }
    private let directory: URL
    private let loader: Loader
    private var snapshot = EnvironmentSnapshot()
    private var errors: [Feed: String] = [:]
    private var attempts: [Feed: Date] = [:]
    private var tasks: [Feed: Task<Void, Never>] = [:]
    private var loaded = false

    public init(directory: URL? = nil, loader: Loader? = nil) {
        self.directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("TashAir/cache", isDirectory: true)
        let client = HTTPClient()
        self.loader = loader ?? { url in try await client.data(url) }
    }
    public func state() -> RefreshState {
        if !loaded { loadCache(); loaded = true }
        return RefreshState(snapshot: snapshot, errors: errors)
    }
    public func refresh(force: Bool = false, feeds: [Feed] = Feed.allCases, now: Date = Date()) async -> RefreshState {
        _ = state()
        await withTaskGroup(of: Void.self) { group in
            for feed in feeds { group.addTask { await self.refreshFeed(feed, force: force, now: now) } }
        }
        return state()
    }
    private func refreshFeed(_ feed: Feed, force: Bool, now: Date) async {
        if let task = tasks[feed] { await task.value; return }
        if !force {
            if let fetched = snapshot.fetched[feed], now.timeIntervalSince(fetched) >= 0,
               now.timeIntervalSince(fetched) < feed.interval,
               !(feed == .history && !Tashkent.calendar.isDate(fetched, inSameDayAs: now)) { return }
            if let attempted = attempts[feed], now.timeIntervalSince(attempted) < 60 { return }
        }
        attempts[feed] = now
        // Join the complete update, including parsing and persistence, rather than just its network request.
        let task = Task { await self.fetchAndStore(feed, now: now) }
        tasks[feed] = task
        await task.value
    }
    private func fetchAndStore(_ feed: Feed, now: Date) async {
        defer { tasks[feed] = nil }
        do {
            let data = try await loader(Providers.url(feed))
            try apply(data, feed: feed, fetchedAt: now)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let encoded = try JSONEncoder().encode(Envelope(fetchedAt: now, data: data))
            try encoded.write(to: file(feed), options: .atomic)
            errors[feed] = nil
        } catch {
            errors[feed] = error.localizedDescription
        }
    }
    private func file(_ feed: Feed) -> URL { directory.appendingPathComponent("\(feed.rawValue).json") }
    private func loadCache() {
        for feed in Feed.allCases {
            let url = file(feed)
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            do {
                let envelope = try JSONDecoder().decode(Envelope.self, from: Data(contentsOf: url))
                guard envelope.version == 1 else { throw ProviderError.invalidData("cache version") }
                try apply(envelope.data, feed: feed, fetchedAt: envelope.fetchedAt)
            } catch {
                errors[feed] = "Кэш повреждён: \(error.localizedDescription)"
                // Preserve the original bytes before a later successful network refresh.
                let backup = url.appendingPathExtension("damaged-\(UUID().uuidString)")
                do { try FileManager.default.moveItem(at: url, to: backup) }
                catch { errors[feed] = "Не удалось сохранить повреждённый кэш: \(error.localizedDescription)" }
            }
        }
    }
    private func apply(_ data: Data, feed: Feed, fetchedAt: Date) throws {
        switch feed {
        case .weather: snapshot.weather = try Providers.weather(data)
        case .air: snapshot.air = try Providers.air(data)
        case .space: snapshot.space = try Providers.kp(data)
        case .flares: snapshot.flares = try Providers.flares(data)
        case .history: snapshot.history = try Providers.days(data)
        }
        snapshot.fetched[feed] = fetchedAt
    }
}
