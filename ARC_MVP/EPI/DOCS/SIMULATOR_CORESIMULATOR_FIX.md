# Fix: CoreSimulatorService "No longer valid" / Connection Refused

If you see:

**"Loaded CoreSimulatorService is no longer valid for this process. Simulator services will no longer be available. Error=... Connection refused ... Service version (1051.17.8) does not match expected service version (1051.17.7)."**

This usually happens when Xcode (or its components) were updated while the Simulator or another app using the simulator was running.

## Steps to fix

1. **Quit everything that uses the simulator**
   - Xcode
   - Simulator app
   - Cursor / your IDE (if it launched the simulator)
   - Any terminal running `flutter run` or `ios-sim`

2. **Clear CoreSimulator caches** (in Terminal):
   ```bash
   rm -rf ~/Library/Developer/CoreSimulator/Caches
   mkdir -p ~/Library/Developer/CoreSimulator/Caches
   ```
   (If the folder was already empty, you may have seen "no matches found" with the old command—that’s fine.)

3. **Restart the CoreSimulator service**:
   ```bash
   killall -9 com.apple.CoreSimulator.CoreSimulatorService 2>/dev/null; true
   ```

4. **Optional – if the issue persists:** Remove unavailable simulator runtimes and list devices:
   ```bash
   xcrun simctl delete unavailable
   xcrun simctl list
   ```

5. **Reopen Xcode** (or run your Flutter/iOS command again). The simulator should work with the current Xcode version.

## Prevention

- Avoid updating Xcode while Simulator or a project using it is running.
- After an Xcode update, quit Simulator and any IDE/terminals that use it, then run the steps above if you see the version mismatch error.

---

## Other common simulator messages

### Sign in with Apple fails (error 1000 / AKAuthenticationError -7022)

**Sign in with Apple does not work in the iOS Simulator.** It only works on a **physical device** with an Apple ID signed in to Settings → Apple ID.

- You’ll see: `AuthorizationErrorCode.unknown`, `ASAuthorizationError error 1000`, or `AKAuthenticationError Code=-7022`.
- **What to do:** Test Sign in with Apple on a real iPhone or iPad. Use the simulator for everything else.

### objc "Class X is implemented in both ... One of the duplicates must be removed"

These come from the **iOS simulator runtime** (Apple frameworks) or occasionally from a plugin (e.g. `FileUtils` in `file_picker`). They are known simulator issues and do not indicate a bug in your app. Safe to ignore for development.

### RevenueCat "API Key not recognized" / "Error fetching offerings"

Simulator builds often use a different or placeholder API key, or no StoreKit Configuration file. Configure RevenueCat and (for simulator) a StoreKit Configuration file if you need to test purchases; otherwise you can ignore these in simulator.

### "The OS has terminated the Flutter debug connection for being inactive in the background"

Normal when the app goes to the background (e.g. after opening Sign in with Apple or switching apps). Run the app again with `flutter run` to reconnect.
