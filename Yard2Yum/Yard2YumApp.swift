//
//  Yard2YumApp.swift
//  Yard2Yum
//
//  Created by Eric Liu on 08/03/2026.
//

import SwiftUI
import FirebaseCore
import FirebaseFirestore

@main
struct Yard2YumApp: App {
    init() {
        FirebaseApp.configure()
        
        // Configure Firestore settings
        let settings = FirestoreSettings()
        settings.isPersistenceEnabled = true
        Firestore.firestore().settings = settings
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
