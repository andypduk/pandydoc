# PandyDoc Application Icon Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the PandyDoc panda footprint logo as the application icon in Finder/Dock, window title bar, and About window.

**Architecture:** Create a simplified panda head SVG, convert to ICNS for the app icon, export to PDF for title bar rendering, and build an About view.

**Tech Stack:** Swift, SwiftUI, macOS AppKit, iconutil, SVG/PDF assets

---

### Task 1: Create Panda Head SVG

**Files:**
- Create: `Resources/PandaHead.svg`

- [ ] **Step 1: Create the simplified panda head SVG**

Create `Resources/PandaHead.svg` with the "Rounder & Fluffier" panda design — wider head, bigger ears with inner detail, larger expressive eyes, pink cheeks, cute smile. The SVG should be 1024x1024 with the blue gradient background matching the existing brand colors.

```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">
  <defs>
    <linearGradient id="bg" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#4A90D9"/>
      <stop offset="100%" style="stop-color:#2C5F8A"/>
    </linearGradient>
  </defs>
  
  <!-- Background circle -->
  <circle cx="512" cy="512" r="512" fill="url(#bg)"/>
  
  <!-- Rounder, wider head -->
  <ellipse cx="512" cy="520" rx="340" ry="320" fill="white"/>
  
  <!-- Bigger, fluffier ears -->
  <circle cx="300" cy="320" r="110" fill="#1a1a1a"/>
  <circle cx="300" cy="320" r="60" fill="#333"/>
  <circle cx="724" cy="320" r="110" fill="#1a1a1a"/>
  <circle cx="724" cy="320" r="60" fill="#333"/>
  
  <!-- Larger, more dramatic eye patches -->
  <ellipse cx="400" cy="500" rx="120" ry="90" fill="#1a1a1a" transform="rotate(-15 400 500)"/>
  <ellipse cx="624" cy="500" rx="120" ry="90" fill="#1a1a1a" transform="rotate(15 624 500)"/>
  
  <!-- Bigger eyes -->
  <circle cx="400" cy="490" r="50" fill="white"/>
  <circle cx="624" cy="490" r="50" fill="white"/>
  <circle cx="410" cy="485" r="28" fill="#1a1a1a"/>
  <circle cx="634" cy="485" r="28" fill="#1a1a1a"/>
  <circle cx="418" cy="475" r="12" fill="white"/>
  <circle cx="642" cy="475" r="12" fill="white"/>
  
  <!-- Wider, cuter nose -->
  <ellipse cx="512" cy="600" rx="40" ry="28" fill="#1a1a1a"/>
  <ellipse cx="512" cy="595" rx="15" ry="8" fill="#333" opacity="0.5"/>
  
  <!-- Bigger smile -->
  <path d="M460 645 Q512 700 564 645" stroke="#1a1a1a" stroke-width="12" fill="none" stroke-linecap="round"/>
  
  <!-- Pink cheeks -->
  <circle cx="330" cy="620" r="40" fill="#FFB6C1" opacity="0.5"/>
  <circle cx="694" cy="620" r="40" fill="#FFB6C1" opacity="0.5"/>
</svg>
```

- [ ] **Step 2: Commit**

```bash
git add Resources/PandaHead.svg
git commit -m "feat: add simplified panda head SVG for app icon"
```

---

### Task 2: Generate ICNS Icon Set

**Files:**
- Create: `Resources/PandaHead.iconset/` (directory with all sizes)
- Create: `Resources/PandaHead.icns`

- [ ] **Step 1: Create iconset directory and generate PNGs at all required sizes**

Run the following commands to create the `.iconset` directory and generate PNGs at all macOS-required sizes using `sips`:

