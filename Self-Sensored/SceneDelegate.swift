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
import Alamofire

class SceneDelegate: UIResponder, UIWindowSceneDelegate, HKQueryDelegate {
    func queryComplete(results: [Dictionary<String, Any>], identifier: String) {
        // Convert to Alamofire parameters.
        for result in results {
                    let parameters : Parameters = result
                    let url = "http://maddatum.com:3000/activities/\(identifier)"
                    Alamofire.request(url, method: .post, parameters: parameters, encoding: Alamofire.JSONEncoding.default).response { response in
            //                                                            print(response)
                    }
        }
    }

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
        
        let activity = HKQuantityTypeIdentifier.restingHeartRate
        
        let readDataTypes : Set = [HKObjectType.quantityType(forIdentifier: activity)!,
                                   HKObjectType.characteristicType(forIdentifier: HKCharacteristicTypeIdentifier.biologicalSex)!,
                                   HKObjectType.characteristicType(forIdentifier: HKCharacteristicTypeIdentifier.dateOfBirth)!,
                                   HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.bodyMass)!]
        
        let writeDataTypes : Set = [HKObjectType.quantityType(forIdentifier: activity)!]
        
        let hkh = HealthKitHelper(readDataTypes: readDataTypes, writeDataTypes: writeDataTypes)
        
        hkh.delegate = self
        
        hkh.queryQuantityTypeByDateRange(user_id: 1, activity: activity, queryStartDate: "2019-11-03", queryEndDate: "2020-01-01")
        
    }
    
    func sceneDidDisconnect(_ scene: UIScene) {

    }

    func sceneDidBecomeActive(_ scene: UIScene) {

    }

    func sceneWillResignActive(_ scene: UIScene) {

    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        (UIApplication.shared.delegate as? AppDelegate)?.saveContext()
    }


}

