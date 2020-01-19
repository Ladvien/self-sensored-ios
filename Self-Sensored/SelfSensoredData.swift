//
//  SelfSensoredData.swift
//  Self-Sensored
//
//  Created by Casey Brittain on 1/19/20.
//  Copyright © 2020 Casey Brittain. All rights reserved.
//

import Foundation
import Alamofire

class SelfSensoredData {
    
    var id: String
    var data: [Parameters]
    var totalItems: Int
    
    init(id: String, parameters: [Parameters]) {
        self.id = id
        self.data = parameters
        self.totalItems = parameters.count
    }
    
}
