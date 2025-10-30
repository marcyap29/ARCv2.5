# Fix HealthKit permission flow on iOS (ARC)

This guide resolves the “Apple Health permission denied” banner by ensuring the app is properly entitled, shows the iOS authorization sheet, and can read steps and heart rate immediately.

## Acceptance Tests
- First launch shows the Health authorization sheet.
- After granting, app reads steps and latest heart rate in the same session.
- If previously denied, tapping Open Settings navigates to app settings and reads work after enabling.
- ARC appears under Health → Profile → Apps with requested categories.

---

## 1) Xcode project setup
- Enable capability: Targets → Runner → Signing & Capabilities → + Capability → HealthKit.
- Ensure entitlements include: `com.apple.developer.healthkit = true`.
- Info.plist keys:
  - `NSHealthShareUsageDescription` = "ARC needs read access to your Health data to surface patterns and wellness insights."
  - `NSHealthUpdateUsageDescription` = "ARC writes optional mindfulness sessions and notes when you ask it to."
- Clean install path:
  - Delete the app from the device.
  - Product → Clean Build Folder, then build & run on a real device.

## 2) Native bridge (Swift)
Create or update `ios/Runner/HealthKitManager.swift` (typo fixed):

```12:52:ios/Runner/HealthKitManager.swift
import Foundation
import HealthKit

class HealthKitManager {
    static let shared = HealthKitManager()
    let store = HKHealthStore()

    var readTypes: Set<HKObjectType> {
        var s: Set<HKObjectType> = []
        s.insert(HKObjectType.quantityType(forIdentifier: .stepCount)!)
        s.insert(HKObjectType.quantityType(forIdentifier: .heartRate)!)
        s.insert(HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!)
        s.insert(HKObjectType.quantityType(forIdentifier: .restingHeartRate)!)
        s.insert(HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!)
        s.insert(HKObjectType.quantityType(forIdentifier: .vo2Max)!)
        s.insert(HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!)
        s.insert(HKObjectType.quantityType(forIdentifier: .appleExerciseTime)!)
        s.insert(HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!)
        return s
    }

    var writeTypes: Set<HKSampleType> {
        var s: Set<HKSampleType> = []
        if let mindful = HKObjectType.categoryType(forIdentifier: .mindfulSession) {
            s.insert(mindful)
        }
        return s
    }

    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(false, NSError(domain: "HealthKit", code: 1,
              userInfo: [NSLocalizedDescriptionKey: "Health data unavailable"]))
            return
        }
        store.requestAuthorization(toShare: writeTypes, read: readTypes) { ok, err in
            DispatchQueue.main.async { completion(ok, err) }
        }
    }
}
```

Expose the bridge in `ios/Runner/AppDelegate.swift`:

```57:79:ios/Runner/AppDelegate.swift
    let healthChannel = FlutterMethodChannel(name: "epi.healthkit/bridge", binaryMessenger: controller.binaryMessenger)
    healthChannel.setMethodCallHandler { call, result in
      switch call.method {
      case "requestAuthorization":
        HealthKitManager.shared.requestAuthorization { ok, err in
          if let err = err {
            result(FlutterError(code: "HK_AUTH", message: err.localizedDescription, details: nil))
          } else {
            result(ok)
          }
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
```

## 3) Flutter side: request + settings fallback
Ensure `pubspec.yaml` includes:

```yaml
dependencies:
  health: ^9.4.0
  url_launcher: ^6.3.0
```

Create `lib/prism/services/health_service.dart`:

```1:200:lib/prism/services/health_service.dart
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:health/health.dart';
import 'package:url_launcher/url_launcher.dart';

class HealthService {
  static const MethodChannel _channel = MethodChannel('epi.healthkit/bridge');
  final HealthFactory _health = HealthFactory(useHealthConnectIfAvailable: true);

  Future<bool> requestAuthorization() async {
    if (!Platform.isIOS && !Platform.isAndroid) return false;
    if (Platform.isIOS) {
      final ok = await _channel.invokeMethod<bool>('requestAuthorization');
      return ok ?? false;
    }
    final types = <HealthDataType>[
      HealthDataType.STEPS,
      HealthDataType.HEART_RATE,
      HealthDataType.SLEEP_ASLEEP,
      HealthDataType.SLEEP_AWAKE,
      HealthDataType.HEART_RATE_VARIABILITY_SDNN,
      HealthDataType.ACTIVE_ENERGY_BURNED,
      HealthDataType.EXERCISE_TIME,
      HealthDataType.DISTANCE_DELTA,
      HealthDataType.VO2MAX,
      HealthDataType.RESTING_HEART_RATE,
    ];
    return await _health.requestAuthorization(types);
  }

  Future<Map<String, dynamic>> readToday() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final steps = await _health.getTotalStepsInInterval(start, now) ?? 0;
    final hr = await _health.getHealthDataFromTypes(start, now, [HealthDataType.HEART_RATE]);
    final latestHR = hr.isEmpty ? null : hr.last.value;
    return { 'steps': steps, 'latest_heart_rate': latestHR };
  }

  Future<void> openAppSettings() async {
    final uri = Uri.parse('app-settings:');
    if (await canLaunchUrl(uri)) { await launchUrl(uri); }
  }
}
```

Use in UI:

```dart
final svc = HealthService();
Future<void> onConnectPressed() async {
  final ok = await svc.requestAuthorization();
  if (!ok) {
    await svc.openAppSettings();
    return;
  }
  final sample = await svc.readToday();
  // Update UI with sample values…
}
```

## 4) Safety checks
- Runner entitlements has HealthKit capability (Xcode adds automatically).
- Info.plist contains both Health usage strings (already present in this repo).
- HealthKitManager.swift compiles and is in the Runner target.
- Build and test on a physical device.
- After clean install, the Health sheet appears on first connection.

---

## Troubleshooting
- App not in Health → Apps list → Add HealthKit capability, clean build, reinstall.
- Sheet never shows → Ensure you invoke on user action, and on real device.
- Reads empty → Health app not set up, types not granted, or types not produced by device. Start with steps + heartRate.

---

## Done-when checklist
- [ ] First-run sheet appears and user can grant.
- [ ] App shows steps and latest HR without relaunch.
- [ ] Deny → Open Settings works and reads after enabling.
- [ ] App listed under Health → Apps with toggles.
