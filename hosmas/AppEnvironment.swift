//
//  AppEnvironment.swift
//  hosmas
//
//  The only place platform types meet package types. Both services share one
//  disk cache directory and one Keychain, but nothing else — separate sessions,
//  separate hosts, separate header conventions.
//

import Foundation
import HosKhas

@MainActor
@Observable
final class AppEnvironment {
    let resident: ResidentService
    let canteen: CanteenService
    let captcha = WebViewCaptchaProvider()

    init() {
        let timer = HKLog.start("app", "environment-init")
        defer { HKLog.end(timer) }

        let cacheDirectory = URL.cachesDirectory.appending(path: "HosKhas")
        let cache = FileCacheStore(directory: cacheDirectory)
        let store = KeychainSecureStore()
        HKLog.trace("app", "cache at \(cacheDirectory.path())")

        // This init runs on the main thread before the first frame, so the
        // steps are timed separately — "environment-init took 936ms" does not
        // say which part to go and fix.
        let sessionTimer = HKLog.start("app", "url-session-warmup")
        _ = URLSession.shared
        HKLog.end(sessionTimer)

        let servicesTimer = HKLog.start("app", "service-construction")
        defer { HKLog.end(servicesTimer) }

        // Auth root, per capture. Not admintest.fretbox.in — that host only
        // serves the hCaptcha page (see WebViewCaptchaProvider).
        resident = ResidentService(
            baseURL: URL(string: "https://socialpoc.fretbox.in")!,
            cache: cache,
            captcha: captcha,
            store: store
        )

        canteen = CanteenService(
            baseURL: URL(string: "https://rest.hungerbox.com")!,
            config: Secrets.hungerBox,
            cache: cache,
            store: store
        )
    }
}
