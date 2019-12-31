//
//  SceneDelegate.swift
//  Self-Sensored
//
//  Created by Casey Brittain on 12/29/19.
//  Copyright © 2019 Casey Brittain. All rights reserved.
//
// https://medium.com/react-native-training/how-to-handle-background-app-refresh-with-healthkit-in-react-native-3a32704461fe

import UIKit
import SwiftUI
import HealthKit
import SwiftyJSON


class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    let healthStore = HKHealthStore()
    var window: UIWindow?


    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).

        // Get the managed object context from the shared persistent container.
        let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext

        // Create the SwiftUI view and set the context as the value for the managedObjectContext environment keyPath.
        // Add `@Environment(\.managedObjectContext)` in the views that will need the context.
        let contentView = ContentView().environment(\.managedObjectContext, context)

        // Use a UIHostingController as window root view controller.
        if let windowScene = scene as? UIWindowScene {
            let window = UIWindow(windowScene: windowScene)
            window.rootViewController = UIHostingController(rootView: contentView)
            self.window = window
            window.makeKeyAndVisible()
        }
        
        if HKHealthStore.isHealthDataAvailable() {
            let readDataTypes : Set = [HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.stepCount)!,
                                       HKObjectType.characteristicType(forIdentifier: HKCharacteristicTypeIdentifier.biologicalSex)!,
                                       HKObjectType.characteristicType(forIdentifier: HKCharacteristicTypeIdentifier.dateOfBirth)!,
                                       HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.bodyMass)!]
            
            let writeDataTypes : Set = [HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.stepCount)!]
            
            healthStore.requestAuthorization(toShare: writeDataTypes, read: readDataTypes) { (success, error) in
                if !success {
                    // Handle the error here.
                } else {
                    self.queryStepsByDateRange(queryStartDate: "2019-10-01", queryEndDate: "2019-10-02")
                    
                }
            }
        }
        
    }
    
    // HKSampleQuery with a predicate
    func queryStepsByDateRange(queryStartDate: String, queryEndDate: String) {
        
        // Set dates to midnight
        let startDateAsString = queryStartDate + "T00:00:00+0000"
        let endDateAsString = queryEndDate + "T00:00:00+0000"

        // Convert to Date objects
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX") // set locale to reliable US_POSIX
        let startDate = dateFormatter.date(from:startDateAsString)!
        let endDate  = dateFormatter.date(from:endDateAsString)!
        
        let sampleType = HKSampleType.quantityType(forIdentifier: HKQuantityTypeIdentifier.stepCount)
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: HKQueryOptions.strictEndDate)
        
        var stepsByDateAndTime: [Date:Double] = [:]
        
        let query = HKSampleQuery.init(sampleType: sampleType!,
                                       predicate: predicate,
                                       limit: HKObjectQueryNoLimit,
                                       sortDescriptors: nil) { (query, results, error) in
                                        if let results = results  {
                                            var index = 0
                                            for result in results as! [HKQuantitySample] {
                                                // Steps info
                                                let dateOfSteps = result.startDate
                                                let numberOfSteps = result.quantity.doubleValue(for: HKUnit.count())

                                                // Device information.
                                                stepsByDateAndTime[dateOfSteps] = numberOfSteps
                                                index += 1
                                                self.HKQuantitySampleToJSON(user_id: 1, sample: result)
                                            }
                                        }

        }
        
        healthStore.execute(query)
    }
    
    func HKQuantitySampleToJSON(user_id: Int, sample: HKQuantitySample?) -> JSON {
        
        let deviceJSON: JSON = [
            "name": sample?.device?.name ?? "Unknown",
            "model": sample?.device?.model ?? "Unknown",
            "firmware": sample?.device?.firmwareVersion ?? "Unknown",
            "local_identifier": sample?.device?.localIdentifier ?? "Unknown",
            "manufacturer": sample?.device?.manufacturer ?? "Unknown",
            "software_version": sample?.device?.softwareVersion ?? "Unknown",
            "uuid": sample?.device?.udiDeviceIdentifier ?? "Unknown"
        ]
        
        guard let sample = sample else {
            let error: JSON = ["error": "Missing sample."]
            return error
        }
        
        let packet: JSON = [
            "user_id": user_id,
            "date": sample.startDate.toString(),
            "activity_type": sample.sampleType.identifier,
            "quantity_type": sample.quantityType.identifier,
            "quantity": sample.quantity.doubleValue(for: HKUnit.count()),
            "device": deviceJSON
        ]

        // Convert the JSON to a raw String
        if let rawString =  packet.rawString([.castNilToNSNull: true]) {
          print(rawString)
        } else {
            print("json.rawString is nil")
        }
        
        return packet
    }
    
    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not neccessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
        
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.

        // Save changes in the application's managed object context when the application transitions to the background.
        (UIApplication.shared.delegate as? AppDelegate)?.saveContext()
    }


}

extension Date {
    init(_ dateString:String) {
        let dateStringFormatter = DateFormatter()
        dateStringFormatter.dateFormat = "yyyy-MM-dd"
        dateStringFormatter.locale = NSLocale(localeIdentifier: "en_US_POSIX") as Locale
        let date = dateStringFormatter.date(from: dateString)!
        self.init(timeInterval:0, since:date)
    }
}

extension Date {
    func toString() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy'-'MM'-'dd'T'HH':'mm':'ssZZZ"
        return dateFormatter.string(from: self)
    }
}