```bash
mkdir -p Resources/PandaHead.iconset

# Convert SVG to a temporary PNG at 1024x1024 using qlmanage or a simple approach
# Since sips doesn't handle SVG directly, use a Python/QuickLook approach:
# First, render SVG to PNG using a simple method
python3 -c "
import subprocess
import os

# Use qlmanage to render SVG to PNG
svg_path = 'Resources/PandaHead.svg'
png_path = '/tmp/PandaHead_1024.png'

# Use sips with a workaround: render SVG via CoreGraphics
# On macOS, we can use 'qlmanage -t' to generate thumbnails
subprocess.run(['qlmanage', '-t', '-s', '1024', '-o', '/tmp', svg_path], check=True)

# qlmanage outputs as <filename>.png
ql_png = '/tmp/PandaHead.svg.png'
if os.path.exists(ql_png):
    os.rename(ql_png, png_path)
"

# If qlmanage doesn't work, fall back to using the existing icns or a manual approach
# Check if we got the PNG
if [ ! -f /tmp/PandaHead_1024.png ]; then
    echo "qlmanage failed, using alternative approach..."
    # Use a simple SVG-to-PNG conversion via Python's PIL or manual rendering
    # For now, copy the existing approach and note the user may need to manually export
    echo "Please export PandaHead.svg to PNG at 1024x1024 manually, or use an online converter"
    exit 1
fi

# Generate all icon sizes
sips -z 16 16 /tmp/PandaHead_1024.png --out Resources/PandaHead.iconset/icon_16x16.png
sips -z 32 32 /tmp/PandaHead_1024.png --out Resources/PandaHead.iconset/icon_16x16@2x.png
sips -z 32 32 /tmp/PandaHead_1024.png --out Resources/PandaHead.iconset/icon_32x32.png
sips -z 64 64 /tmp/PandaHead_1024.png --out Resources/PandaHead.iconset/icon_32x32@2x.png
sips -z 128 128 /tmp/PandaHead_1024.png --out Resources/PandaHead.iconset/icon_128x128.png
sips -z 256 256 /tmp/PandaHead_1024.png --out Resources/PandaHead.iconset/icon_128x128@2x.png
sips -z 256 256 /tmp/PandaHead_1024.png --out Resources/PandaHead.iconset/icon_256x256.png
sips -z 512 512 /tmp/PandaHead_1024.png --out Resources/PandaHead.iconset/icon_256x256@2x.png
sips -z 512 512 /tmp/PandaHead_1024.png --out Resources/PandaHead.iconset/icon_512x512.png
sips -z 1024 1024 /tmp/PandaHead_1024.png --out Resources/PandaHead.iconset/icon_512x512@2x.png

# Generate ICNS
iconutil -c icns Resources/PandaHead.iconset -o Resources/PandaHead.icns

# Clean up
rm -rf /tmp/PandaHead_*.png
rm -rf Resources/PandaHead.iconset
```

Expected: `Resources/PandaHead.icns` is created successfully.

- [ ] **Step 2: Commit**

```bash
git add Resources/PandaHead.icns
git commit -m "feat: generate ICNS app icon from panda head SVG"
```

---

### Task 3: Update Package.swift to Use New Icon

**Files:**
- Modify: `Package.swift:29-31`

- [ ] **Step 1: Update Package.swift resource reference**

Change the resource reference from `PandaIcon.icns` to `PandaHead.icns`:

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PandyDoc",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "PandyDoc",
            targets: ["DocManager"]
        ),
        .executable(
            name: "SaveToPandyDoc",
            targets: ["SaveToPandyDoc"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.15.0")
    ],
    targets: [
        .executableTarget(
            name: "DocManager",
            dependencies: [
                .product(name: "SQLite", package: "SQLite.swift")
            ],
            path: "Sources/DocManager",
            resources: [
                .copy("../../Resources/PandaHead.icns")
            ],
            linkerSettings: [
                .linkedFramework("AppKit")
            ]
        ),
        .target(
            name: "PrinterExtension",
            dependencies: [],
            path: "Sources/PrinterExtension"
        ),
        .target(
            name: "Shared",
            dependencies: [],
            path: "Sources/Shared"
        ),
        .executableTarget(
            name: "SaveToPandyDoc",
            dependencies: [],
            path: "Sources/SaveToPandyDoc",
            linkerSettings: [
                .linkedFramework("AppKit")
            ]
        )
    ]
)
```

- [ ] **Step 2: Commit**

```bash
git add Package.swift
git commit -m "refactor: update Package.swift to use PandaHead.icns"
```

---

### Task 4: Update AppDelegate to Load New Icon

**Files:**
- Modify: `Sources/DocManager/Utilities/AppDelegate.swift:14-19`

- [ ] **Step 1: Update setupAppIcon to use PandaHead.icns**

Change the icon filename from `PandaIcon` to `PandaHead`:

```swift
    private func setupAppIcon() {
        if let iconURL = Bundle.main.url(forResource: "PandaHead", withExtension: "icns"),
           let icon = NSImage(contentsOf: iconURL) {
            NSApplication.shared.applicationIconImage = icon
        }
    }
