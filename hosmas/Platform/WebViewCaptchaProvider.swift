//
//  WebViewCaptchaProvider.swift
//  hosmas
//
//  hCaptcha runs in a WKWebView, which is Apple-only, so it lives here and
//  satisfies HosKhas's CaptchaTokenProvider from outside the package.
//
//  freshToken() suspends, flips `isPresenting`, and RootView shows the sheet.
//  The page's JS bridge posts the token back and the continuation resumes.
//

import Foundation
import SwiftUI
import WebKit
import HosKhas

@MainActor
@Observable
final class WebViewCaptchaProvider: CaptchaTokenProvider {
    /// The page the official app loads. Only the token leaves this view.
    let url = URL(string: "https://admintest.fretbox.in/assets/hcaptcha.html")!

    private(set) var isPresenting = false
    private var continuation: CheckedContinuation<String, any Error>?

    enum CaptchaError: Error {
        case cancelled
        case alreadyRunning
    }

    nonisolated func freshToken() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            Task { @MainActor in
                guard self.continuation == nil else {
                    HKLog.warning("captcha", "freshToken() called while a challenge is already open")
                    continuation.resume(throwing: CaptchaError.alreadyRunning)
                    return
                }
                HKLog.info("captcha", "presenting challenge — \(self.url.absoluteString)")
                self.continuation = continuation
                self.isPresenting = true
            }
        }
    }

    func complete(with token: String) {
        guard continuation != nil else {
            // The page can post more than once; ignore anything after the first.
            HKLog.trace("captcha", "token arrived with no pending request, ignoring")
            return
        }
        HKLog.info("captcha", "solved \(HKLog.fingerprint(token))")
        isPresenting = false
        continuation?.resume(returning: token)
        continuation = nil
    }

    func cancel() {
        guard continuation != nil else { return }
        HKLog.info("captcha", "dismissed without solving")
        isPresenting = false
        continuation?.resume(throwing: CaptchaError.cancelled)
        continuation = nil
    }
}

struct CaptchaWebView: UIViewRepresentable {
    let url: URL
    let onToken: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onToken: onToken) }

    final class Coordinator: NSObject, WKScriptMessageHandler {
        let onToken: (String) -> Void

        init(onToken: @escaping (String) -> Void) {
            self.onToken = onToken
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard message.name == "Captcha",
                  let token = message.body as? String,
                  !token.isEmpty else { return }
            onToken(token)
        }
    }

    func makeUIView(context: Context) -> WKWebView {
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "Captcha")

        // The page expects a Flutter-style Captcha channel; bridge it to WKWebView.
        contentController.addUserScript(
            WKUserScript(
                source: """
                window.Captcha = {
                    postMessage: function(message) {
                        window.webkit.messageHandlers.Captcha.postMessage(message);
                    }
                };
                """,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: false
            )
        )

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = contentController

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.load(URLRequest(url: url))
        return webView
    }

    // Loading happens once in makeUIView — reloading here would restart the
    // challenge on every SwiftUI update.
    func updateUIView(_ webView: WKWebView, context: Context) {}
}
