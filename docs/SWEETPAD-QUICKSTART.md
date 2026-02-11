# SweetPad Quick Start Guide

## ✅ Your Project is Ready!

Your Xcode project (`StampFolio.xcodeproj`) is already set up and SweetPad configuration has been created.

## Current Setup

- ✅ **Xcode Project**: `StampFolio.xcodeproj` exists
- ✅ **SweetPad Config**: `.vscode/settings.json` configured
- ✅ **Target Name**: `StampFolio`
- ✅ **Scheme**: Should auto-detect as `StampFolio`

## How to Use SweetPad

### 1. Open SweetPad Panel

1. In Cursor, look for the **🍭 SweetPad icon** in the left sidebar
2. Click it to open the SweetPad panel

### 2. Build & Run Your App

1. In the SweetPad panel, you should see:
   - **Build** section with your scheme (`StampFolio`)
   - **Destination** section with available simulators/devices

2. Select a simulator or device from the **Destination** panel

3. Click the **▶️ Build & Run** button next to the `StampFolio` scheme

4. SweetPad will:
   - Build your app using `xcodebuild`
   - Launch the selected simulator (if needed)
   - Install and run your app

### 3. Just Build (Without Running)

- Click the **⚙️ Build** button (gear icon) to build without running

### 4. Clean Build

- Right-click on the scheme name
- Select **"SweetPad: Clean"** to clean build folder and derived data

## Important Notes

### ⚠️ SwiftUI Previews

**SweetPad does NOT support SwiftUI Preview Canvas**. For previews, you still need to use Xcode:

- **For SwiftUI Previews**: Use Xcode (open `StampFolio.xcodeproj` in Xcode)
- **For Building/Running**: Use SweetPad in Cursor
- **For Code Editing**: Use Cursor (you're already here!)

### Recommended Workflow

1. **Edit code** in Cursor
2. **Preview SwiftUI views** in Xcode (if needed)
3. **Build and run** using SweetPad in Cursor
4. **Debug** using SweetPad with CodeLLDB (optional)

## Troubleshooting

### SweetPad Doesn't Show Your Project

1. Make sure you opened the **root folder** (the one containing `StampFolio.xcodeproj`)
2. Reload Cursor window (Cmd+Shift+P → "Reload Window")
3. Check that SweetPad extension is installed and enabled

### Build Errors

1. Check that Xcode is installed and command-line tools are set up:
   ```bash
   xcode-select --print-path
   ```

2. If you see package resolution errors, try:
   - Right-click scheme → "SweetPad: Resolve Dependencies"
   - Or open in Xcode and let it resolve packages

### Scheme Not Found

If the scheme doesn't appear:
1. Open the project in Xcode once
2. Build it in Xcode (this creates the scheme)
3. Return to Cursor and SweetPad should detect it

## Configuration File

Your SweetPad settings are in `.vscode/settings.json`:

```json
{
  "sweetpad.workspacePath": "StampFolio.xcodeproj"
}
```

You can customize this file if needed (see `SWEETPAD-SETUP.md` for more options).

## Next Steps

1. **Open SweetPad panel** (🍭 icon in sidebar)
2. **Select a simulator** from the Destination panel
3. **Click Build & Run** ▶️
4. **Enjoy building in Cursor!** 🎉

---

For more detailed configuration options, see `SWEETPAD-SETUP.md`.
