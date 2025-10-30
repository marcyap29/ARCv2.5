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
        // Additional read types for expanded health import
        s.insert(HKObjectType.quantityType(forIdentifier: .basalEnergyBurned)!)
        s.insert(HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!)
        s.insert(HKObjectType.quantityType(forIdentifier: .bodyMass)!)
        s.insert(HKObjectType.workoutType())
        if #available(iOS 16.0, *) {
            s.insert(HKObjectType.quantityType(forIdentifier: .appleStandTime)!)
        }
        if #available(iOS 17.0, *) {
            s.insert(HKObjectType.quantityType(forIdentifier: .heartRateRecoveryOneMinute)!)
        }
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


