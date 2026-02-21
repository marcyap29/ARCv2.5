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
            // Medications are accessed through HKMedicationDose samples
            // Note: We'll query these separately as they require special handling
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
    
    @available(iOS 16.0, *)
    func fetchMedications(completion: @escaping ([[String: Any]]?, Error?) -> Void) {
        // HealthKit Medications API requires iOS 16+
        // Medications are accessed through HKMedicationDose samples
        // Note: This feature requires proper HealthKit entitlements and user authorization
        
        // For now, return empty array as medication tracking requires
        // additional HealthKit setup that may not be available in all configurations
        // TODO: Implement proper medication dose querying when HealthKit Medications API is fully configured
        DispatchQueue.main.async {
            completion([], nil)
        }
    }
}


