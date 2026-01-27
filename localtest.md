# Testing StampFolio on Physical Devices

This guide covers how to run and test StampFolio on your physical iPhone or iPad.

## Prerequisites

- Mac with Xcode installed
- Apple ID (free account works for personal testing)
- USB cable (Lightning or USB-C depending on device)
- iOS 17+ device (iPhone or iPad)

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

1. In Xcode, click **"StampFolio"** in the Project Navigator (left sidebar)
2. Select the **"StampFolio"** target (under TARGETS)
3. Go to the **"Signing & Capabilities"** tab
4. Check **"Automatically manage signing"**
5. Click the **Team** dropdown and select your Apple ID
   - If your Apple ID isn't listed, click "Add an Account..." and sign in

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

### "No provisioning profile" Error

1. Ensure "Automatically manage signing" is checked
2. Verify you've selected a valid Team
3. Check your Apple ID is signed in: **Xcode → Settings → Accounts**

### Device Not Appearing in Xcode

1. Check the USB cable connection
2. Ensure you tapped "Trust" on your device
3. Try a different USB port
4. Restart both Xcode and your device

### Build Succeeds but App Crashes

1. Check the Xcode console for error messages
2. Ensure your device is running iOS 17 or later
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
