import SwiftUI

struct ContentView: View {
  @ObservedObject var appState: AppState

  var body: some View {
    VStack(spacing: 0) {
      // Single-line header: [Actions | PRs]  ---  [org dropdown] [refresh]
      HStack(spacing: 8) {
        Picker("", selection: $appState.selectedTab) {
          ForEach(AppState.Tab.allCases, id: \.self) { tab in
            Text(tab.rawValue).tag(tab)
          }
        }
        .pickerStyle(.segmented)
        .frame(width: 150)

        Spacer()

        Picker("", selection: $appState.selectedSource) {
          ForEach(appState.availableSources) { source in
            Text(source.displayName).tag(source)
          }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .frame(maxWidth: 160)
        .onChange(of: appState.selectedSource) { _, newValue in
          appState.switchSource(newValue)
        }

        if appState.isLoading {
          ProgressView()
            .controlSize(.small)
        }

        Button(action: { Task { await appState.refresh() } }) {
          Image(systemName: "arrow.clockwise")
            .font(.system(size: 11))
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)

      Divider()

      // Content
      switch appState.selectedTab {
      case .actions:
        ActionsView(repoGroups: appState.repoGroups, mostRecentRepoId: appState.mostRecentRepoId)
      case .prs:
        PRsView(prsByRepo: appState.pullRequests)
      }

      // Footer
      Divider()
      HStack {
        if let last = appState.lastRefresh {
          Text("Updated at \(formatTime(last))")
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
        }
        Spacer()
        Button("Quit") { NSApp.terminate(nil) }
          .buttonStyle(.plain)
          .font(.system(size: 10))
          .foregroundStyle(.secondary)
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 6)
    }
  }
}
