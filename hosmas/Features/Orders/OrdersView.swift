//
//  OrdersView.swift
//  hosmas
//
//  Past orders. Read-only, and it exercises the same CanteenOrder that
//  checkout depends on — so this is the safe place to confirm the order shape
//  decodes live data.
//

import SwiftUI
import HosKhas

struct OrdersView: View {
    @Bindable var model: OrdersModel

    var body: some View {
        NavigationStack {
            List(model.orders, id: \.orderRef) { order in
                OrderRow(order: order)
            }
            .overlay {
                if model.isLoading && model.orders.isEmpty {
                    ProgressView()
                } else if let errorMessage = model.errorMessage, model.orders.isEmpty {
                    ContentUnavailableView(
                        "Couldn't load orders",
                        systemImage: "bag",
                        description: Text(errorMessage)
                    )
                } else if !model.isLoading && model.orders.isEmpty {
                    ContentUnavailableView(
                        "No orders yet",
                        systemImage: "bag",
                        description: Text("Orders you place show up here.")
                    )
                }
            }
            .navigationTitle("Orders")
            .refreshable { await model.load() }
            .task { await model.load() }
        }
    }
}

private struct OrderRow: View {
    let order: CanteenOrder

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(order.counterReference ?? order.orderRef)
                    .font(.headline)
                Spacer()
                if let total = order.totalOrderValue {
                    Text(total, format: .currency(code: "INR")).monospacedDigit()
                }
            }

            if !order.products.isEmpty {
                Text(itemSummary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 6) {
                StatusBadge(order: order)
                if let date = order.createdAt {
                    Text(date, format: .dateTime.day().month().hour().minute())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }

    /// "Tea ×2, Mrp Chips" — quantities collapsed per product.
    private var itemSummary: String {
        var counts: [String: Int] = [:]
        var order: [String] = []
        for product in self.order.products {
            let name = product.productName ?? "Item"
            if counts[name] == nil { order.append(name) }
            counts[name, default: 0] += product.qty ?? 1
        }
        return order
            .map { counts[$0] == 1 ? $0 : "\($0) ×\(counts[$0] ?? 1)" }
            .joined(separator: ", ")
    }
}

private struct StatusBadge: View {
    let order: CanteenOrder

    var body: some View {
        Text(label)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(colour.opacity(0.15), in: Capsule())
            .foregroundStyle(colour)
    }

    private var label: String {
        // The backend's own vocabulary, tidied for display.
        (order.status ?? order.paymentStatus ?? "unknown")
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }

    private var colour: Color {
        switch order.status {
        case "delivered": .green
        case "payment_failed", "cancelled", "rejected": .red
        case "payment_pending": .orange
        default: .secondary
        }
    }
}
