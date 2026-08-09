//
//  RootView.swift
//  hosmas
//
//  Decides login vs content, and hosts the captcha sheet the provider asks for.
//

import SwiftUI
import HosKhas

struct RootView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var login: LoginModel?
    @State private var profile: ProfileModel?
    @State private var food: FoodModel?

    var body: some View {
        Group {
            switch login?.step {
            case .none:
                ProgressView()
            case .done:
                signedIn
            case .phone, .residentOTP, .canteenOTP:
                if let login {
                    LoginView(model: login)
                }
            }
        }
        .task {
            guard login == nil else { return }
            profile = ProfileModel(service: environment.resident)
            food = FoodModel(service: environment.canteen)
            let model = LoginModel(resident: environment.resident, canteen: environment.canteen)
            await model.restore()
            login = model
        }
        .sheet(isPresented: Binding(
            get: { environment.captcha.isPresenting },
            set: { if !$0 { environment.captcha.cancel() } }
        )) {
            CaptchaWebView(url: environment.captcha.url) { token in
                environment.captcha.complete(with: token)
            }
            .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private var signedIn: some View {
        TabView {
            if let profile {
                ProfileView(model: profile) { signOut() }
                    .tabItem { Label("Profile", systemImage: "person.crop.circle") }
            }
            if let food {
                FoodView(model: food)
                    .tabItem { Label("Food", systemImage: "fork.knife") }
            }
        }
    }

    private func signOut() {
        Task {
            // Both sessions go — they were established together and a half
            // signed-out state has nothing to show.
            try? await environment.canteen.logout()
            login?.reset()
        }
    }
}
