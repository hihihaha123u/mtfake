import SwiftUI

@main
struct MTFileManagerApp: App {
    var body: some Scene {
        WindowGroup {
            FileBrowserView()
                .preferredColorScheme(nil)
        }
    }
}
