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

var hkh = SelfSensoredHealthKitHelper()
var sss = SelfSensoredServer()
var sync = SelfSensoredSyncState(selfSensoredServer: sss, numberOfYearsPast: 10, activities: hkh.getAllHKQuantityTypes())

class DataHandler: SelfSensoredHealthKitHelper, HKQueryDelegate, SelfSensoredServerDelegate, SelfSensoredSyncStateDelegate, ObservableObject {
    
    @Published var action = "Ready"
    @Published var activityId = "None"
    @Published var queryDate = ""
    @Published var queryMonth = ""
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
            sync.populateLatestDateForActivities(user_id: 1)
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
            self.action = "Queueing"
        }
        sss.queueDataToSend(dataId: identifier, data: results)
    }
    
    // CALLBACKS: SelfSensoredServer.
    func dataQueuedToSend(queueId: String, data: SelfSensoredData) {
        if data.totalItems > 0 {
            DispatchQueue.main.async {
                self.action = "Sending"
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
    func populatedLatestDates(latestDates: Dictionary<HKObjectType, Date>) {
        print(latestDates)
        queryNextItem()
    }
    
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
            let currentActivityId = sync.getCurrentActivityToSync()
            
            sync.nextActivityToSync()
            
            let mostRecentActivityDate = sync.getMostRecentActivityDate(activity: currentActivityId)
            
            if mostRecentActivityDate > reportRange.1 {
                queryNextItem()
                return
            }
            
            DispatchQueue.main.async {
                self.activityId = currentActivityId.identifier
                self.queryDate = String(reportRange.0.year)
                self.queryMonth = String(reportRange.0.month)
            }

            sss.latestDateOfActivity(user_id: 1, activity: currentActivityId.identifier, completionHandler: { date, error in
                
                // If the most recent item is less than
                // the Report End Date.
                
                var startDate = Date()
                if date < reportRange.0 {
                    startDate = reportRange.0
                } else {
                    startDate = date
                }
                self.action = "Querying"
                hkh.queryQuantityTypeByDateRange(user_id: 1, activity: HKQuantityTypeIdentifier(rawValue: currentActivityId.identifier), queryStartDate: startDate, queryEndDate: reportRange.1)
            })
        }

    }
    
    func getSyncedPercentage(index: Int, total: Int) -> Double {
        if total == 0 { return 0.0 }
        let result = Double(index) / Double(total) * 100
        return Double(round(1000*result) / 1000)
    }
    

    
}
