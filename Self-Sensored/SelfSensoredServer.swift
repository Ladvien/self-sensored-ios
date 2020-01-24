//
//  Server.swift
//  Self-Sensored
//
//  Created by Casey Brittain on 1/18/20.
//  Copyright © 2020 Casey Brittain. All rights reserved.
//

import Foundation
import Alamofire
import SwiftyJSON

protocol SelfSensoredServerDelegate {
    func completedSendingData()
    func dataQueuedToSend(queueId: String, data: SelfSensoredData)
    func sendingDataToServerUpdate(queueId: String, index: Int, total: Int)
}

class SelfSensoredServer {
    
    var delegate: SelfSensoredServerDelegate?
    var dataQueuedToSend: [String:SelfSensoredData] = [:]
    
    init() {

    }
    
    func latestDateOfActivity(user_id: Int, activity: String, completionHandler: @escaping (_ result: Date, _ error: String) -> Void){

        let url = "http://maddatum.com:3000/activities/" + activity + "/" + String(user_id) + "/latest"

        // Attempt to post data.
        Alamofire.request(url, method: .get, encoding: Alamofire.JSONEncoding.default).validate().responseJSON { response in
            switch response.result {
                case .success(let value):
                    let json = JSON(value)
                    let date = JSON(json["success"]).stringValue
                    completionHandler(date.toDate()?.date ?? "2000-12-31".toDate()!.date, "")
                case .failure(let error):
                    print(error)
                    completionHandler("2000-12-31".toDate()!.date, "error")
                    break
            }
        }
    }
    
    func queueDataToSend(dataId: String, data: [Dictionary<String, Any>]) {
        let parameters = dataToParametersArray(data: data)
        let data = SelfSensoredData(id: dataId, parameters: parameters)
        dataQueuedToSend[dataId] = data
        delegate?.dataQueuedToSend(queueId: dataId, data: data)
    }
    
    func dataToParametersArray(data: [Dictionary<String, Any>]) -> [Parameters] {
        var dataAsParameters: [Parameters] = []
        for entry in data {
            dataAsParameters.append(entry as Parameters)
        }
        return dataAsParameters
    }
    
    func send(data: SelfSensoredData) {
        let url = "http://maddatum.com:3000/activities/\(data.id)"
        if let firstEntry = data.data.first {
            Alamofire.request(url, method: .post, parameters: firstEntry, encoding: Alamofire.JSONEncoding.default).validate().responseJSON { response in
                if response.response?.statusCode == 200 {
                    self.delegate?.sendingDataToServerUpdate(queueId: data.id, index: data.data.count, total: data.totalItems)
                    data.data.removeFirst()
                    self.send(data: data)
                } else {
                    print("Failed request.")
                    self.send(data: data)
                }
            }
        } else {
            self.delegate?.completedSendingData()
        }
    }
    
}

