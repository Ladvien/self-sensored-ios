//
//  HKHelper.swift
//  Self-Sensored
//
//  Created by Casey Brittain on 1/3/20.
//  Copyright © 2020 Casey Brittain. All rights reserved.
//

import Foundation
import HealthKit
import SwiftyJSON
import SwiftDate

protocol HKQueryDelegate {
    func queryComplete(results: [Dictionary<String, Any>], identifier: String)
    func healthKitStoreStateUpdate(state: HealthKitStoreState)
    func queryUpdate(itemNumber: Int, totalItems: Int)
}

enum HealthKitStoreState {
    case ready
    case notAuthorized
    case unknown
}

// TODO: Create a delegate protocol for handling
//       JSON returned from query.
// https://useyourloaf.com/blog/quick-guide-to-swift-delegates/

// TODO: Create a case statement to look up sensible unit
//       for whatever ActivityType selected by the user.


// Types:
// Characteristics.  Fairly static.  Should go in the user table.
// https://developer.apple.com/documentation/healthkit/hkcharacteristictypeidentifier
// Quantity.  Lion's share of the data.
// https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier



class SelfSensoredHealthKitHelper {
    
    let healthStore = HKHealthStore()
    var delegate: HKQueryDelegate?
    var healthKitStoreState: HealthKitStoreState = .unknown
    
    init() {}
    
    func requestDataTypesAuthorization(readDataTypes: Set<HKObjectType>, writeDataTypes: Set<HKSampleType>) {
        if HKHealthStore.isHealthDataAvailable() {
            healthStore.requestAuthorization(toShare: writeDataTypes, read: readDataTypes) { (success, error) in
                if success {
                    self.healthKitStoreState = .ready
                } else {
                    self.healthKitStoreState = .notAuthorized
                }
                self.delegate?.healthKitStoreStateUpdate(state: self.healthKitStoreState)
            }
        }
    }
    
    func requestReadingAuthorizationForAllDataTypes(typesToRead: Set<HKObjectType>) {
        if HKHealthStore.isHealthDataAvailable() {
            healthStore.requestAuthorization(toShare: [], read: typesToRead) { (success, error) in
                if success {
                    self.healthKitStoreState = .ready
                } else {
                    self.healthKitStoreState = .notAuthorized
                }
                self.delegate?.healthKitStoreStateUpdate(state: self.healthKitStoreState)
            }
        }
    }
    
    // HKSampleQuery with a predicate
    func queryQuantityTypeByDateRange(user_id: Int, activity: HKQuantityTypeIdentifier, queryStartDate: Date, queryEndDate: Date) {
         let sampleType = HKSampleType.quantityType(forIdentifier: activity)
         let predicate = HKQuery.predicateForSamples(withStart: queryStartDate, end: queryEndDate, options: HKQueryOptions.strictEndDate)
        
         var activities = [Dictionary<String, Any>]()
         var identifier = ""
        
         // Prepare the query.
         let query = HKSampleQuery.init(sampleType: sampleType!,
                                        predicate: predicate,
                                        limit: HKObjectQueryNoLimit,
                                        sortDescriptors: nil) { (query, results, error) in
                                        // Unwrap the query results
                                         if let results = results  {
                                            for result in results as! [HKQuantitySample] {
                                                // Grab the quantity id to add to the packet.
                                                identifier = result.quantityType.identifier
                                                // Get the HealthKit data.
                                                let queryResult = self.HKQuantitySampleToDictionary(sample: result)
                                                // Prepare the activity and add it to our packet.
                                                if var activity = queryResult[identifier] as? Dictionary<String, Any> {
                                                    activity["user_id"] = user_id
                                                    activities.append(activity)
                                                    self.delegate?.queryUpdate(itemNumber: activities.count, totalItems: results.count)
                                                }
                                             }
                                            self.delegate?.queryComplete(results: activities, identifier: identifier)
                                         }
         }
         
         // Execute the query.
         healthStore.execute(query)
     }
    
    func HKQuantitySampleToDictionary(sample: HKQuantitySample?) -> Dictionary<String, Any> {
        guard let sample = sample else {
            let error = ["error": "Missing sample."]
            return error
        }
        return sample.toDictionary()
    }
    
