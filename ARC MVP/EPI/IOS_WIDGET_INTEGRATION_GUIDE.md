# 🎯 **iOS Widget Extension Integration Guide**

## 📋 **Prerequisites**

Before adding the widget extension, ensure your app builds successfully:

```bash
flutter clean
flutter pub get
flutter build ios --release
```

## 🚀 **Step-by-Step Integration**

### **Step 1: Open Xcode Project**
```bash
cd "ARC MVP/EPI"
open ios/Runner.xcworkspace
```

### **Step 2: Add Widget Extension Target**

1. **In Xcode:**
   - Click on the **project name** in the navigator (top level)
   - Click the **"+"** button at the bottom of the targets list
   - Select **"Widget Extension"**
   - Click **"Next"**

2. **Configure the Widget:**
   - **Product Name:** `EPIJournalWidget`
   - **Bundle Identifier:** `com.epi.arcmvp.EPIJournalWidget`
   - **Language:** Swift
   - **Use Core Data:** ❌ (unchecked)
   - **Include Configuration Intent:** ❌ (unchecked)
   - Click **"Finish"**

3. **When prompted:**
   - **Activate scheme:** ✅ (checked)
   - Click **"Activate"**

### **Step 3: Create Widget Files**

#### **A. Widget Implementation**
Create `ios/EPIJournalWidget/EPIJournalWidget.swift`:

```swift
import WidgetKit
import SwiftUI
import AppIntents

@main
struct EPIJournalWidget: Widget {
    let kind: String = "EPIJournalWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            EPIJournalWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("EPI Journal")
        .description("Quick access to journal entry creation")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(
            date: Date(),
            lastEntry: "Tap to create new entry",
            mediaCount: 0,
            title: "EPI Journal"
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(
            date: Date(),
            lastEntry: "Tap to create new entry",
            mediaCount: 0,
            title: "EPI Journal"
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        var entries: [SimpleEntry] = []

        let currentDate = Date()
        for hourOffset in 0 ..< 5 {
            let entryDate = Calendar.current.date(byAdding: .hour, value: hourOffset, to: currentDate)!
            let entry = SimpleEntry(
                date: entryDate,
                lastEntry: "Tap to create new entry",
                mediaCount: 0,
                title: "EPI Journal"
            )
            entries.append(entry)
        }

        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let lastEntry: String
    let mediaCount: Int
    let title: String
}

struct EPIJournalWidgetEntryView: View {
    var entry: Provider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: "pencil")
                    .foregroundColor(.blue)
                    .font(.system(size: 16, weight: .semibold))
                Text("EPI Journal")
                    .font(.caption)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            // Quick actions
            HStack(spacing: 8) {
                Button(intent: NewEntryIntent()) {
                    VStack(spacing: 2) {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .semibold))
                        Text("New")
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(.blue)
                
                Button(intent: QuickPhotoIntent()) {
                    VStack(spacing: 2) {
                        Image(systemName: "camera")
                            .font(.system(size: 18, weight: .semibold))
                        Text("Photo")
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(.blue)
                
                Button(intent: VoiceNoteIntent()) {
                    VStack(spacing: 2) {
                        Image(systemName: "mic")
                            .font(.system(size: 18, weight: .semibold))
                        Text("Voice")
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(.blue)
            }
            
            // Last entry preview
            if !entry.lastEntry.isEmpty && entry.lastEntry != "Tap to create new entry" {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Last Entry:")
                        .font(.caption2)
                        .fontWeight(.semibold)
                    Text(entry.lastEntry)
                        .font(.caption2)
                        .lineLimit(2)
                        .truncationMode(.tail)
                }
            }
            
            // Media count
            if entry.mediaCount > 0 {
                HStack {
                    Image(systemName: "photo")
                        .font(.caption2)
                    Text("\(entry.mediaCount) media")
                        .font(.caption2)
                }
                .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(12)
        .background(Color(.systemBackground))
    }
}

// MARK: - App Intents

struct NewEntryIntent: AppIntent {
    static var title: LocalizedStringResource = "New Entry"
    static var description: IntentDescription = IntentDescription("Create a new journal entry")
    
    func perform() async throws -> some IntentResult {
        if let url = URL(string: "epi://new-entry") {
            await UIApplication.shared.open(url)
        }
        return .result()
    }
}

struct QuickPhotoIntent: AppIntent {
    static var title: LocalizedStringResource = "Quick Photo"
    static var description: IntentDescription = IntentDescription("Take a photo for journal entry")
    
    func perform() async throws -> some IntentResult {
        if let url = URL(string: "epi://camera") {
            await UIApplication.shared.open(url)
        }
        return .result()
    }
}

struct VoiceNoteIntent: AppIntent {
    static var title: LocalizedStringResource = "Voice Note"
    static var description: IntentDescription = IntentDescription("Record a voice note for journal entry")
    
    func perform() async throws -> some IntentResult {
        if let url = URL(string: "epi://voice") {
            await UIApplication.shared.open(url)
        }
        return .result()
    }
}

@main
struct EPIJournalWidgetBundle: WidgetBundle {
    var body: some Widget {
        EPIJournalWidget()
    }
}
```

