# Testing StampFolio on Physical Devices

This guide covers how to run and test StampFolio on your physical iPhone or iPad.

## Prerequisites

- Mac with Xcode installed
- Apple ID (free account works for personal testing)
- USB cable (Lightning or USB-C depending on device)
- iOS 26+ device (iPhone or iPad)

---

## Option 1: USB Connection (Recommended for First Time)

### Step 1: Connect Your Device

1. Connect your iPhone/iPad to your Mac via USB cable
2. If prompted on your device, tap **"Trust"** to trust this computer
3. Enter your device passcode if requested

### Step 2: Select Your Device in Xcode

1. Open the project in Xcode
2. In the top toolbar, click the device dropdown (shows "iPhone 15 Pro" or similar)
3. Your physical device should appear under **"iOS Devices"**
4. Select your device (e.g., "Laxmi's iPhone")

### Step 3: Configure Signing (First Time Only)

**SIMPLE METHOD - Click the Inspector Toggle:**

1. In Xcode, click the **blue "StampFolio"** project icon at the top of the left sidebar
2. In the top-right area of Xcode, **click the "Inspector" icon** (looks like a document or panel icon) to show the project settings panel
3. You should now see **"PROJECT"** and **"TARGETS"** sections with tabs at the top
4. Under **TARGETS**, click **"StampFolio"**
5. Click the **"Signing & Capabilities"** tab at the top
6. Check **"Automatically manage signing"**
7. Click the **Team** dropdown and select your Apple ID
   - If your Apple ID isn't listed, click **"Add an Account..."** and sign in
   - Once added, select it from the Team dropdown

**The Inspector icon is in the top-right toolbar area of Xcode - it toggles the project settings panel on/off.**

### Step 4: Trust Developer Certificate on Device

1. On your iPhone/iPad, go to:
   - **Settings → General → VPN & Device Management**
2. Under "Developer App", tap your Apple ID email
3. Tap **"Trust [your email]"**
4. Confirm by tapping **"Trust"**

### Step 5: Build and Run

1. In Xcode, press **⌘R** (or click the Play button)
2. Wait for the build to complete
3. The app will automatically install and launch on your device

---

## Option 2: Wireless Debugging

After connecting via USB at least once, you can deploy wirelessly:

### Enable Wireless Debugging

1. In Xcode, go to **Window → Devices and Simulators**
2. Select your device in the left sidebar
3. Check **"Connect via network"**
4. Wait for the network icon to appear next to your device

### Deploy Wirelessly

1. Disconnect the USB cable
2. Ensure your Mac and device are on the same Wi-Fi network
3. Your device should still appear in the Xcode device dropdown
4. Press **⌘R** to build and run wirelessly

---

## Troubleshooting

### "Untrusted Developer" Error

Go to **Settings → General → VPN & Device Management** on your device and trust the developer certificate.

### "Could not launch app" Error

1. Ensure the device is unlocked
2. Try disconnecting and reconnecting the USB cable
3. Restart Xcode

### Can't See "Signing & Capabilities" Tab

**If you see raw code/text instead of tabs with "General", "Signing & Capabilities", etc.:**

1. **Close the current editor tab:**
   - Click the **X** button on the tab showing the code/text
   - Or press **⌘W** to close the tab

2. **Click the project icon again:**
   - In the left sidebar, click the **blue "StampFolio"** project icon
   - Make sure it's the project icon (blue folder), not any file inside it

3. **Look for the settings interface:**
   - The right side should now show tabs: **General** | **Signing & Capabilities** | **Resource Tags**
   - If you still see code/text, try: **View → Show Project Navigator** (or press **⌘1**)

4. **Alternative method:**
   - Right-click the **blue "StampFolio"** project icon in the left sidebar
   - Select **"Open in New Tab"** or **"Show in Finder"** then click it again
   - This sometimes forces Xcode to show the settings interface

5. **If tabs still don't appear:**
   - Make sure you're clicking the **project icon** (blue), not a folder or file
   - Try clicking on **"StampFolio"** under TARGETS in the center area (if visible)
   - The Signing & Capabilities tab should appear at the top

### "Signing requires a development team" Error

**This is the most common error when connecting a device for the first time.**

1. **Open Signing & Capabilities:**
   - Click **"StampFolio"** (blue project icon) in the left sidebar
   - Select the **"StampFolio"** target in the TARGETS section
   - Click the **"Signing & Capabilities"** tab at the top

2. **Configure signing:**
   - Check **"Automatically manage signing"**
   - Click the **Team** dropdown
   - Select your Apple ID (or add it if not listed)

3. **If Team dropdown is empty:**
   - Click **"Add an Account..."** in the Team dropdown
   - Sign in with your Apple ID
   - Go back to Signing & Capabilities and select your account

4. **Verify your account is added:**
   - Go to **Xcode → Settings** (or **Preferences** on older versions)
   - Click the **"Accounts"** tab
   - Your Apple ID should be listed here
   - If not, click the **"+"** button to add it

### "No provisioning profile" Error

1. Ensure "Automatically manage signing" is checked
2. Verify you've selected a valid Team
3. Check your Apple ID is signed in: **Xcode → Settings → Accounts**

### Device Not Appearing in Xcode

1. Check the USB cable connection
2. Ensure you tapped "Trust" on your device
3. Try a different USB port
4. Restart both Xcode and your device

### "Unpaired" Device Error

If Xcode shows your iPad/iPhone as "unpaired", follow these steps to re-pair:

1. **Disconnect and reconnect the device:**
   - Unplug the USB cable from your Mac
   - Wait 5 seconds
   - Plug it back in

2. **On your iPad/iPhone:**
   - Unlock the device
   - If prompted, tap **"Trust This Computer"**
   - Enter your device passcode

3. **In Xcode:**
   - Go to **Window → Devices and Simulators** (⇧⌘2)
   - Select your device in the left sidebar
   - If you see an "Unpair" button, click it first to clear the old pairing
   - Wait a few seconds, then the device should re-pair automatically

4. **If still unpaired:**
   - In Xcode Devices window, right-click your device and select **"Unpair Device"**
   - Disconnect the USB cable
   - Restart your iPad/iPhone
   - Reconnect the USB cable
   - On your device, tap **"Trust This Computer"** when prompted
   - The device should now pair automatically

5. **Alternative: Reset pairing via Finder (macOS Catalina+):**
   - Open **Finder**
   - Your iPad should appear in the sidebar under "Locations"
   - If it shows as unpaired, click it and follow the on-screen instructions
   - Trust the computer on your device when prompted

### Build Succeeds but App Crashes

1. Check the Xcode console for error messages
2. Ensure your device is running iOS 26 or later
3. Try cleaning the build: **Product → Clean Build Folder** (⇧⌘K)

---

## Notes

- **No localhost needed**: StampFolio connects directly to the Stampchain.io API over the internet
- **Free Apple ID**: Works for personal testing (apps expire after 7 days)
- **Paid Developer Account**: Apps don't expire, can distribute via TestFlight
- **Camera Access**: QR scanning requires physical device (simulators don't have cameras)

---

## Quick Reference

| Action | Shortcut |
|--------|----------|
| Build | ⌘B |
| Run | ⌘R |
| Stop | ⌘. |
| Clean Build | ⇧⌘K |
| Devices Window | ⇧⌘2 |
