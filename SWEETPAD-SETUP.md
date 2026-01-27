# SweetPad Setup Guide for StampFolio

## Important Limitations

⚠️ **SweetPad does NOT support SwiftUI Preview Canvas** - it's designed for building and running iOS apps, not for live SwiftUI previews like Xcode's canvas.

SweetPad can:
- ✅ Build and run your app on simulators/devices
- ✅ Manage simulators
- ✅ Debug with CodeLLDB
- ✅ Format code
- ✅ Run tests

SweetPad cannot:
- ❌ Show SwiftUI preview canvas
- ❌ Live preview SwiftUI views

## Current Project Status

Your project is currently a **Swift Package Manager** project (`Package.swift`). SweetPad requires an **Xcode project** (`.xcodeproj` or `.xcworkspace`) to work.

## Solution Options

### Option 1: Create Xcode Project (Recommended for SweetPad)

To use SweetPad, you need to create an Xcode project. Here's how:

#### Step 1: Open Xcode and Create New Project

1. Open Xcode
2. File → New → Project
3. Choose "iOS" → "App"
4. Configure:
   - Product Name: `StampFolio`
   - Team: Your development team
   - Organization Identifier: `com.yourname` (or your preferred identifier)
   - Interface: SwiftUI
   - Language: Swift
   - Storage: SwiftData (since you're using it)
5. Save it in your project directory

#### Step 2: Add Your Source Files

1. In Xcode, right-click on the project
2. Add Files to "StampFolio"...
3. Select all your source files from `StampFolio/` directory
4. Make sure "Copy items if needed" is checked
5. Add to targets: StampFolio

#### Step 3: Configure Dependencies

1. In Xcode project settings, go to "Package Dependencies"
2. Click "+" to add package
3. Add: `https://github.com/onevcat/Kingfisher.git`
4. Version: 7.0.0 or later

#### Step 4: Configure Info.plist

Your existing `Info.plist` should be added to the Xcode project. Make sure:
- Camera usage description is included
- Bundle identifier matches your project settings

#### Step 5: Setup SweetPad

1. Install SweetPad extension in Cursor/VSCode
2. Open the folder containing your `.xcodeproj` file
3. SweetPad should detect the project automatically
4. Use the SweetPad panel to build and run

### Option 2: Use Xcode for Previews, SweetPad for Building

If you want SwiftUI previews, you'll need to use Xcode for that. You can:
- Use Xcode for SwiftUI preview canvas
- Use SweetPad for building and running on simulators/devices
- Use Cursor for code editing

### Option 3: Alternative Preview Solutions

Since SweetPad doesn't support previews, here are alternatives:

#### A. Use Xcode Side-by-Side
- Keep Cursor open for editing
- Keep Xcode open for previews
- Use Xcode's "Open with External Editor" feature

#### B. Use Preview Command Line Tool
There are some experimental tools, but they're not as reliable as Xcode's preview canvas.

## SweetPad Configuration

Once you have an Xcode project, configure SweetPad:

### 1. Install SweetPad Extension

In Cursor/VSCode:
1. Open Extensions (Cmd+Shift+X)
2. Search for "SweetPad"
3. Install the extension by sweetpad-dev

### 2. Configure Settings

Create or edit `.vscode/settings.json`:

```json
{
  // Path to your Xcode workspace (if using .xcworkspace)
  // "sweetpad.workspacePath": "StampFolio.xcworkspace",
  
  // Optional: Custom derived data path
  // "sweetpad.build.derivedDataPath": ".build/derivedData",
  
  // Optional: Additional build arguments
  // "sweetpad.build.args": ["-skipMacroValidation"],
  
  // Optional: Launch arguments
  // "sweetpad.build.launchArgs": [],
  
  // Optional: Environment variables
  // "sweetpad.build.launchEnv": {}
}
```

### 3. Using SweetPad

1. Open the SweetPad panel (🍭 icon in sidebar)
2. Select your scheme (usually "StampFolio")
3. Select a simulator or device
4. Click the ▶️ button to build and run

## Recommended Workflow

For the best development experience:

1. **Code Editing**: Use Cursor (you're already here!)
2. **SwiftUI Previews**: Use Xcode (unfortunately, no alternative yet)
3. **Building/Running**: Use SweetPad or Xcode
4. **Debugging**: Use SweetPad with CodeLLDB or Xcode

## Next Steps

1. Create an Xcode project from your Swift Package
2. Install SweetPad extension
3. Configure SweetPad settings
4. Test building and running through SweetPad

## Notes

- You'll still need Xcode installed (SweetPad uses Xcode's command-line tools)
- SwiftUI previews remain an Xcode-only feature for now
- SweetPad is great for building/running without switching to Xcode
- Consider keeping both Xcode and Cursor open for the best workflow
