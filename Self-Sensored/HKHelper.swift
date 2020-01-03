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

class HealthKitHelper {
    
    let healthStore = HKHealthStore()
    
    init(readDataTypes: Set<HKObjectType>, writeDataTypes: Set<HKSampleType>) {
        
        if HKHealthStore.isHealthDataAvailable() {
            
            healthStore.requestAuthorization(toShare: writeDataTypes, read: readDataTypes) { (success, error) in
                if !success {
                    // Handle the error here.
                } else {
                    
                }
            }
        }
    }
    
    // HKSampleQuery with a predicate
     func queryQuantityTypeByDateRange(activity: HKQuantityTypeIdentifier, queryStartDate: String, queryEndDate: String) {
    
         // Convert string to date.
         let startDate = Date.init(queryStartDate)
         let endDate = Date.init(queryEndDate)
         
         let sampleType = HKSampleType.quantityType(forIdentifier: activity)
         let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: HKQueryOptions.strictEndDate)
         
         // Prepare JSON array for the data.
         var json: [JSON] = []
         
         // Prepare the query.
         let query = HKSampleQuery.init(sampleType: sampleType!,
                                        predicate: predicate,
                                        limit: HKObjectQueryNoLimit,
                                        sortDescriptors: nil) { (query, results, error) in
                                         if let results = results  {
                                             var index = 0
                                             print(results.count)
                                             for result in results as! [HKQuantitySample] {
                                                 if (index % 100 == 0) {
                                                     print(index)
                                                 }
                                                 json.append(self.HKQuantitySampleToJSON(sample: result))
                                                 index += 1
                                                 
                                             }
                                         }
                                            print(json)
         }
         
         // Execute the query.
         healthStore.execute(query)
     }
    
    func HKQuantitySampleToJSON(sample: HKQuantitySample?) -> JSON {
        guard let sample = sample else {
            let error: JSON = ["error": "Missing sample."]
            return error
        }
        var packet = sample.toJSON()
        return packet
    }
    
}

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
    func toJSON() -> JSON {
        let deviceJSON: JSON = [
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
    func toJSON() -> JSON {
        let result: JSON = [ self.quantityType.identifier: [
            "date": self.startDate.toString(),
            "activity_type": self.sampleType.identifier,
            "quantity_type": self.quantityType.identifier,
            "quantity": self.quantity.doubleValue(for: HKUnit.count()),
            "device": self.device?.toJSON() ?? JSON()
            ]
        ]
        return result
    }
}
