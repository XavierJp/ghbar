import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.accessory) // No dock icon

let delegate = MainActor.assumeIsolated { AppDelegate() }
app.delegate = delegate
app.run()
