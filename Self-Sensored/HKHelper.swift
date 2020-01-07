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

protocol HKQueryDelegate {
    func queryComplete(results: [Dictionary<String, Any>], identifier: String)
    func healthKitStoreStateUpdate(state: HealthKitStoreState)
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



class HealthKitHelper {
    
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
    
    // HKSampleQuery with a predicate
    func queryQuantityTypeByDateRange(user_id: Int, activity: HKQuantityTypeIdentifier, queryStartDate: String, queryEndDate: String) {
    
         // Convert string to date.
         let startDate = Date.init(queryStartDate)
         let endDate = Date.init(queryEndDate)
         
         let sampleType = HKSampleType.quantityType(forIdentifier: activity)
         let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: HKQueryOptions.strictEndDate)
        
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
    
}

//func jsonToParameters(json: JSON) -> Parameters {
//    var parameters: Parameters = [Int:Dictionary]
//    for i in 0...json.count {
//
//    }
//}

// Date from String.
extension Date {
    init(_ dateString:String) {
        let dateStringFormatter = DateFormatter()
        dateStringFormatter.dateFormat = "yyyy-MM-dd"
        dateStringFormatter.locale = NSLocale(localeIdentifier: "en_US_POSIX") as Locale
        let date = dateStringFormatter.date(from: dateString)!
        self.init(timeInterval:0, since:date)
    }
}

// Date to String
extension Date {
    func toString() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy'-'MM'-'dd'T'HH':'mm':'ssZZZ"
        return dateFormatter.string(from: self)
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
            "date": self.startDate.toString(),
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