```

- [ ] **Step 2: Commit**

```bash
git add Sources/DocManager/Utilities/AppDelegate.swift
git commit -m "refactor: update AppDelegate to load PandaHead.icns"
```

---

### Task 5: Export Panda Head PDF for Title Bar

**Files:**
- Create: `Resources/PandaHead.pdf`

- [ ] **Step 1: Create PDF version of the panda head**

The PDF is needed for crisp Retina rendering in the title bar. Create `Resources/PandaHead.pdf` by exporting the SVG. Since we need a PDF that scales well, we'll create it from the SVG:

```bash
# Use qlmanage or a simple approach to convert SVG to PDF
# On macOS, we can use the built-in Preview automation or a simple script
python3 -c "
import subprocess
import os

svg_path = 'Resources/PandaHead.svg'
pdf_path = 'Resources/PandaHead.pdf'

# Use macOS built-in tools to convert
# Method: Use 'sips' doesn't do PDF, so use a different approach
# Use 'qlmanage' to get a high-res PNG, then convert to PDF
subprocess.run(['qlmanage', '-t', '-s', '1024', '-o', '/tmp', svg_path], check=True)

ql_png = '/tmp/PandaHead.svg.png'
if os.path.exists(ql_png):
    # Convert PNG to PDF using sips
    subprocess.run(['sips', '-s', 'format', 'pdf', ql_png, '--out', pdf_path], check=True)
    os.remove(ql_png)
    print(f'Created {pdf_path}')
else:
    print('qlmanage failed')
    exit(1)
"
```

If the above fails, the PDF can be created manually by opening the SVG in Preview and exporting as PDF. The key requirement is a vector or high-resolution PDF that scales well at small sizes.

Expected: `Resources/PandaHead.pdf` is created.

- [ ] **Step 2: Add PDF to Package.swift resources**

Update `Package.swift` to include the PDF:

```swift
            resources: [
                .copy("../../Resources/PandaHead.icns"),
                .copy("../../Resources/PandaHead.pdf")
            ],
```

- [ ] **Step 3: Commit**

```bash
git add Resources/PandaHead.pdf Package.swift
git commit -m "feat: add PandaHead.pdf for title bar rendering"
```

---

### Task 6: Add Title Bar Icon + Text to ContentView

**Files:**
- Modify: `Sources/DocManager/Views/ContentView.swift:22-35` (body, toolbar, navigationTitle)
- Modify: `Sources/DocManager/Views/ContentView.swift:456-469` (appBranding)

- [ ] **Step 1: Update appBranding to use PandaHead image**

Replace the `appBranding` view's pawprint SF Symbol with the PandaHead image. The `appBranding` view is used in the sidebar header (line 456-469). Update it to load the PDF:

```swift
    private var appBranding: some View {
        HStack(spacing: 8) {
            Image("PandaHead")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 24, height: 24)
            Text("PandyDoc")
                .font(.headline)
                .fontWeight(.semibold)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(NSColor.windowBackgroundColor))
    }
```

- [ ] **Step 2: Add Image loading helper for bundle resources**

Since `Image("PandaHead")` in SwiftUI looks for asset catalog images, we need to load the PDF from the bundle. Add a helper view at the end of `ContentView.swift` (before the closing brace):

```swift
extension Image {
    init(pdfNamed name: String) {
        guard let url = Bundle.main.url(forResource: name, withExtension: "pdf"),
              let image = NSImage(contentsOf: url) else {
            self.init(systemName: "pawprint.fill")
            return
        }
        let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
        let cgImage = rep.cgImage!
        self.init(nsImage: NSImage(cgImage: cgImage, size: image.size))
    }
}
```

Then update `appBranding` to use this:

```swift
    private var appBranding: some View {
        HStack(spacing: 8) {
            Image(pdfNamed: "PandaHead")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 24, height: 24)
            Text("PandyDoc")
                .font(.headline)
                .fontWeight(.semibold)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(NSColor.windowBackgroundColor))
    }
