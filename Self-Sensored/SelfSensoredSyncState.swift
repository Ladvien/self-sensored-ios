//
//  SyncState.swift
//  Self-Sensored
//
//  Created by Casey Brittain on 1/21/20.
//  Copyright © 2020 Casey Brittain. All rights reserved.
//

import Foundation
import HealthKit

protocol SelfSensoredSyncStateDelegate {
    func populatedLatestDates(latestDates: Dictionary<HKObjectType, Date>)
    func allDatesHaveBeenQueried()
    func allActivitiesHaveBeenQueried()
}

class SelfSensoredSyncState {
    
    var delegate: SelfSensoredSyncStateDelegate?
    
    internal var ssServer: SelfSensoredServer
    
    internal var yearsToSyncRange: [(Date, Date)]
    internal var activitiesToSync: Array<HKObjectType> = []
    internal var latestActivityDates: Dictionary<HKObjectType, Date> = [:]
    internal var activitiesIndex = 0
    
    internal var currentDateRange: (Date, Date)
    
    
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
                    self.delegate?.populatedLatestDates(latestDates: self.latestActivityDates)
                }
            }
        }
    }
    
    public func getMostRecentActivityDate(activity: HKObjectType) -> Date {
        return latestActivityDates[activity] ?? Date()
    }
    
    // Funcs
    func getNextDateRangeToSync() {
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
}