    public func getAllHKQuantityTypes() -> Array<HKObjectType> {
        // TODO: Alphabetize
        let dataTypes : Array = [
                                HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.heartRate)!,
                                HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.restingHeartRate)!,
                                HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.stepCount)!,
                                HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.activeEnergyBurned)!,
                                HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.appleStandTime)!,
                                HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.appleExerciseTime)!,
                                HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.bloodGlucose)!,
                                HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.bloodPressureSystolic)!,
                                HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.bloodPressureDiastolic)!,
                                HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.bodyMass)!,
                                HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.bodyMassIndex)!,
                                HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.bodyFatPercentage)!,
                                HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.bodyTemperature)!
                                
        ]
        return dataTypes
    }
    
}

// JSON to String
extension JSON {
    func toString() -> String {
        // Convert the JSON to a raw String
        if let rawString =  self.rawString([.castNilToNSNull: true]) {
          return rawString
        } else {
          return("json.rawString is nil")
        }
    }
}

// Convert HKDevice to JSON
extension HKDevice {
    func toDictionary() -> Dictionary<String, Any> {
        let deviceJSON: Dictionary<String, Any> = [
            "name": self.name ?? "Unknown",
            "model": self.model ?? "Unknown",
            "firmware": self.firmwareVersion ?? "Unknown",
            "local_identifier": self.localIdentifier ?? "Unknown",
            "manufacturer": self.manufacturer ?? "Unknown",
            "software_version": self.softwareVersion ?? "Unknown",
            "uuid": self.udiDeviceIdentifier ?? "Unknown"
        ]
        return deviceJSON
    }
}

extension HKQuantitySample {
    func toDictionary() -> Dictionary<String, Any> {
        let result: Dictionary<String, Any> = [ self.quantityType.identifier: [
            "date": self.startDate.toISO(),
            "activity_type": self.sampleType.identifier,
            "quantity_type": self.commonExpressedUnit().unitString,
            "quantity": self.toCommonHKUnit(),
            "device": self.device?.toDictionary() ?? [:]
            ]
        ]
        return result
    }
}

extension HKQuantitySample {
    func toCommonHKUnit() -> Double {
        self.quantity.doubleValue(for: self.commonExpressedUnit())
    }
}

extension HKQuantitySample {
    func commonExpressedUnit() -> HKUnit {
        var unitType:HKUnit = HKUnit.count()
        switch self.quantityType.identifier {
        case HKQuantityTypeIdentifier.activeEnergyBurned.rawValue:
            unitType = HKUnit.kilocalorie()
            break
        case HKQuantityTypeIdentifier.appleStandTime.rawValue:
            unitType = HKUnit.count().unitDivided(by: HKUnit.minute())
            break
        case HKQuantityTypeIdentifier.appleExerciseTime.rawValue:
            unitType = HKUnit.minute()
            break
        case HKQuantityTypeIdentifier.bloodGlucose.rawValue:
            // Blood glucose samples may be measured in mg/dL (milligrams per deciliter) or mmol/L (millimoles per liter), depending on the region.
            // You can access the preferred units using the preferredUnitsForQuantityTypes:completion: method.
            unitType = HKUnit.moleUnit(with: .milli, molarMass: HKUnitMolarMassBloodGlucose)
            break
        case HKQuantityTypeIdentifier.bodyMass.rawValue:
            unitType = HKUnit.pound()
            break
        case HKQuantityTypeIdentifier.bodyFatPercentage.rawValue:
            unitType = HKUnit.percent()
            break
        case HKQuantityTypeIdentifier.bodyMassIndex.rawValue:
            unitType = HKUnit.count()
            break
        case HKQuantityTypeIdentifier.bloodPressureDiastolic.rawValue:
            unitType = HKUnit.pascalUnit(with: HKMetricPrefix.milli)
            break
        case HKQuantityTypeIdentifier.bloodPressureSystolic.rawValue:
            unitType = HKUnit.pascalUnit(with: HKMetricPrefix.milli)
            break
        case HKQuantityTypeIdentifier.bodyTemperature.rawValue:
            unitType = HKUnit.degreeFahrenheit()
            break
        case HKQuantityTypeIdentifier.stepCount.rawValue:
            unitType = HKUnit.count()
            break
        case HKQuantityTypeIdentifier.dietaryEnergyConsumed.rawValue:
            unitType = HKUnit.kilocalorie()
            break
        case HKQuantityTypeIdentifier.heartRate.rawValue:
            unitType = HKUnit.count().unitDivided(by: HKUnit.minute())
            break
        case HKQuantityTypeIdentifier.restingHeartRate.rawValue:
            unitType = HKUnit.count().unitDivided(by: HKUnit.minute())
            break
        default:
            // TODO: Handle improper unit.
            print("Not valid HKUnit")
            break
        }
        return unitType
    }
}
