//
//  CheckoutView.swift
//  hosmas
//
//  Reads the server-side cart, hands the UPI request to a payment app, then
//  watches the payment settle.
//
//  Placing the order is the one irreversible, money-spending action in this
//  app. It is reachable only from a button, and only after a confirmation that
//  names the vendor and the exact amount.
//

import SwiftUI
import HosKhas

struct CheckoutView: View {
    @Bindable var model: CheckoutModel

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var isConfirming = false
    @State private var didCopyLink = false

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Checkout")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Close") { dismiss() }
                    }
                }
                .task { await model.load() }
                .onChange(of: scenePhase) { _, phase in
                    // Coming back from a UPI app is the moment the result exists.
                    guard phase == .active, case .awaitingPayment = model.stage else { return }
                    Task { await model.pollUntilSettled() }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.stage {
        case .loading:
            ProgressView()

        case .empty:
            ContentUnavailableView {
                Label("Nothing in the cart", systemImage: "cart")
            } description: {
                // Honest about the current limitation: the add-to-cart call
                // hasn't been captured, so items still go in via HungerBox.
                Text("Add items in the HungerBox app — they'll show up here.")
            } actions: {
                Button("Reload") { Task { await model.load() } }
            }

        case .ready(let cart):
            cartForm(cart)

        case .awaitingPayment(let order):
            awaitingPayment(order)

        case .settled(let order):
            settled(order)
        }
    }

    // MARK: - Ready to pay

    private func cartForm(_ cart: Cart) -> some View {
        Form {
            Section("Items") {
                ForEach(cart.items) { item in
                    HStack {
                        Text(item.name)
                        if item.quantity > 1 {
                            Text("×\(item.quantity)")
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let total = item.itemTotal ?? item.price {
                            Text(total, format: .currency(code: "INR"))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section {
                LabeledContent("Total") {
                    Text(cart.total ?? 0, format: .currency(code: "INR"))
                        .monospacedDigit()
                        .fontWeight(.semibold)
                }
            } footer: {
                if let tax = cart.totalTax, tax > 0 {
                    Text("Includes \(tax, format: .currency(code: "INR")) tax.")
                }
            }

            Section {
                if let paymentUnavailable = model.paymentUnavailable {
                    // The cart loaded and payment did not — say which, rather
                    // than replacing the whole screen with an error.
                    Label(paymentUnavailable, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.secondary)
                    Button("Try again") { Task { await model.load() } }
                } else {
                    ForEach(model.wallets) { wallet in
                        ForEach(wallet.usableUPIMethods) { method in
                            Button {
                                model.select(method)
                            } label: {
                                HStack {
                                    Text(method.appDisplayName ?? method.method)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if model.selectedMethod?.id == method.id {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.tint)
                                    }
                                }
                            }
                        }
                    }
                }
            } header: {
                Text("Pay with")
            }

            if let errorMessage = model.errorMessage {
                Section { Text(errorMessage).foregroundStyle(.red) }
            }

            Section {
                Button("Place Order") { isConfirming = true }
                    .disabled(!model.canPlaceOrder)
            }
        }
        .overlay { if model.isPlacing { ProgressView() } }
        .confirmationDialog(
            confirmationTitle(cart),
            isPresented: $isConfirming,
            titleVisibility: .visible
        ) {
            Button("Place Order", role: .destructive) {
                Task { await placeAndHandOff() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This charges your UPI app immediately and can't be undone.")
        }
    }

    private func confirmationTitle(_ cart: Cart) -> String {
        let amount = (cart.total ?? 0).formatted(.currency(code: "INR"))
        let vendor = cart.vendorNames.first ?? "the canteen"
        return "Pay \(amount) to \(vendor)?"
    }

    // MARK: - Awaiting payment

    private func awaitingPayment(_ order: CanteenOrder) -> some View {
        Form {
            Section {
                LabeledContent("Order", value: order.counterReference ?? order.orderRef)
                LabeledContent("Status", value: "Waiting for payment")
                if let total = order.totalOrderValue {
                    LabeledContent("Amount") {
                        Text(total, format: .currency(code: "INR")).monospacedDigit()
                    }
                }
            } footer: {
                Text("Finish paying in your UPI app, then come back — this updates on its own.")
            }

            if let url = model.paymentURL {
                Section {
                    Button("Open payment app") { Task { await open(url) } }
                    Button(didCopyLink ? "Link copied" : "Copy payment link") {
                        UIPasteboard.general.string = url.absoluteString
                        didCopyLink = true
                    }
                    .foregroundStyle(.secondary)
                } footer: {
                    // If no installed app claims upi://, the link is still the
                    // whole payment request — better than a dead end.
                    Text("Copy it if nothing opens automatically.")
                }
            }

            if let errorMessage = model.errorMessage {
                Section { Text(errorMessage).foregroundStyle(.red) }
            }

            Section {
                Button("Check payment status") { Task { await model.refreshStatus() } }
            }
        }
    }

    // MARK: - Settled

    private func settled(_ order: CanteenOrder) -> some View {
        VStack(spacing: 16) {
            Image(systemName: order.didPaymentSucceed ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(order.didPaymentSucceed ? .green : .red)

            Text(order.didPaymentSucceed ? "Order placed" : "Payment failed")
                .font(.title2.weight(.semibold))

            if order.didPaymentSucceed, let reference = order.counterReference {
                Text("Quote \(reference) at the counter.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else if let message = order.failureMessage {
                Text(message)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
        }
        .padding(32)
    }

    // MARK: - Actions

    private func placeAndHandOff() async {
        await model.placeOrder()
        guard let url = model.paymentURL else { return }
        await open(url)
    }

    /// `open` reports whether anything took the URL, and unlike `canOpenURL` it
    /// needs no LSApplicationQueriesSchemes entry. A false means no installed
    /// app claims `upi://`, so the copy fallback is the way out.
    private func open(_ url: URL) async {
        let opened = await UIApplication.shared.open(url)
        if !opened {
            didCopyLink = false
            UIPasteboard.general.string = url.absoluteString
        }
    }
}
