//
//  LoginView.swift
//  hosmas
//
//  Pure rendering — every decision (which step, busy, error text) is already
//  made by LoginModel inside the package.
//
//  One code at a time: both SMS come from the same number, so asking for them
//  together invites typing the wrong one into the wrong field.
//

import SwiftUI
import HosKhas

struct LoginView: View {
    @Bindable var model: LoginModel
    @FocusState private var focus: Field?

    private enum Field { case phone, residentOTP }

    var body: some View {
        Form {
            Section {
                TextField("Phone number or email", text: $model.identifier)
                    .keyboardType(.emailAddress)
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focus, equals: .phone)
                    .disabled(model.step != .phone)
            } header: {
                Text("Sign in")
            } footer: {
                // Some hostels are tagged to a college email, not the phone.
                Text("Use whichever your hostel account is under.")
            }

            switch model.step {
            case .residentOTP:
                Section {
                    TextField("4-digit code", text: $model.residentOTP)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .focused($focus, equals: .residentOTP)
                } header: {
                    Text("Hostel code")
                } footer: {
                    Text("Sent by Fretbox to \(model.loginIdentifier.masked).")
                }

            case .phone, .done:
                EmptyView()
            }

            if let errorMessage = model.errorMessage {
                Section { Text(errorMessage).foregroundStyle(.red) }
            }

            Section {
                Button(primaryTitle) {
                    Task { await primaryAction() }
                }
                .disabled(model.isBusy || !isPrimaryEnabled)
            }
        }
        .animation(.default, value: model.step)
        .overlay { if model.isBusy { ProgressView() } }
        .onChange(of: model.step) { _, step in
            // Move the caret to whichever code was just requested.
            switch step {
            case .residentOTP: focus = .residentOTP
            case .phone: focus = .phone
            case .done: focus = nil
            }
        }
    }

    private var primaryTitle: String {
        switch model.step {
        case .phone: "Send Code"
        case .residentOTP: "Verify Hostel Code"
        case .done: "Done"
        }
    }

    private var isPrimaryEnabled: Bool {
        switch model.step {
        case .phone: model.loginIdentifier.isPlausible
        case .residentOTP: !model.residentOTP.isEmpty
        case .done: false
        }
    }

    private func primaryAction() async {
        switch model.step {
        case .phone: await model.sendResidentOTP()
        case .residentOTP: await model.verifyResidentOTP()
        case .done: break
        }
    }
}
