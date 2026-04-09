import SwiftUI

struct PRsView: View {
  let prsByRepo: [String: [PRViewModel]]

  var body: some View {
    if prsByRepo.isEmpty {
      emptyState
    } else {
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 0) {
          ForEach(sortedRepos, id: \.self) { repo in
            repoSection(repo: repo, prs: prsByRepo[repo] ?? [])
          }
        }
        .padding(.vertical, 4)
      }
    }
  }

  private var sortedRepos: [String] {
    prsByRepo.keys.sorted()
  }

  private func repoSection(repo: String, prs: [PRViewModel]) -> some View {
    Section {
      ForEach(prs) { pr in
        prRow(pr: pr)
      }
    } header: {
      Text(repo)
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 2)
    }
  }

  private func prRow(pr: PRViewModel) -> some View {
    Button(action: { openURL(pr.url) }) {
      VStack(alignment: .leading, spacing: 3) {
        HStack(spacing: 6) {
          Text("#\(pr.number)")
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundColor(.accentColor)
          Text(pr.title)
            .font(.system(size: 13))
            .lineLimit(1)
          Spacer()
          Text(pr.timeAgo)
            .font(.system(size: 11))
            .foregroundStyle(.tertiary)
        }
        HStack(spacing: 8) {
          HStack(spacing: 3) {
            Image(systemName: "arrow.triangle.branch")
              .font(.system(size: 10))
            Text(pr.branch)
              .font(.system(size: 11, design: .monospaced))
          }
          .foregroundStyle(.tertiary)

          Spacer()

          HStack(spacing: 3) {
            Image(systemName: pr.checksStatus.symbol)
              .font(.system(size: 11))
              .foregroundColor(pr.checksStatus.color)
            Text("CI")
              .font(.system(size: 11))
              .foregroundStyle(.secondary)
          }

          HStack(spacing: 3) {
            Image(systemName: pr.reviewStatus.symbol)
              .font(.system(size: 11))
              .foregroundColor(pr.reviewStatus.color)
            Text(pr.reviewStatus.label)
              .font(.system(size: 11))
              .foregroundStyle(.secondary)
          }
        }
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 5)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .onHover { hovering in
      if hovering {
        NSCursor.pointingHand.push()
      } else {
        NSCursor.pop()
      }
    }
  }

  private var emptyState: some View {
    VStack(spacing: 8) {
      Spacer()
      Image(systemName: "arrow.triangle.pull")
        .font(.system(size: 28))
        .foregroundStyle(.tertiary)
      Text("No open PRs")
        .font(.system(size: 13))
        .foregroundStyle(.secondary)
      Spacer()
    }
    .frame(maxWidth: .infinity)
  }

  private func openURL(_ url: URL?) {
    guard let url else { return }
    NSWorkspace.shared.open(url)
  }
}
