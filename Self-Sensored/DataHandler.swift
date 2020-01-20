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

class DataHandler: HealthKitHelper, HKQueryDelegate, SelfSensoredServerDelegate, ObservableObject {
    
    @Published var action = "Ready"
    @Published var activityId = "None"
    @Published var queryStartDate = ""
    @Published var queryEndDate = ""
    @Published var itemPercentageSynced = 0.0
    @Published var totalPercentageSynced = 0.0
    
    var yearsToSyncRange: [(Date, Date)]?
    
    var queryTypeIndex = 0
    var healthQueryResultsIndex = 0
    var healthQueryResults = [Dictionary<String, Any>]()
    var healthQueryResultsId = ""
    
    let dataTypes = hkh.getAllHKQuantityTypes()
    
    var readDataTypes: Set<HKObjectType>
    
    override init() {
        readDataTypes = Set(dataTypes)
        super.init()
        hkh.delegate = self
        sss.delegate = self
        yearsToSyncRange! = createArrayOfDates(numberOfYearsPast: 20)
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
        DispatchQueue.main.async {
            self.action = "Sending Data"
        }
        sss.send(data: data)
        print("Queued data to send: \(queueId)")
    }
    
    func completedSendingData() {
        print("Completed sending data")
        self.queryTypeIndex += 1
        queryNextItem()
    }
    
    func sendingDataToServerUpdate(queueId: String, index: Int, total: Int) {
        DispatchQueue.main.async {
            self.itemPercentageSynced = self.getSyncedPercentage(index: total - index, total: total)
        }
    }
    
    // DataHandler
    func queryNextYear() {
        
        if let yearsToSyncRange = yearsToSyncRange {
            if !yearsToSyncRange.isEmpty {
                let year = yearsToSyncRange.first!
                queryNextItem(startDate: year.0, endDate: year.1)
                return
            } else {
                print("Finished syncing all years.")
            }
        }
        print("Unable to find dates to sync.")
    }
    
    
    func queryNextItem(startDate: Date, endDate: Date) {
        if self.queryTypeIndex == self.dataTypes.count {
            self.queryTypeIndex = 0
            print("All done")
            return
        }
        
        let activity = HKQuantityTypeIdentifier(rawValue: self.dataTypes[self.queryTypeIndex].identifier)
        
        DispatchQueue.main.async {
            self.activityId = self.dataTypes[self.queryTypeIndex].identifier
        }
        
        sss.latestDateOfActivity(user_id: String(1), activity: dataTypes[queryTypeIndex].identifier, completionHandler: { date, error in
            let today = Date()
            DispatchQueue.main.async {
                self.queryStartDate = date.toFormat("yyyy-MM-dd")
                self.queryEndDate = today.toFormat("yyyy-MM-dd")
            }
            hkh.queryQuantityTypeByDateRange(user_id: 1, activity: activity, queryStartDate: date, queryEndDate: today)
            self.action = "Querying"
        })
    }
    
    func getSyncedPercentage(index: Int, total: Int) -> Double {
        if total == 0 { return 0.0 }
        let result = Double(index) / Double(total) * 100
        return Double(round(1000*result) / 1000)
    }
    
    func createArrayOfDates(numberOfYearsPast: Int) -> [(Date, Date)] {
        var dates = [(Date(), Date())]
        for index in (0...numberOfYearsPast).reversed() {
            let calendar = Calendar.current
            let year = calendar.component(.year, from: Date()) - index
            let startDate = createDateForRange(year: year, month: 1, day: 1)
            let endDate = createDateForRange(year: year, month: 12, day: 31)
            dates.append((startDate, endDate))
        }
        return dates
    }
    
    func createDateForRange(year: Int, month: Int, day: Int) -> Date {
        var dateComponents = DateComponents()
        dateComponents.year = year
        dateComponents.month = month
        dateComponents.day = day
        
        let userCalendar = Calendar.current // user calendar
        let someDateTime = userCalendar.date(from: dateComponents)
        return someDateTime!
    }
    
}