```

- [ ] **Step 3: Update detailView empty state to use PandaHead**

Update the empty state in `detailView` (around line 540-558) to use the PandaHead image instead of the pawprint SF Symbol:

```swift
    private var detailView: some View {
        Group {
            if viewModel.selectedDocument != nil {
                DocumentQuickView(viewModel: viewModel)
                    .id("\(viewModel.selectedDocument!.id.uuidString)-\(viewModel.documentRefreshToken)")
            } else {
                VStack(spacing: 16) {
                    Image(pdfNamed: "PandaHead")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 64, height: 64)
                        .foregroundColor(.accentColor.opacity(0.6))
                    Text("PandyDoc")
                        .font(.title)
                        .fontWeight(.semibold)
                    Text("Select a document to preview")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
```

- [ ] **Step 4: Update emptyIcon to return PandaHead for all documents**

Update `emptyIcon` (around line 520-526) to return a custom view instead of SF Symbol. Since `emptyIcon` is used with `ContentUnavailableView`, we'll keep it as a system name fallback but note that the main branding is now handled by `appBranding` and `detailView`.

No change needed here — the `ContentUnavailableView` will still use the system icon as a fallback, which is acceptable.

- [ ] **Step 5: Commit**

```bash
git add Sources/DocManager/Views/ContentView.swift
git commit -m "feat: add PandaHead icon to sidebar branding and detail view"
```

---

### Task 7: Create About View

**Files:**
- Create: `Sources/DocManager/Views/AboutView.swift`

- [ ] **Step 1: Create AboutView**

Create a new file `Sources/DocManager/Views/AboutView.swift`:

```swift
import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Image(pdfNamed: "PandaHead")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 128, height: 128)
            
            Text("PandyDoc")
                .font(.title)
                .fontWeight(.bold)
            
            VStack(spacing: 4) {
                Text("Version \(appVersion) (\(buildNumber))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("macOS Document Management System")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            Text("Copyright © 2026 PandyDoc. All rights reserved.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(width: 320, height: 280)
        .padding()
    }
}

#Preview {
    AboutView()
}
```

- [ ] **Step 2: Commit**

```bash
git add Sources/DocManager/Views/AboutView.swift
git commit -m "feat: create AboutView with PandaHead icon"
```

---

### Task 8: Register About Window in App Menu

**Files:**
- Modify: `Sources/DocManager/DocManagerApp.swift:77-98` (help CommandGroup)
- Modify: `Sources/DocManager/Utilities/AppDelegate.swift:4-12` (applicationDidFinishLaunching)

- [ ] **Step 1: Update DocManagerApp to show custom About window**

The existing menu already has "About PandyDoc" (line 95-97) that calls `NSApp.orderFrontStandardAboutPanel(nil)`. We'll replace this with our custom AboutView by using a sheet on the main window.

Add a `@State` variable to track the About window presentation in `DocManagerApp`:

```swift
@main
struct DocManagerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var showAbout = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .sheet(isPresented: $showAbout) {
                    AboutView()
                }
        }
        .windowStyle(.automatic)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            // ... existing commands ...
            
            CommandGroup(replacing: .help) {
                Button("PandyDoc Help") {
                    NotificationCenter.default.post(name: .showHelp, object: nil)
                }
                .keyboardShortcut("?", modifiers: [.command])

                Divider()

                Button("Getting Started") {
                    NotificationCenter.default.post(name: .showGettingStarted, object: nil)
                }

                Button("Keyboard Shortcuts") {
                    NotificationCenter.default.post(name: .showShortcuts, object: nil)
                }

                Divider()

                Button("About PandyDoc") {
                    showAbout = true
                }
            }
            
            // ... rest of commands unchanged ...
        }

        Settings {
            SettingsView()
        }
    }
}
```

Full file after changes:

```swift
import SwiftUI

