//
//  RootView.swift
//  hosmas
//
//  Decides login vs content, and hosts the captcha sheet the provider asks for.
//
//  Hostel sign-in gates the app. The canteen signs in separately from the Food
//  tab, so a HungerBox that is down or changed never blocks the hostel side.
//

import SwiftUI
import HosKhas

struct RootView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var login: LoginModel?
    @State private var profile: ProfileModel?
    @State private var food: FoodModel?
    @State private var orders: OrdersModel?
    @State private var canteenLogin: CanteenLoginModel?

    var body: some View {
        Group {
            switch login?.step {
            case .none:
                ProgressView()
            case .done:
                signedIn
            case .phone, .residentOTP:
                if let login {
                    LoginView(model: login)
                }
            }
        }
        .task {
            guard login == nil else { return }
            profile = ProfileModel(service: environment.resident)
            food = FoodModel(service: environment.canteen)
            orders = OrdersModel(service: environment.canteen)

            let canteenModel = CanteenLoginModel(service: environment.canteen)
            await canteenModel.restore()
            canteenLogin = canteenModel

            let model = LoginModel(resident: environment.resident)
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
            if let food, let canteenLogin {
                FoodView(model: food, login: canteenLogin)
                    .tabItem { Label("Food", systemImage: "fork.knife") }
            }
            if let orders, let canteenLogin {
                OrdersView(model: orders, login: canteenLogin)
                    .tabItem { Label("Orders", systemImage: "bag") }
            }
        }
    }

    private func signOut() {
        Task {
            // Hostel sign-out also drops the canteen — a half signed-out app has
            // nothing coherent to show.
            await canteenLogin?.signOut()
            login?.reset()
        }
    }
}
