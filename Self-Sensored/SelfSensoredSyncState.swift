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
    func allDatesHaveBeenQueried()
    func allActivitiesHaveBeenQueried()
}

class SelfSensoredSyncState {
    
    var delegate: SelfSensoredSyncStateDelegate?
    
    internal var yearsToSyncRange: [(Date, Date)]
    internal let activitiesToSync = hkh.getAllHKQuantityTypes()
    internal var activitiesIndex = 0
    
    internal var currentDateRange: (Date, Date)
    
    
    init(numberOfYearsPast: Int) {
        yearsToSyncRange = SelfSensoredSyncState.createArrayOfDates(numberOfYearsPast: numberOfYearsPast)
        currentDateRange = yearsToSyncRange.first!
    }
    
    // Static Funcs
    internal static func createArrayOfDates(numberOfYearsPast: Int) -> [(Date, Date)] {
        var dates: Array<(Date, Date)> = []
        for index in (0...numberOfYearsPast).reversed() {
            let calendar = Calendar.current
            let year = calendar.component(.year, from: Date()) - index
            let startDate = createDateForRange(year: year, month: 1, day: 1)
            let endDate = createDateForRange(year: year, month: 12, day: 31)
            dates.append((startDate, endDate))
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
