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
        Text(String(dataHandler.percentageSynced) + "%")
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
