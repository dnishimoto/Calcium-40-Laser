//
//  Calcium_40_LaserApp.swift
//  Calcium 40 Laser
//
//  Created by David Nishimoto on 9/13/26.
//

import SwiftUI
import CoreData

@main
struct Calcium_40_LaserApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
