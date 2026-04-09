import AppKit
import SwiftUI
import Combine

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
  private var statusItem: NSStatusItem!
  private var popover: NSPopover!
  private let appState = AppState()
  private var cancellables = Set<AnyCancellable>()

  func applicationDidFinishLaunching(_ notification: Notification) {
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    updateIcon(status: .unknown)

    popover = NSPopover()
    popover.contentSize = NSSize(width: 420, height: 520)
    popover.behavior = .transient
    popover.contentViewController = NSHostingController(
      rootView: ContentView(appState: appState)
    )

    if let button = statusItem.button {
      button.action = #selector(togglePopover)
      button.target = self
    }

    appState.$overallStatus
      .receive(on: RunLoop.main)
      .sink { [weak self] status in
        self?.updateIcon(status: status)
      }
      .store(in: &cancellables)

  }

  @objc private func togglePopover() {
    guard let button = statusItem.button else { return }
    if popover.isShown {
      popover.performClose(nil)
      appState.popoverClosed()
    } else {
      popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
      NSApp.activate(ignoringOtherApps: true)
      appState.popoverOpened()
    }
  }

  private func updateIcon(status: RunStatus) {
    guard let button = statusItem.button else { return }
    button.image = makePRIcon()
  }

  /// Draws the Lucide `git-pull-request-arrow` icon as an 18x18 NSImage, label color.
  private func makePRIcon() -> NSImage {
    let size = NSSize(width: 18, height: 18)
    let image = NSImage(size: size, flipped: false) { rect in
      let scale: CGFloat = 18.0 / 24.0

      // Always use label color (black in light mode, white in dark mode)
      NSColor.labelColor.setStroke()

      let strokeWidth: CGFloat = 2.0 * scale
      let lineJoin: NSBezierPath.LineJoinStyle = .round
      let lineCap: NSBezierPath.LineCapStyle = .round

      func p(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
        NSPoint(x: x * scale, y: (24.0 - y) * scale)
      }

      // 1) Circle at (5, 6) r=3
      let c1Center = p(5, 6)
      let c1Radius = 3.0 * scale
      let circle1 = NSBezierPath(
        ovalIn: NSRect(
          x: c1Center.x - c1Radius, y: c1Center.y - c1Radius,
          width: c1Radius * 2, height: c1Radius * 2
        )
      )
      circle1.lineWidth = strokeWidth
      circle1.lineJoinStyle = lineJoin
      circle1.stroke()

      // 2) Line from (5, 9) to (5, 21)
      let line1 = NSBezierPath()
      line1.move(to: p(5, 9))
      line1.line(to: p(5, 21))
      line1.lineWidth = strokeWidth
      line1.lineCapStyle = lineCap
      line1.stroke()

      // 3) Circle at (19, 18) r=3
      let c2Center = p(19, 18)
      let c2Radius = 3.0 * scale
      let circle2 = NSBezierPath(
        ovalIn: NSRect(
          x: c2Center.x - c2Radius, y: c2Center.y - c2Radius,
          width: c2Radius * 2, height: c2Radius * 2
        )
      )
      circle2.lineWidth = strokeWidth
      circle2.lineJoinStyle = lineJoin
      circle2.stroke()

      // 4) Arrow: M15,9 L12,6 L15,3
      let arrow = NSBezierPath()
      arrow.move(to: p(15, 9))
      arrow.line(to: p(12, 6))
      arrow.line(to: p(15, 3))
      arrow.lineWidth = strokeWidth
      arrow.lineCapStyle = lineCap
      arrow.lineJoinStyle = lineJoin
      arrow.stroke()

      // 5) Path: M12,6 h5 a2,2 0 0 1 2,2 v7
      let connector = NSBezierPath()
      connector.move(to: p(12, 6))
      connector.line(to: p(17, 6))
      let arcCenter = p(17, 8)
      let arcRadius = 2.0 * scale
      connector.appendArc(
        withCenter: arcCenter,
        radius: arcRadius,
        startAngle: 90,
        endAngle: 0,
        clockwise: true
      )
      connector.line(to: p(19, 15))
      connector.lineWidth = strokeWidth
      connector.lineCapStyle = lineCap
      connector.lineJoinStyle = lineJoin
      connector.stroke()

      return true
    }

    return image
  }
}
