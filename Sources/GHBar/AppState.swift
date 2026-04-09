import Foundation
import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {
  @Published var config: AppConfig
  @Published var selectedSource: OrgSource
  @Published var repoGroups: [RepoGroup] = []
  @Published var pullRequests: [String: [PRViewModel]] = [:]
  @Published var overallStatus: RunStatus = .unknown
  @Published var isLoading = false
  @Published var lastRefresh: Date?
  @Published var selectedTab: Tab = .actions
  @Published var mostRecentRepoId: String?

  enum Tab: String, CaseIterable {
    case actions = "Actions"
    case prs = "PRs"
  }

  private var timer: Timer?
  private(set) var isPopoverVisible = false

  init() {
    let cfg = AppConfig.load()
    self.config = cfg
    self.selectedSource = cfg.allSources.first ?? OrgSource(name: "parsio-ai", kind: .org)
  }

  var availableSources: [OrgSource] {
    config.allSources
  }

  func popoverOpened() {
    isPopoverVisible = true
    Task { await refresh() }
    startPolling()
  }

  func popoverClosed() {
    isPopoverVisible = false
    stopPolling()
  }

  private func startPolling() {
    stopPolling()
    timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(config.pollingIntervalSeconds), repeats: true) { [weak self] _ in
      Task { @MainActor in
        await self?.refresh()
      }
    }
  }

  private func stopPolling() {
    timer?.invalidate()
    timer = nil
  }

  func switchSource(_ source: OrgSource) {
    selectedSource = source
    repoGroups = []
    pullRequests = [:]
    mostRecentRepoId = nil
    Task { await refresh() }
  }

  func refresh() async {
    isLoading = true
    defer {
      isLoading = false
      lastRefresh = Date()
    }

    async let runsResult = GitHubService.fetchRunsForSource(selectedSource, config: config)
    async let prsResult = GitHubService.fetchPRsForSource(selectedSource, config: config)

    let (runs, prs) = await (runsResult, prsResult)

    // Build Repo → Workflow → Runs hierarchy
    var repos: [RepoGroup] = []
    for (repo, repoRuns) in runs {
      let shortName = repo.components(separatedBy: "/").last ?? repo
      let byWorkflow = Dictionary(grouping: repoRuns, by: \.workflowName)

      let workflows = byWorkflow.map { (name, wfRuns) in
        WorkflowGroup(
          id: "\(repo)::\(name)",
          workflowName: name,
          runs: wfRuns.map { run in
            RunViewModel(
              id: "\(repo)::\(name)::\(run.headBranch)::\(run.updatedAt)",
              branch: run.headBranch,
              status: parseRunStatus(status: run.status, conclusion: run.conclusion),
              duration: formatDuration(from: run.startedAt, to: run.updatedAt),
              timeAgo: relativeTime(from: run.updatedAt),
              url: URL(string: run.url)
            )
          },
          stats: computeWorkflowStats(runs: wfRuns)
        )
      }.sorted { $0.workflowName < $1.workflowName }

      let latestDate = repoRuns.map(\.updatedAt).max() ?? .distantPast

      if !workflows.isEmpty {
        repos.append(RepoGroup(
          id: repo, repo: repo, shortName: shortName,
          workflows: workflows, mostRecentDate: latestDate
        ))
      }
    }

    // Sort by most recent activity first
    self.repoGroups = repos.sorted { $0.mostRecentDate > $1.mostRecentDate }
    self.mostRecentRepoId = self.repoGroups.first?.id

    // Build PR view models grouped by repo
    var prsByRepo: [String: [PRViewModel]] = [:]
    for (repo, repoPRs) in prs {
      prsByRepo[repo] = repoPRs.map { pr in
        PRViewModel(
          id: "\(repo)#\(pr.number)",
          number: pr.number,
          title: pr.title,
          repo: repo,
          branch: pr.headRefName,
          reviewStatus: parseReviewStatus(pr.reviewDecision),
          checksStatus: checksOverallStatus(pr.statusCheckRollup),
          timeAgo: relativeTime(from: pr.updatedAt),
          url: URL(string: pr.url)
        )
      }
    }
    self.pullRequests = prsByRepo

    // Overall icon status
    let allRuns = runs.values.flatMap { $0 }
    if allRuns.isEmpty {
      overallStatus = .unknown
    } else {
      let statuses = allRuns.map { parseRunStatus(status: $0.status, conclusion: $0.conclusion) }
      if statuses.contains(where: { $0 == .failure }) {
        overallStatus = .failure
      } else if statuses.contains(where: { $0 == .inProgress || $0 == .queued }) {
        overallStatus = .inProgress
      } else {
        overallStatus = .success
      }
    }
  }
}
