import SwiftUI

struct FoodRowView: View {
    let item: FoodItem
    /// Shown while searching, since results can come from either tab.
    var showsLocation: Bool = false

    @Environment(\.locale) private var locale

    private var dateFormatter: DateFormatter {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.locale = locale
        return df
    }

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)

                HStack(spacing: 4) {
                    Text(item.category.displayName)
                    if showsLocation {
                        Text(verbatim: "•")
                        Label(item.location.displayName, systemImage: item.location.systemImage)
                            .labelStyle(.titleAndIcon)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    if let quantity = item.quantity {
                        Label {
                            Text("\(quantity) pcs.")
                        } icon: {
                            Image(systemName: "number")
                        }
                    }
                    if let weight = item.weightInGrams {
                        Label(formattedWeight(weight), systemImage: "scalemass")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if let notes = item.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("Added")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(dateFormatter.string(from: item.dateAdded))
                    .font(.caption)

                if item.location == .freezer {
                    daysInFreezerBadge
                } else {
                    Text("\(item.daysSinceAdded) days ago")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let expiry = item.expiryDate {
                    Divider()
                    Text("Best before")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(dateFormatter.string(from: expiry))
                        .font(.caption)
                        .foregroundStyle(item.isExpired ? .red : (item.isExpiringSoon ? .orange : .primary))
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var daysInFreezerBadge: some View {
        let days = item.daysSinceAdded
        let (color, icon): (Color, String) = switch item.freezerFreshness {
        case .fresh: (.secondary, "")
        case .useSoon: (.orange, "clock")
        case .old: (.red, "exclamationmark.triangle.fill")
        }

        return HStack(spacing: 3) {
            if !icon.isEmpty {
                Image(systemName: icon)
                    .font(.caption2)
            }
            Text("\(days) days in the freezer")
                .font(.caption2)
                .fontWeight(item.freezerFreshness == .fresh ? .regular : .semibold)
        }
        .foregroundStyle(color)
    }
}
