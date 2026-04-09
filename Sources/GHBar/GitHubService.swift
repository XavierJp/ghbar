import Foundation

enum GitHubService {

  // MARK: - Public API

  static func fetchRepos(source: OrgSource, config: AppConfig) async -> [String] {
    let cmd: String
    switch source.kind {
    case .org:
      cmd = "repo list \(source.name) --no-archived --limit \(config.maxReposPerOrg) --json nameWithOwner --jq '.[].nameWithOwner'"
    case .personal:
      cmd = "repo list \(source.name) --no-archived --limit \(config.maxReposPerOrg) --source --json nameWithOwner --jq '.[].nameWithOwner'"
    }
    guard let output = try? await gh(cmd), !output.isEmpty else { return [] }
    return output.components(separatedBy: "\n").filter { !$0.isEmpty }
  }

  static func fetchRuns(repo: String, limit: Int) async -> [GHRun] {
    let fields = "workflowName,status,conclusion,headBranch,startedAt,updatedAt,url"
    let cmd = "run list -R \(repo) --limit \(limit) --json \(fields)"
    return (try? await ghJSON(cmd, as: [GHRun].self)) ?? []
  }

  static func fetchPRs(repo: String) async -> [GHPullRequest] {
    let fields = "number,title,url,headRefName,reviewDecision,updatedAt,statusCheckRollup"
    let cmd = "pr list -R \(repo) --author @me --state open --json \(fields)"
    return (try? await ghJSON(cmd, as: [GHPullRequest].self)) ?? []
  }

  // MARK: - Aggregate fetchers

  static func fetchRunsForSource(_ source: OrgSource, config: AppConfig) async -> [String: [GHRun]] {
    let repos = await fetchRepos(source: source, config: config)

    // First pass: small fetch for all repos to find most recently active
    let initial = await withThrottledTasks(inputs: repos, concurrency: config.maxConcurrency) { repo in
      let runs = await fetchRuns(repo: repo, limit: config.runsPerRepo)
      return (repo, runs)
    }

    // Find the most recently updated repo
    let activeRepo = initial
      .max { ($0.value.first?.updatedAt ?? .distantPast) < ($1.value.first?.updatedAt ?? .distantPast) }?
      .key

    // Second pass: fetch more runs for the active repo
    var result = initial
    if let activeRepo, config.activeRepoRunsLimit > config.runsPerRepo {
      let moreRuns = await fetchRuns(repo: activeRepo, limit: config.activeRepoRunsLimit)
      if !moreRuns.isEmpty {
        result[activeRepo] = moreRuns
      }
    }

    return result
  }

  static func fetchPRsForSource(_ source: OrgSource, config: AppConfig) async -> [String: [GHPullRequest]] {
    let repos = await fetchRepos(source: source, config: config)
    return await withThrottledTasks(inputs: repos, concurrency: config.maxConcurrency) { repo in
      let prs = await fetchPRs(repo: repo)
      return (repo, prs)
    }
  }

  // MARK: - Shell helpers

  private static let ghPath: String = {
    let candidates = [
      "/opt/homebrew/bin/gh",
      "/usr/local/bin/gh",
      "/usr/bin/gh"
    ]
    for path in candidates {
      if FileManager.default.fileExists(atPath: path) { return path }
    }
    return "gh"
  }()

  private static func gh(_ arguments: String) async throws -> String {
    try await withCheckedThrowingContinuation { continuation in
      let process = Process()
      let stdout = Pipe()
      let stderr = Pipe()
      process.executableURL = URL(fileURLWithPath: ghPath)
      process.arguments = arguments.components(separatedBy: " ").flatMap { arg -> [String] in
        if arg.hasPrefix("'") && arg.hasSuffix("'") {
          return [String(arg.dropFirst().dropLast())]
        }
        return [arg]
      }
      process.standardOutput = stdout
      process.standardError = stderr
      process.environment = ProcessInfo.processInfo.environment

      do {
        try process.run()
      } catch {
        continuation.resume(throwing: error)
        return
      }

      // Read stdout/stderr BEFORE waitUntilExit to avoid pipe buffer deadlock
      let data = stdout.fileHandleForReading.readDataToEndOfFile()
      let errData = stderr.fileHandleForReading.readDataToEndOfFile()
      process.waitUntilExit()
      let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

      if process.terminationStatus == 0 {
        continuation.resume(returning: output)
      } else {
        let errStr = String(data: errData, encoding: .utf8) ?? "unknown error"
        continuation.resume(throwing: NSError(domain: "gh", code: Int(process.terminationStatus),
                                              userInfo: [NSLocalizedDescriptionKey: errStr]))
      }
    }
  }

  private static func ghJSON<T: Decodable>(_ arguments: String, as type: T.Type) async throws -> T {
    let output = try await gh(arguments)
    guard let data = output.data(using: .utf8), !output.isEmpty else {
      throw NSError(domain: "gh", code: -1, userInfo: [NSLocalizedDescriptionKey: "Empty output"])
    }
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try decoder.decode(type, from: data)
  }

  // MARK: - Concurrency helper

  private static func withThrottledTasks<Input: Sendable, Value>(
    inputs: [Input],
    concurrency: Int,
    operation: @Sendable @escaping (Input) async -> (String, [Value])
  ) async -> [String: [Value]] {
    var results: [String: [Value]] = [:]

    await withTaskGroup(of: (String, [Value]).self) { group in
      var running = 0
      var index = 0

      while index < inputs.count {
        if running < concurrency {
          let input = inputs[index]
          group.addTask { await operation(input) }
          running += 1
          index += 1
        } else {
          if let (repo, values) = await group.next() {
            if !values.isEmpty {
              results[repo] = values
            }
            running -= 1
          }
        }
      }

      for await (repo, values) in group {
        if !values.isEmpty {
          results[repo] = values
        }
      }
    }

    return results
  }
}