#### **B. Widget Info.plist**
Update `ios/EPIJournalWidget/Info.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>$(DEVELOPMENT_LANGUAGE)</string>
	<key>CFBundleDisplayName</key>
	<string>EPI Journal Widget</string>
	<key>CFBundleExecutable</key>
	<string>$(EXECUTABLE_NAME)</string>
	<key>CFBundleIdentifier</key>
	<string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>$(PRODUCT_NAME)</string>
	<key>CFBundlePackageType</key>
	<string>$(PRODUCT_BUNDLE_PACKAGE_TYPE)</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>NSExtension</key>
	<dict>
		<key>NSExtensionPointIdentifier</key>
		<string>com.apple.widgetkit-extension</string>
	</dict>
	<key>NSSupportsAutomaticTermination</key>
	<true/>
	<key>NSSupportsSuddenTermination</key>
	<true/>
</dict>
</plist>
```

### **Step 4: Configure Main App**

#### **A. Update Main App Info.plist**
Add to `ios/Runner/Info.plist`:

```xml
	<key>CFBundleURLTypes</key>
	<array>
		<dict>
			<key>CFBundleURLName</key>
			<string>epi-deep-link</string>
			<key>CFBundleURLSchemes</key>
			<array>
				<string>epi</string>
			</array>
		</dict>
	</array>
	<key>UIApplicationShortcutItems</key>
	<array>
		<dict>
			<key>UIApplicationShortcutItemType</key>
			<string>new_entry</string>
			<key>UIApplicationShortcutItemTitle</key>
			<string>New Entry</string>
			<key>UIApplicationShortcutItemSubtitle</key>
			<string>Create journal entry</string>
			<key>UIApplicationShortcutItemIconType</key>
			<string>UIApplicationShortcutIconTypeCompose</string>
		</dict>
		<dict>
			<key>UIApplicationShortcutItemType</key>
			<string>quick_photo</string>
			<key>UIApplicationShortcutItemTitle</key>
			<string>Quick Photo</string>
			<key>UIApplicationShortcutItemSubtitle</key>
			<string>Take photo for journal</string>
			<key>UIApplicationShortcutItemIconType</key>
			<string>UIApplicationShortcutIconTypeCapturePhoto</string>
		</dict>
		<dict>
			<key>UIApplicationShortcutItemType</key>
			<string>voice_note</string>
			<key>UIApplicationShortcutItemTitle</key>
			<string>Voice Note</string>
			<key>UIApplicationShortcutItemSubtitle</key>
			<string>Record voice note</string>
			<key>UIApplicationShortcutItemIconType</key>
			<string>UIApplicationShortcutIconTypeAudio</string>
		</dict>
	</array>
```

#### **B. Add App Delegate Extension**
Create `ios/Runner/AppDelegate+Widget.swift`:

```swift
import UIKit

extension AppDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Handle quick action from launch
        if let shortcutItem = launchOptions?[UIApplication.LaunchOptionsKey.shortcutItem] as? UIApplicationShortcutItem {
            handleQuickAction(shortcutItem)
        }
        
        return true
    }
    
    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        handleQuickAction(shortcutItem)
        completionHandler(true)
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        handleDeepLink(url)
        return true
    }
    
    // MARK: - Private Methods
    
    private func handleQuickAction(_ shortcutItem: UIApplicationShortcutItem) {
        switch shortcutItem.type {
        case "new_entry":
            openAppToNewEntry()
        case "quick_photo":
            openAppToCamera()
        case "voice_note":
            openAppToVoiceRecorder()
        default:
            break
        }
    }
    
    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "epi" else { return }
        
        switch url.host {
        case "new-entry":
            openAppToNewEntry()
        case "camera":
            openAppToCamera()
        case "voice":
            openAppToVoiceRecorder()
        default:
            break
        }
    }
    
    private func openAppToNewEntry() {
        NotificationCenter.default.post(
            name: NSNotification.Name("OpenNewEntry"),
            object: nil
        )
    }
    
    private func openAppToCamera() {
        NotificationCenter.default.post(
            name: NSNotification.Name("OpenCamera"),
            object: nil
        )
    }
    
    private func openAppToVoiceRecorder() {
        NotificationCenter.default.post(
            name: NSNotification.Name("OpenVoiceRecorder"),
            object: nil
        )
    }
}
```

### **Step 5: Configure App Groups (Optional)**

For shared data between app and widget:

1. **In Xcode:**
   - Select the **project** → **Runner** target
   - Go to **Signing & Capabilities**
   - Click **"+ Capability"**
   - Add **"App Groups"**
   - Add group: `group.com.epi.arcmvp.shared`

2. **Repeat for Widget:**
   - Select **EPIJournalWidget** target
   - Add the same App Group

### **Step 6: Build and Test**

```bash
flutter clean
flutter pub get
flutter build ios --release
```

## 🎯 **Key Differences from Previous Attempt**

1. **Proper Target Setup:** Created through Xcode UI, not manually
2. **Correct Bundle IDs:** Widget has proper extension identifier
3. **App Groups:** Optional but recommended for data sharing
4. **Clean Separation:** Widget and app targets are properly configured
5. **No Build Conflicts:** Each target has its own configuration

## 📱 **Testing**

1. **Build on device** (widgets don't work in simulator)
2. **Long press home screen** → Add widget
3. **Search "EPI Journal"** → Add widget
4. **Test quick actions** on app icon
5. **Test deep linking** from widget buttons

This approach should work without build conflicts!
