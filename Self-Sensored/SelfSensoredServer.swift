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
    func dataQueuedToSend(queueId: String)
}

class SelfSensoredServer {
    
    var delegate: SelfSensoredServerDelegate?
    var dataQueuedToSend: [String:[Parameters]] = [:]
    
    init() {

    }
    
    func latestDateOfActivity(user_id: String, activity: String, completionHandler: @escaping (_ result: Date, _ error: String) -> Void){

        let url = "http://maddatum.com:3000/activities/" + activity + "/" + (user_id) + "/latest"

        // Attempt to post data.
        Alamofire.request(url, method: .get, encoding: Alamofire.JSONEncoding.default).validate().responseJSON { response in
            switch response.result {
                case .success(let value):
                    let json = JSON(value)
                    let date = JSON(json["success"]).stringValue
                    completionHandler(date.toDate()?.date ?? "2019-12-31".toDate()!.date, "")
                case .failure(let error):
                    print(error)
                    completionHandler("2019-12-31".toDate()!.date, "error")
                    break
            }
        }
    }
    
    func queueDataToSend(dataId: String, data: [Dictionary<String, Any>]) {
        print(dataId)
        let parameters = dataToParametersArray(data: data)
        dataQueuedToSend[dataId] = parameters
        delegate?.dataQueuedToSend(queueId: dataId)
    }
    
    func dataToParametersArray(data: [Dictionary<String, Any>]) -> [Parameters] {
        var dataAsParameters: [Parameters] = []
        for entry in data {
            dataAsParameters.append(entry as Parameters)
        }
        return dataAsParameters
    }
    
    func send(queueId: String) {
        let url = "http://maddatum.com:3000/activities/\(queueId)"
        if let firstEntry = dataQueuedToSend[queueId]?.first {
            Alamofire.request(url, method: .post, parameters: firstEntry, encoding: Alamofire.JSONEncoding.default).validate().responseJSON { response in
                if response.response?.statusCode == 200 {
                        self.dataQueuedToSend[queueId]?.removeFirst()
                        self.send(queueId: queueId)
                } else {
                    print("Failed request.")
                }
            }
        } else {
            self.delegate?.completedSendingData()
        }

    }
    
}

