import Foundation

struct AppConfig: Codable {
  var orgs: [String]
  var includePersonal: Bool
  var username: String
  var pollingIntervalSeconds: Int
  var maxReposPerOrg: Int
  var runsPerRepo: Int
  var activeRepoRunsLimit: Int
  var maxConcurrency: Int

  static let `default` = AppConfig(
    orgs: ["parsio-ai"],
    includePersonal: true,
    username: "XavierJp",
    pollingIntervalSeconds: 15,
    maxReposPerOrg: 25,
    runsPerRepo: 8,
    activeRepoRunsLimit: 25,
    maxConcurrency: 8
  )

  static let configDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".ghbar")
  static let configFile = configDir.appendingPathComponent("config.json")

  static func load() -> AppConfig {
    guard let data = try? Data(contentsOf: configFile),
          let config = try? JSONDecoder().decode(AppConfig.self, from: data) else {
      // Write default config if missing
      let config = AppConfig.default
      config.save()
      return config
    }
    return config
  }

  func save() {
    try? FileManager.default.createDirectory(at: Self.configDir, withIntermediateDirectories: true)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    if let data = try? encoder.encode(self) {
      try? data.write(to: Self.configFile)
    }
  }

  /// All fetchable sources: orgs + optional personal
  var allSources: [OrgSource] {
    var sources = orgs.map { OrgSource(name: $0, kind: .org) }
    if includePersonal {
      sources.append(OrgSource(name: username, kind: .personal))
    }
    return sources
  }
}

struct OrgSource: Hashable, Identifiable {
  let name: String
  let kind: SourceKind
  var id: String { name }

  var displayName: String {
    switch kind {
    case .org: return name
    case .personal: return "\(name) (personal)"
    }
  }

  enum SourceKind: Hashable {
    case org, personal
  }
}
