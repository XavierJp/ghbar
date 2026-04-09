import SwiftUI

struct ActionsView: View {
  let repoGroups: [RepoGroup]
  let mostRecentRepoId: String?

  var body: some View {
    if repoGroups.isEmpty {
      emptyState
    } else {
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 0) {
          ForEach(repoGroups) { repo in
            RepoDisclosure(
              repo: repo,
              startsExpanded: repo.id == mostRecentRepoId
            )
          }
        }
        .padding(.vertical, 4)
      }
    }
  }

  private var emptyState: some View {
    VStack(spacing: 8) {
      Spacer()
      Image(systemName: "tray")
        .font(.system(size: 28))
        .foregroundStyle(.tertiary)
      Text("No workflow runs found")
        .font(.system(size: 13))
        .foregroundStyle(.secondary)
      Spacer()
    }
    .frame(maxWidth: .infinity)
  }
}

// MARK: - Repo disclosure (stateful, controls its own expansion)

private struct RepoDisclosure: View {
  let repo: RepoGroup
  let startsExpanded: Bool
  @State private var isExpanded: Bool = false

  init(repo: RepoGroup, startsExpanded: Bool) {
    self.repo = repo
    self.startsExpanded = startsExpanded
    self._isExpanded = State(initialValue: startsExpanded)
  }

  var body: some View {
    DisclosureGroup(isExpanded: $isExpanded) {
      ForEach(repo.workflows) { workflow in
        workflowSection(workflow: workflow)
      }
    } label: {
      HStack(spacing: 6) {
        Image(systemName: "folder.fill")
          .font(.system(size: 12))
          .foregroundStyle(.secondary)
        Text(repo.shortName)
          .font(.system(size: 13, weight: .semibold))
        Spacer()
        repoStatusBadge
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 1)
  }

  private var repoStatusBadge: some View {
    let allStatuses = repo.workflows.flatMap { $0.runs }.map(\.status)
    let worst = worstStatus(allStatuses)
    return Image(systemName: worst.symbol)
      .font(.system(size: 12))
      .foregroundColor(statusColor(worst))
  }

  private func workflowSection(workflow: WorkflowGroup) -> some View {
    DisclosureGroup {
      ForEach(workflow.runs) { run in
        runRow(run: run)
      }
    } label: {
      HStack(spacing: 6) {
        Image(systemName: "gearshape")
          .font(.system(size: 11))
          .foregroundStyle(.tertiary)
        Text(workflow.workflowName)
          .font(.system(size: 12, weight: .medium))
        Spacer()
        statsLabel(workflow.stats)
      }
    }
    .padding(.leading, 8)
    .padding(.vertical, 0)
  }

  private func statsLabel(_ stats: WorkflowStats) -> some View {
    HStack(spacing: 6) {
      Text("\(stats.successRate)%")
        .font(.system(size: 12, weight: .medium, design: .monospaced))
        .foregroundColor(stats.successRate >= 80 ? .green : stats.successRate >= 50 ? .orange : .red)

      HStack(spacing: 2) {
        Image(systemName: "clock")
          .font(.system(size: 10))
        Text(stats.avgDuration)
          .font(.system(size: 12, design: .monospaced))
      }
      .foregroundStyle(.tertiary)

      if stats.failCount > 0 {
        HStack(spacing: 2) {
          Image(systemName: "xmark.circle.fill")
            .font(.system(size: 10))
          Text("\(stats.failCount)")
            .font(.system(size: 12, design: .monospaced))
        }
        .foregroundColor(.red.opacity(0.8))
      }
    }
  }

  private func runRow(run: RunViewModel) -> some View {
    Button(action: { openURL(run.url) }) {
      HStack(spacing: 6) {
        Image(systemName: run.status.symbol)
          .font(.system(size: 11))
          .foregroundColor(statusColor(run.status))
        Text(run.branch)
          .font(.system(size: 11, design: .monospaced))
          .lineLimit(1)
        Spacer()
        Text(run.duration)
          .font(.system(size: 10, design: .monospaced))
          .foregroundStyle(.tertiary)
        Text(run.timeAgo)
          .font(.system(size: 10))
          .foregroundStyle(.quaternary)
      }
      .padding(.leading, 16)
      .padding(.vertical, 1)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .onHover { hovering in
      if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
    }
  }

  private func statusColor(_ status: RunStatus) -> Color {
    switch status {
    case .success:    return .green
    case .failure:    return .red
    case .inProgress: return .orange
    case .queued:     return .gray
    case .cancelled:  return .gray
    case .unknown:    return .gray
    }
  }

  private func worstStatus(_ statuses: [RunStatus]) -> RunStatus {
    if statuses.contains(where: { $0 == .failure }) { return .failure }
    if statuses.contains(where: { $0 == .inProgress }) { return .inProgress }
    if statuses.contains(where: { $0 == .queued }) { return .queued }
    if statuses.allSatisfy({ $0 == .success }) { return .success }
    return .unknown
  }

  private func openURL(_ url: URL?) {
    guard let url else { return }
    NSWorkspace.shared.open(url)
  }
}
