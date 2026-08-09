//
//  hosmasApp.swift
//  hosmas
//
//  Created by Aarav Gupta on 06/08/26.
//

import SwiftUI
import HosKhas

@main
struct hosmasApp: App {
    @State private var environment = AppEnvironment()

    init() {
        HKLog.info("app", "hosmas launching")
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(environment)
        }
    }
}
