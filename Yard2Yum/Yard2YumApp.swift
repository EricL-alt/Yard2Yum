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
        
        UserDefaults.standard.set("CyGiF77GlvN0qtl2KXrHK9YKk3aNsJVB", forKey: "typesense_api_key")
        UserDefaults.standard.set("sk1qa6e53tz4iurmp-1.a2.typesense.net", forKey: "typesense_host")
        
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
