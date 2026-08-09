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

    private enum Field { case phone, residentOTP, canteenOTP }

    var body: some View {
        Form {
            Section("Phone") {
                TextField("10-digit number", text: $model.phoneNumber)
                    .keyboardType(.numberPad)
                    .textContentType(.telephoneNumber)
                    .focused($focus, equals: .phone)
                    .disabled(model.step != .phone)
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
                    Text("Sent by Fretbox to ••••\(model.phoneNumber.suffix(4)).")
                }

            case .canteenOTP:
                Section {
                    TextField("Code", text: $model.canteenOTP)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .focused($focus, equals: .canteenOTP)
                } header: {
                    Text("Canteen code")
                } footer: {
                    Text("Hostel sign-in done. HungerBox sent a second code to \(model.canteenOTPDestination ?? "your phone").")
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

                if model.step == .canteenOTP {
                    Button("Skip canteen for now") {
                        Task { await model.skipCanteen() }
                    }
                    .foregroundStyle(.secondary)
                    .disabled(model.isBusy)
                }
            }
        }
        .animation(.default, value: model.step)
        .overlay { if model.isBusy { ProgressView() } }
        .onChange(of: model.step) { _, step in
            // Move the caret to whichever code was just requested.
            switch step {
            case .residentOTP: focus = .residentOTP
            case .canteenOTP: focus = .canteenOTP
            case .phone: focus = .phone
            case .done: focus = nil
            }
        }
    }

    private var primaryTitle: String {
        switch model.step {
        case .phone: "Send Code"
        case .residentOTP: "Verify Hostel Code"
        case .canteenOTP: "Verify Canteen Code"
        case .done: "Done"
        }
    }

    private var isPrimaryEnabled: Bool {
        switch model.step {
        case .phone: model.phoneNumber.count >= 10
        case .residentOTP: !model.residentOTP.isEmpty
        case .canteenOTP: !model.canteenOTP.isEmpty
        case .done: false
        }
    }

    private func primaryAction() async {
        switch model.step {
        case .phone: await model.sendResidentOTP()
        case .residentOTP: await model.verifyResidentOTP()
        case .canteenOTP: await model.verifyCanteenOTP()
        case .done: break
        }
    }
}
