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

                ForEach(model.visibleSections) { section in
                    Section(section.title) {
                        ForEach(section.items) { item in
                            MenuRow(item: item)
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
            price
        }
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
