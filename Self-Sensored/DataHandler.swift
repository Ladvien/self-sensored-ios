//
//  DataHandler.swift
//  Self-Sensored
//
//  Created by Casey Brittain on 1/12/20.
//  Copyright © 2020 Casey Brittain. All rights reserved.
//

import SwiftUI
import Combine
import Alamofire
import HealthKit

var hkh = HealthKitHelper()

class DataHandler: HealthKitHelper, HKQueryDelegate, ObservableObject {
    
    @Published var percentageSynced = 0.0
    
    var healthQueryResultsIndex = 0
    var healthQueryResults = [Dictionary<String, Any>]()
    var healthQueryResultsId = ""
    
    override init() {
        super.init()
        hkh.delegate = self
        
        let activity = HKQuantityTypeIdentifier.heartRate
        
        let readDataTypes : Set = [HKObjectType.quantityType(forIdentifier: activity)!,
                                   HKObjectType.characteristicType(forIdentifier: HKCharacteristicTypeIdentifier.biologicalSex)!,
                                   HKObjectType.characteristicType(forIdentifier: HKCharacteristicTypeIdentifier.dateOfBirth)!,
                                   HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.bodyMass)!]
        
        let writeDataTypes : Set = [HKObjectType.quantityType(forIdentifier: activity)!]

        
        hkh.requestDataTypesAuthorization(readDataTypes: readDataTypes, writeDataTypes: writeDataTypes)
    }
    
    func queryComplete(results: [Dictionary<String, Any>], identifier: String) {
        self.healthQueryResults = results
        self.healthQueryResultsId = identifier
        sendHealthData()
    }
    
    func sendHealthData() {
        
        // If all data is sent, exit recursion.
        if self.healthQueryResultsIndex == self.healthQueryResults.count - 1 {
            print("All done")
            self.healthQueryResultsIndex = 0
            return
        }
        
        let url = "http://maddatum.com:3000/activities/\(self.healthQueryResultsId)"
        // Convert to Alamofire parameters.
        let parameters : Parameters = self.healthQueryResults[self.healthQueryResultsIndex]
        
        // Attempt to post data.
        Alamofire.request(url, method: .post, parameters: parameters, encoding: Alamofire.JSONEncoding.default).validate().responseJSON { response in
            if response.response?.statusCode == 200 {
                self.healthQueryResultsIndex += 1
                self.percentageSynced = Double(self.getSyncedPercentage(index: self.healthQueryResultsIndex, total: self.healthQueryResults.count))
                // If there's more data, recurse.
                self.sendHealthData()
            } else {
                print("Big fat fail")
            }
        }
    }
    
    func healthKitStoreStateUpdate(state: HealthKitStoreState) {
        let activity = HKQuantityTypeIdentifier.heartRate
        if state == .ready {
            hkh.queryQuantityTypeByDateRange(user_id: 1, activity: activity, queryStartDate: "2019-11-03", queryEndDate: "2020-01-01")
        } else {
            print("Not authorized")
        }
    }
    
    func getSyncedPercentage(index: Int, total: Int) -> Double {
        if total == 0 { return 0.0 }
        let result = Double(index) / Double(total) * 100
        return Double(round(1000*result) / 1000)
    }
    
}
