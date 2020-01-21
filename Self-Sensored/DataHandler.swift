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
import SwiftyJSON
import SwiftDate

// Order of exec.
// 1. requestReadingAuthorizationForAllDataTypes
// 2. healthKitStoreStateUpdate
// 3. queryNextItem
// 4. hkh.queryQuantityTypeByDateRange
// 5. hkh.queryComplete

var hkh = HealthKitHelper()
var sss = SelfSensoredServer()
var sync = SelfSensoredSyncState(numberOfYearsPast: 20)

class DataHandler: HealthKitHelper, HKQueryDelegate, SelfSensoredServerDelegate, SelfSensoredSyncStateDelegate, ObservableObject {
    
    @Published var action = "Ready"
    @Published var activityId = "None"
    @Published var queryStartDate = ""
    @Published var queryEndDate = ""
    @Published var itemPercentageSynced = 0.0
    @Published var totalPercentageSynced = 0.0
    

    var healthQueryResults = [Dictionary<String, Any>]()
    var healthQueryResultsId = ""
    
    var readDataTypes: Set<HKObjectType> = Set(hkh.getAllHKQuantityTypes())
    
    override init() {
        super.init()
        hkh.delegate = self
        sss.delegate = self
        sync.delegate = self
        hkh.requestReadingAuthorizationForAllDataTypes(typesToRead: readDataTypes)
    }
    
    // CALLBACKS: HealthKitHelper.
    func healthKitStoreStateUpdate(state: HealthKitStoreState) {
        if state == .ready {
            queryNextItem()
        } else {
            print("Not authorized")
        }
    }
    
    func queryUpdate(itemNumber: Int, totalItems: Int) {
        DispatchQueue.main.async {
            self.itemPercentageSynced = self.getSyncedPercentage(index: itemNumber, total: totalItems)
        }
    }
    
    func queryComplete(results: [Dictionary<String, Any>], identifier: String) {
        DispatchQueue.main.async {
            self.action = "Queueing Data"
        }
        sss.queueDataToSend(dataId: identifier, data: results)
    }
    
    // CALLBACKS: SelfSensoredServer.
    func dataQueuedToSend(queueId: String, data: SelfSensoredData) {
        if data.totalItems > 0 {
            DispatchQueue.main.async {
                self.action = "Sending Data"
            }
            sss.send(data: data)
            print("Queued data to send: \(queueId)")
        } else {
            queryNextItem()
        }
        
    }
    
    func completedSendingData() {
        print("Completed sending data")
        queryNextItem()
    }
    
    func sendingDataToServerUpdate(queueId: String, index: Int, total: Int) {
        DispatchQueue.main.async {
            self.itemPercentageSynced = self.getSyncedPercentage(index: total - index, total: total)
        }
    }
    
    // CALLBACKS: SelfSensoredSyncState
    func allDatesHaveBeenQueried() {
        print("Here")
    }
    
    func allActivitiesHaveBeenQueried() {
        print("All activities have been queried")
        sync.getNextDateRangeToSync()
    }
    
    
    // DataHandler
    func queryNextItem() {
        
        if let reportRange = sync.getCurrentDateRangeToSync() {
            
            let currentActivityId = sync.getCurrentActivityToSync().identifier
            sync.nextActivityToSync()
            
            DispatchQueue.main.async {
                self.activityId = currentActivityId
            }

            sss.latestDateOfActivity(user_id: String(1), activity: currentActivityId, completionHandler: { date, error in

                DispatchQueue.main.async {
                    self.queryStartDate = reportRange.0.toString()
                    self.queryEndDate = reportRange.1.toString()
                }
                hkh.queryQuantityTypeByDateRange(user_id: 1, activity: HKQuantityTypeIdentifier(rawValue: currentActivityId), queryStartDate: reportRange.0, queryEndDate: reportRange.1)
                self.action = "Querying"
            })
        }

    }
    
    func getSyncedPercentage(index: Int, total: Int) -> Double {
        if total == 0 { return 0.0 }
        let result = Double(index) / Double(total) * 100
        return Double(round(1000*result) / 1000)
    }
    

    
}
