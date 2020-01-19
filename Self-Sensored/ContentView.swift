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
            Text(String("Querying: \(dataHandler.activityId.replacingOccurrences(of: "HKQuantityTypeIdentifier", with: ""))"))
            Text(String("Between \(dataHandler.queryStartDate) and \(dataHandler.queryEndDate)"))
            Text(String("Item " + String(dataHandler.itemPercentageSynced) + "%"))
            Text("Total " + String(dataHandler.totalPercentageSynced) + "%")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
