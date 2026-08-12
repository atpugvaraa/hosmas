//
//  FoodView.swift
//  hosmas
//
//  The canteen menu for whichever meal is being served now, grouped by
//  category the way the official client orders it.
//

import SwiftUI
import HosKhas

struct FoodView: View {
    @Bindable var model: FoodModel
    @Environment(AppEnvironment.self) private var environment
    /// Built on tap rather than up front — checkout reads a live cart, so it
    /// should not be loading one behind the menu.
    @State private var checkout: CheckoutModel?
    @State private var isCheckingOut = false

    var body: some View {
        NavigationStack {
            List {
                if !model.occasions.isEmpty {
                    Section {
                        Picker("Meal", selection: occasionSelection) {
                            ForEach(model.occasions) { occasion in
                                Text(occasion.name).tag(occasion.id)
                            }
                        }
                        .pickerStyle(.menu)

                        Toggle("Vegetarian only", isOn: vegOnly)
                    }
                }

                if let cartMessage = model.cartMessage {
                    Section {
                        Label(cartMessage, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                }

                ForEach(model.visibleSections) { section in
                    Section(section.title) {
                        ForEach(section.items) { item in
                            MenuRow(
                                item: item,
                                quantity: model.quantity(for: item),
                                isPending: model.isPending(item),
                                canIncrease: model.canIncrease(item),
                                onAdd: { Task { await model.add(item) } },
                                onRemove: { Task { await model.decrement(item) } }
                            )
                        }
                    }
                }
            }
            .overlay {
                if model.isLoading && model.sections.isEmpty {
                    ProgressView()
                } else if let errorMessage = model.errorMessage, model.sections.isEmpty {
                    ContentUnavailableView(
                        "Couldn't load the menu",
                        systemImage: "fork.knife",
                        description: Text(errorMessage)
                    )
                } else if !model.isLoading && model.visibleSections.isEmpty {
                    ContentUnavailableView(
                        "Nothing on the menu",
                        systemImage: "fork.knife",
                        description: Text(model.selectedOccasion.map { "No items for \($0.name) right now." }
                            ?? "No items right now.")
                    )
                }
            }
            .navigationTitle("Food")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        checkout = CheckoutModel(service: environment.canteen)
                        isCheckingOut = true
                    } label: {
                        Label("Cart", systemImage: "cart")
                    }
                    .badge(model.cartItemCount)
                }
            }
            .sheet(isPresented: $isCheckingOut) {
                if let checkout {
                    CheckoutView(model: checkout)
                }
            }
            .onChange(of: isCheckingOut) { _, presenting in
                // Placing an order consumes the cart, so the badge is stale the
                // moment checkout closes.
                guard !presenting else { return }
                Task { await model.refreshCart() }
            }
            .refreshable { await model.load() }
            .task { await model.load() }
        }
    }

    private var occasionSelection: Binding<Int> {
        Binding(
            get: { model.selectedOccasion?.id ?? -1 },
            set: { id in
                guard let occasion = model.occasions.first(where: { $0.id == id }) else { return }
                Task { await model.select(occasion) }
            }
        )
    }

    private var vegOnly: Binding<Bool> {
        Binding(get: { model.vegOnly }, set: { model.setVegOnly($0) })
    }
}

private struct MenuRow: View {
    let item: MenuItem
    let quantity: Int
    let isPending: Bool
    let canIncrease: Bool
    let onAdd: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            VegBadge(isVeg: item.isVeg)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                if let description = item.description?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                price
                stepper
            }
        }
        // The quantity shown is whatever the backend last reported, so it can
        // change without this row being touched.
        .animation(.default, value: quantity)
    }

    @ViewBuilder
    private var stepper: some View {
        if item.amount == nil {
            // Without a price there is no valid mutation body to send.
            EmptyView()
        } else if quantity == 0 {
            Button(action: onAdd) {
                Text("Add").font(.subheadline.weight(.medium))
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .controlSize(.small)
            .disabled(isPending)
        } else {
            HStack(spacing: 12) {
                stepperButton("minus", action: onRemove, enabled: true)
                Text("\(quantity)")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .frame(minWidth: 16)
                stepperButton("plus", action: onAdd, enabled: canIncrease)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.tint.opacity(0.12), in: Capsule())
            .overlay {
                if isPending { ProgressView().controlSize(.mini) }
            }
            .opacity(isPending ? 0.4 : 1)
        }
    }

    private func stepperButton(_ symbol: String, action: @escaping () -> Void, enabled: Bool) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.caption.weight(.bold))
        }
        .buttonStyle(.plain)
        .foregroundStyle(enabled ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
        // Rows live in a List, so the tap has to stay on the button.
        .buttonRepeatBehavior(.disabled)
        .disabled(!enabled || isPending)
    }

    @ViewBuilder
    private var price: some View {
        if let discounted = item.discountedAmount, let full = item.amount, discounted < full {
            VStack(alignment: .trailing, spacing: 0) {
                Text(full, format: .currency(code: "INR"))
                    .strikethrough()
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(discounted, format: .currency(code: "INR"))
                    .monospacedDigit()
            }
        } else if let amount = item.amount {
            Text(amount, format: .currency(code: "INR"))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }
}

/// The green/brown square Indian menus use to mark vegetarian items.
private struct VegBadge: View {
    let isVeg: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .stroke(isVeg ? .green : .brown, lineWidth: 1.5)
            .frame(width: 12, height: 12)
            .overlay {
                Circle()
                    .fill(isVeg ? .green : .brown)
                    .frame(width: 6, height: 6)
            }
            .accessibilityLabel(isVeg ? "Vegetarian" : "Non-vegetarian")
    }
}
