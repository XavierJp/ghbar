import Foundation
import SwiftUI

// MARK: - gh CLI JSON models

struct GHRun: Codable {
  let workflowName: String
  let status: String          // "completed", "in_progress", "queued", "waiting"
  let conclusion: String?     // "success", "failure", "cancelled", "skipped", null
  let headBranch: String
  let startedAt: Date
  let updatedAt: Date
  let url: String
}

struct GHPullRequest: Codable {
  let number: Int
  let title: String
  let url: String
  let headRefName: String
  let reviewDecision: String  // "APPROVED", "CHANGES_REQUESTED", "REVIEW_REQUIRED", ""
  let updatedAt: Date
  let statusCheckRollup: [GHStatusCheck]
}

struct GHStatusCheck: Codable {
  let name: String
  let status: String
  let conclusion: String
}

// MARK: - App view models

/// Org → Repo → Workflow → Runs
struct RepoGroup: Identifiable {
  let id: String              // "org/repo"
  let repo: String            // "org/repo"
  let shortName: String       // "repo"
  let workflows: [WorkflowGroup]
  let mostRecentDate: Date    // latest updatedAt across all runs
}

struct WorkflowGroup: Identifiable {
  let id: String              // "org/repo::WorkflowName"
  let workflowName: String
  let runs: [RunViewModel]
  let stats: WorkflowStats
}

struct WorkflowStats {
  let successRate: Int        // 0-100
  let totalRuns: Int
  let avgDuration: String     // e.g. "2m 15s"
  let failCount: Int
}

struct RunViewModel: Identifiable {
  let id: String
  let branch: String
  let status: RunStatus
  let duration: String
  let timeAgo: String
  let url: URL?
}

enum RunStatus {
  case success
  case failure
  case inProgress
  case queued
  case cancelled
  case unknown

  var symbol: String {
    switch self {
    case .success:    return "checkmark.circle.fill"
    case .failure:    return "xmark.circle.fill"
    case .inProgress: return "arrow.triangle.2.circlepath"
    case .queued:     return "clock.fill"
    case .cancelled:  return "minus.circle.fill"
    case .unknown:    return "questionmark.circle"
    }
  }

  var color: Color {
    switch self {
    case .success:    return .green
    case .failure:    return .red
    case .inProgress: return .orange
    case .queued:     return .gray
    case .cancelled:  return .gray
    case .unknown:    return .gray
    }
  }
}

struct PRViewModel: Identifiable {
  let id: String
  let number: Int
  let title: String
  let repo: String
  let branch: String
  let reviewStatus: ReviewStatus
  let checksStatus: RunStatus
  let timeAgo: String
  let url: URL?
}

enum ReviewStatus {
  case approved
  case changesRequested
  case reviewRequired
  case none

  var label: String {
    switch self {
    case .approved:         return "Approved"
    case .changesRequested: return "Changes requested"
    case .reviewRequired:   return "Review required"
    case .none:             return "No reviews"
    }
  }

  var symbol: String {
    switch self {
    case .approved:         return "checkmark.circle.fill"
    case .changesRequested: return "exclamationmark.triangle.fill"
    case .reviewRequired:   return "eye.circle"
    case .none:             return "circle"
    }
  }

  var color: Color {
    switch self {
    case .approved:         return .green
    case .changesRequested: return .orange
    case .reviewRequired:   return .blue
    case .none:             return .gray
    }
  }
}

// MARK: - Helpers

func parseRunStatus(status: String, conclusion: String?) -> RunStatus {
  switch status {
  case "completed":
    switch conclusion {
    case "success":   return .success
    case "failure":   return .failure
    case "cancelled": return .cancelled
    default:          return .unknown
    }
  case "in_progress": return .inProgress
  case "queued", "waiting": return .queued
  default: return .unknown
  }
}

func parseReviewStatus(_ raw: String) -> ReviewStatus {
  switch raw {
  case "APPROVED":          return .approved
  case "CHANGES_REQUESTED": return .changesRequested
  case "REVIEW_REQUIRED":   return .reviewRequired
  default:                  return .none
  }
}

func checksOverallStatus(_ checks: [GHStatusCheck]) -> RunStatus {
  if checks.isEmpty { return .unknown }
  if checks.contains(where: { $0.conclusion == "failure" }) { return .failure }
  if checks.contains(where: { $0.status == "in_progress" || $0.status == "queued" }) { return .inProgress }
  if checks.allSatisfy({ $0.conclusion == "success" }) { return .success }
  return .unknown
}

func relativeTime(from date: Date) -> String {
  let seconds = Int(Date().timeIntervalSince(date))
  if seconds < 0 { return "just now" }
  if seconds < 60 { return "\(seconds)s ago" }
  let minutes = seconds / 60
  if minutes < 60 { return "\(minutes)m ago" }
  let hours = minutes / 60
  if hours < 24 { return "\(hours)h ago" }
  let days = hours / 24
  return "\(days)d ago"
}

private let timeFormatter: DateFormatter = {
  let f = DateFormatter()
  f.dateFormat = "HH:mm:ss"
  return f
}()

func formatTime(_ date: Date) -> String {
  timeFormatter.string(from: date)
}

func formatDuration(from start: Date, to end: Date) -> String {
  let seconds = Int(end.timeIntervalSince(start))
  if seconds < 0 { return "-" }
  if seconds < 60 { return "\(seconds)s" }
  let minutes = seconds / 60
  let secs = seconds % 60
  if minutes < 60 { return "\(minutes)m \(secs)s" }
  let hours = minutes / 60
  let mins = minutes % 60
  return "\(hours)h \(mins)m"
}

func computeWorkflowStats(runs: [GHRun]) -> WorkflowStats {
  let completed = runs.filter { $0.status == "completed" }
  let successes = completed.filter { $0.conclusion == "success" }.count
  let failures = completed.filter { $0.conclusion == "failure" }.count
  let rate = completed.isEmpty ? 0 : Int(Double(successes) / Double(completed.count) * 100)

  let durations = completed.map { $0.updatedAt.timeIntervalSince($0.startedAt) }.filter { $0 > 0 }
  let avgSecs = durations.isEmpty ? 0 : Int(durations.reduce(0, +) / Double(durations.count))
  let avgStr: String
  if avgSecs < 60 {
    avgStr = "\(avgSecs)s"
  } else {
    avgStr = "\(avgSecs / 60)m \(avgSecs % 60)s"
  }

  return WorkflowStats(
    successRate: rate,
    totalRuns: runs.count,
    avgDuration: avgStr,
    failCount: failures
  )
}
