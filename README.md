# MT File Manager (iOS)

A small SwiftUI file manager starter app.

## Included
- Browse the app's Documents directory
- Create folders
- Import files from the iOS Files picker (copies into the app sandbox)
- Copy, rename, and delete items
- Preview supported files with Quick Look
- Edit UTF-8 text files (TXT, JSON, XML, HTML, CSS, JS, Markdown, CSV, Swift, plist, YAML, log)

## iOS limitation
This app does not have unrestricted access to the iPhone filesystem. Imported files are copied into the app's own Documents folder. To access other locations, the user must choose files through the iOS document picker. This starter version does not yet persist bookmarks to external folders.

## Build
Open `MTFileManager.xcodeproj` in Xcode, select an iOS simulator or device, and build.

For cloud builds, connect the repository to Codemagic and use the included `codemagic.yaml`. The workflow creates an **unsigned app bundle packaged as an IPA**. It is intended for subsequent signing with a compatible sideloading certificate/profile.
