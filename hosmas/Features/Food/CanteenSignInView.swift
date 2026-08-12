//
//  CanteenSignInView.swift
//  hosmas
//
//  Canteen sign-in, shown inside the Food tab. Separate from the hostel login
//  because HungerBox is a separate identity — the phone or email here may not
//  be the one the hostel is under.
//

import SwiftUI
import HosKhas

struct CanteenSignInView: View {
    @Bindable var login: CanteenLoginModel
    @FocusState private var focus: Field?

    private enum Field { case identifier, otp }

    var body: some View {
        Form {
            Section {
                TextField("Phone number or email", text: $login.identifier)
                    .keyboardType(.emailAddress)
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focus, equals: .identifier)
                    .disabled(login.step != .identifier)
            } header: {
                Text("Canteen sign-in")
            } footer: {
                Text("HungerBox uses its own login — the number or email your canteen account is under.")
            }

            if login.step == .otp {
                Section {
                    TextField("Code", text: $login.otp)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .focused($focus, equals: .otp)
                } header: {
                    Text("Canteen code")
                } footer: {
                    Text("Sent to \(login.otpDestination ?? "your phone").")
                }
            }

            if let errorMessage = login.errorMessage {
                Section { Text(errorMessage).foregroundStyle(.red) }
            }

            Section {
                Button(primaryTitle) {
                    Task { await primaryAction() }
                }
                .disabled(login.isBusy || !isPrimaryEnabled)
            }
        }
        .overlay { if login.isBusy { ProgressView() } }
        .animation(.default, value: login.step)
        .onChange(of: login.step) { _, step in
            switch step {
            case .identifier: focus = .identifier
            case .otp: focus = .otp
            case .signedIn: focus = nil
            }
        }
    }

    private var primaryTitle: String {
        switch login.step {
        case .identifier: "Send Code"
        case .otp: "Verify"
        case .signedIn: "Done"
        }
    }

    private var isPrimaryEnabled: Bool {
        switch login.step {
        case .identifier: !login.identifier.isEmpty
        case .otp: !login.otp.isEmpty
        case .signedIn: false
        }
    }

    private func primaryAction() async {
        switch login.step {
        case .identifier: await login.sendOTP()
        case .otp: await login.verify()
        case .signedIn: break
        }
    }
}
