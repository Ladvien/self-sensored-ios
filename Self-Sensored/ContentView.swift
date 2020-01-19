//
//  ContentView.swift
//  Self-Sensored
//
//  Created by Casey Brittain on 12/29/19.
//  Copyright © 2019 Casey Brittain. All rights reserved.
//

// Declartive UI
// https://developer.apple.com/videos/play/wwdc2019/204/

import SwiftUI

struct ContentView: View {
    
    @ObservedObject var dataHandler = DataHandler()
    
    var body: some View {
        VStack() {
            Text("Total " + String(dataHandler.totalPercentageSynced) + "%")
            Text(String("\(dataHandler.action): \(dataHandler.activityId.replacingOccurrences(of: "HKQuantityTypeIdentifier", with: ""))"))
            Text("From: " + dataHandler.queryStartDate)
            Text("To: " + dataHandler.queryEndDate)
            Text(String("Complete: " + String(dataHandler.itemPercentageSynced) + "%"))
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
