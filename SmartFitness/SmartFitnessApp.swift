//
//  SmartFitnessApp.swift
//  SmartFitness
//
//  Created by Jeremy chen on 2026/3/19.
//

import SwiftUI

@main
struct SmartFitnessApp: App {
    @StateObject private var appData = AppData()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appData)
        }
    }
}
