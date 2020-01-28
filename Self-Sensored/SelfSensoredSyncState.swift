//
//  SyncState.swift
//  Self-Sensored
//
//  Created by Casey Brittain on 1/21/20.
//  Copyright © 2020 Casey Brittain. All rights reserved.
//

import Foundation
import HealthKit
import SwiftyJSON

protocol SelfSensoredSyncStateDelegate {
    func populatedLatestDates(latestDates: Dictionary<HKObjectType, Date>)
    func allDatesHaveBeenQueried()
    func allActivitiesHaveBeenQueried()
}

class SelfSensoredSyncState {
    
    let defaults = UserDefaults.standard
    
    var delegate: SelfSensoredSyncStateDelegate?
    
    internal var ssServer: SelfSensoredServer

    internal var yearsToSyncRange: [(Date, Date)]
    internal var activitiesToSync: Array<HKObjectType> = []
    internal var latestActivityDates: Dictionary<HKObjectType, Date> = [:]
    internal var activitiesIndex = 0
    
    internal var currentDateRange: (Date, Date)
    
    internal let userDefaultsLatestDateKeyPrefix = "latest_date_for_"
    
    init(selfSensoredServer: SelfSensoredServer, numberOfYearsPast: Int, activities: Array<HKObjectType>) {
        self.yearsToSyncRange = SelfSensoredSyncState.createArrayOfDates(numberOfYearsPast: numberOfYearsPast)
        self.currentDateRange = yearsToSyncRange.first!
        self.activitiesToSync = activities
        self.ssServer = selfSensoredServer
    }
    
    // Static Funcs
    internal static func createArrayOfDates(numberOfYearsPast: Int) -> [(Date, Date)] {
        var dates: Array<(Date, Date)> = []
        
        // For each year
        for index in (0...numberOfYearsPast).reversed() {
            let calendar = Calendar.current
            let year = calendar.component(.year, from: Date()) - index
            
            // Get each month
            for monthIndex in 1...12 {
                let startDate = createDateForRange(year: year, month: monthIndex, day: 1)
                // Quit before adding future dates.
                if startDate > Date().date {
                    break
                }
                let endDate = startDate.dateByAdding(1, .month).dateByAdding(-1, .day).date
                dates.append((startDate, endDate))
            }
        }
        return dates
    }
    
    internal static func createDateForRange(year: Int, month: Int, day: Int) -> Date {
        var dateComponents = DateComponents()
        dateComponents.year = year
        dateComponents.month = month
        dateComponents.day = day
        
        let userCalendar = Calendar.current // user calendar
        let someDateTime = userCalendar.date(from: dateComponents)
        return someDateTime!
    }
    
    public func populateLatestDateForActivities(user_id: Int) {
        for activity in activitiesToSync {
            ssServer.latestDateOfActivity(user_id: user_id, activity: activity.identifier) { (date, error) in
                if(error != "") { print(error) }
                self.latestActivityDates[activity] = date
                if self.latestActivityDates.count == self.activitiesToSync.count {
                    self.initialSyncServerAndUserDefaults()
                    self.delegate?.populatedLatestDates(latestDates: self.latestActivityDates)
                }
            }
        }
    }
    
    public func getMostRecentActivityDate(activity: HKObjectType) -> Date {
        return latestActivityDates[activity] ?? Date()
    }
    
    public func setMostRecentActivityDate(activity: HKObjectType, date: Date) {
        let key = getLatestActivityNameForUserDefaults(activityId: activity.identifier)
        defaults.set(date, forKey: key)
    }
    
    // Funcs
    func getNextDateRangeToSync() {
        endOfReportRangeSyncServerAndDefault()
        if yearsToSyncRange.count > 0 {
            yearsToSyncRange.removeFirst()
        } else {
            delegate?.allDatesHaveBeenQueried()
        }
    }
    
    func getCurrentDateRangeToSync() -> (Date, Date)? {
        if let dates = yearsToSyncRange.first {
            return dates
        }
        return nil
    }
    
    func nextActivityToSync() {
        if activitiesIndex == activitiesToSync.count - 1 {
            activitiesIndex = 0
            delegate?.allActivitiesHaveBeenQueried()
        } else {
            activitiesIndex += 1
        }
    }
    
    func getCurrentActivityToSync() -> HKObjectType {
        return activitiesToSync[activitiesIndex]
    }
    
    func endOfReportRangeSyncServerAndDefault() {
        if let recentlySyncedEndDate = getCurrentDateRangeToSync()?.1 {
            for key in latestActivityDates.keys {
                if let previousEndDate = latestActivityDates[key] {
                    if recentlySyncedEndDate > previousEndDate {
                        let userDefaultKey = getLatestActivityNameForUserDefaults(activityId: key.identifier)
                        defaults.set(recentlySyncedEndDate.date.toISO(), forKey: userDefaultKey)
                    }
                }
            }
        }
    }
    
    func initialSyncServerAndUserDefaults() {
        for key in latestActivityDates.keys {
            initialSyncServerAndDefault(key: key)
        }
    }
    
    func initialSyncServerAndDefault(key: HKObjectType) {
        // For eachActivity
            // 1. Get user default record
            //      a. If none, store server's date and break.
            // 2. Compare server's and default's latest date.
            //      a. If server's date is greater or equal, set default date.
            //      b. If default's date is greater, update latestActivityDates
        
        let keyForDefaults = getLatestActivityNameForUserDefaults(activityId: key.identifier)
        
        // 1.
        if let userDefaultsDate = defaults.object(forKey: keyForDefaults) as? String {
            if let localDate = userDefaultsDate.toISODate()?.date {
                let remoteDate = latestActivityDates[key]!
                print(keyForDefaults)
                if remoteDate >= localDate {
                    // 2.a
                    print("Remote is greater.")
                    latestActivityDates[key] = localDate
                    defaults.set(localDate, forKey: keyForDefaults)
                } else {
                    // 2.b
                    print("Local is greater.")
                    latestActivityDates[key] = localDate
                }
                print("Local: \(localDate.toString())")
                print("Remote: \(remoteDate.toString())")
                print()
            } else {
                print("\(keyForDefaults): Can't convert userDefaultsDate to actual date.")
            }
            print()
        } else {
            // 1.a
            if let date = latestActivityDates[key]?.date.toISO() {
                defaults.set(date, forKey: keyForDefaults)
            }
        }
    }
 
    func getStringDictionaryFromLatestActivityDates() -> Dictionary<String, String> {
        var stringDict = Dictionary<String, String>()
        for key in latestActivityDates.keys {
            if let date = latestActivityDates[key]?.date.toString() {
                stringDict[key.identifier] = date
            }
        }
        return stringDict
    }
    
    func getLatestActivityNameForUserDefaults(activityId: String) -> String {
        return userDefaultsLatestDateKeyPrefix + activityId
    }
    
    func getHKObjectFromUserDefaultsString(userDefaultsKey: String) -> HKObjectType? {
        let stringId = userDefaultsKey.replacingOccurrences(of: userDefaultsLatestDateKeyPrefix, with: "")
        if let hkObjectType = HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier(rawValue: stringId)) {
            return hkObjectType
        }
        return nil
    }
}