@main
struct DocManagerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var showAbout = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .sheet(isPresented: $showAbout) {
                    AboutView()
                }
        }
        .windowStyle(.automatic)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Import Document...") {
                    NotificationCenter.default.post(name: .importDocument, object: nil)
                }
                .keyboardShortcut("i", modifiers: [.command])

                Button("Import Folder...") {
                    let panel = NSOpenPanel()
                    panel.title = "Import Folder"
                    panel.canChooseFiles = false
                    panel.canChooseDirectories = true
                    panel.allowsMultipleSelection = false
                    panel.begin { response in
                        if response == .OK, let url = panel.url {
                            NotificationCenter.default.post(name: .importFolder, object: nil, userInfo: ["url": url])
                        }
                    }
                }
                .keyboardShortcut("i", modifiers: [.command, .option])
            }

            CommandGroup(after: .newItem) {
                Button("Check In Document...") {
                    NotificationCenter.default.post(name: .checkInDocument, object: nil)
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])

                Divider()

                Button("Printer Setup...") {
                    NotificationCenter.default.post(name: .showPrinterSetup, object: nil)
                }
            }

            CommandGroup(replacing: .sidebar) {
                Button("Show Sidebar") {
                    NSApp.keyWindow?.firstResponder?.tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
                }
                .keyboardShortcut("0", modifiers: [.command, .option])
            }

            CommandGroup(after: .windowSize) {
                Button("Show Inbox") {
                    NotificationCenter.default.post(name: .navigateToInbox, object: nil)
                }
                .keyboardShortcut("3", modifiers: [.command])

                Button("Show Flagged") {
                    NotificationCenter.default.post(name: .navigateToFlagged, object: nil)
                }
                .keyboardShortcut("4", modifiers: [.command])

                Button("Show All Documents") {
                    NotificationCenter.default.post(name: .navigateToAllDocuments, object: nil)
                }
                .keyboardShortcut("1", modifiers: [.command])

                Button("Show Templates") {
                    NotificationCenter.default.post(name: .navigateToTemplates, object: nil)
                }
                .keyboardShortcut("2", modifiers: [.command])
            }

            CommandGroup(replacing: .help) {
                Button("PandyDoc Help") {
                    NotificationCenter.default.post(name: .showHelp, object: nil)
                }
                .keyboardShortcut("?", modifiers: [.command])

                Divider()

                Button("Getting Started") {
                    NotificationCenter.default.post(name: .showGettingStarted, object: nil)
                }

                Button("Keyboard Shortcuts") {
                    NotificationCenter.default.post(name: .showShortcuts, object: nil)
                }

                Divider()

                Button("About PandyDoc") {
                    showAbout = true
                }
            }
        }

        Settings {
            SettingsView()
        }
    }
}

extension Notification.Name {
    static let importDocument = Notification.Name("importDocument")
    static let importFolder = Notification.Name("importFolder")
    static let checkInDocument = Notification.Name("checkInDocument")
    static let showHelp = Notification.Name("showHelp")
    static let showGettingStarted = Notification.Name("showGettingStarted")
    static let showShortcuts = Notification.Name("showShortcuts")
    static let navigateToAllDocuments = Notification.Name("navigateToAllDocuments")
    static let navigateToTemplates = Notification.Name("navigateToTemplates")
    static let navigateToInbox = Notification.Name("navigateToInbox")
    static let navigateToFlagged = Notification.Name("navigateToFlagged")
}
```

- [ ] **Step 2: Commit**

```bash
git add Sources/DocManager/DocManagerApp.swift
git commit -m "feat: add custom About window with PandaHead icon"
```

---

### Task 9: Build and Verify

**Files:**
- No file changes

- [ ] **Step 1: Build the project**

```bash
swift build
```

Expected: Build succeeds with no errors.

- [ ] **Step 2: Verify icon files exist**

```bash
ls -la Resources/PandaHead.icns Resources/PandaHead.pdf Resources/PandaHead.svg
```

Expected: All three files exist.

- [ ] **Step 3: Final commit**

```bash
git add -A
git commit -m "feat: complete application icon implementation"
```
