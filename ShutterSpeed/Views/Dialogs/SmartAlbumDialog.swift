import SwiftUI

/// Dialog for creating and editing smart albums
struct SmartAlbumDialog: View {
    @Environment(\.dismiss) private var dismiss

    @State private var albumName = "New Smart Album"
    @State private var matchAll = true
    @State private var rules: [SmartAlbumRule] = [
        SmartAlbumRule(field: .rating, comparison: .greaterThan, value: "3")
    ]

    let onSave: (String, SmartAlbumCriteria) -> Void

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: "gearshape")
                    .font(.title)
                    .foregroundStyle(.tint)
                Text("Smart Album")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
            }

            // Name
            TextField("Album Name", text: $albumName)
                .textFieldStyle(.roundedBorder)

            // Match type
            HStack {
                Text("Match")
                Picker("", selection: $matchAll) {
                    Text("all").tag(true)
                    Text("any").tag(false)
                }
                .pickerStyle(.segmented)
                .frame(width: 100)
                Text("of the following rules:")
                Spacer()
            }

            // Rules
            VStack(spacing: 8) {
                ForEach(rules.indices, id: \.self) { index in
                    RuleRow(rule: $rules[index]) {
                        rules.remove(at: index)
                    }
                }

                Button(action: addRule) {
                    Label("Add Rule", systemImage: "plus.circle")
                }
                .buttonStyle(.borderless)
            }

            Spacer()

            // Actions
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Create") {
                    let criteria = SmartAlbumCriteria(rules: rules, matchAll: matchAll)
                    onSave(albumName, criteria)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(albumName.isEmpty || rules.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 500, height: 400)
    }

    private func addRule() {
        rules.append(SmartAlbumRule(field: .rating, comparison: .greaterThan, value: "3"))
    }
}

struct RuleRow: View {
    @Binding var rule: SmartAlbumRule
    let onDelete: () -> Void

    var body: some View {
        HStack {
            // Field picker
            Picker("", selection: $rule.field) {
                ForEach(SmartAlbumField.allCases, id: \.self) { field in
                    Text(field.displayName).tag(field)
                }
            }
            .frame(width: 120)

            // Comparison picker
            Picker("", selection: $rule.comparison) {
                ForEach(rule.field.validComparisons, id: \.self) { comparison in
                    Text(comparison.displayName).tag(comparison)
                }
            }
            .frame(width: 100)

            // Value input
            valueInput

            // Delete button
            Button(action: onDelete) {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.borderless)
        }
    }

    @ViewBuilder
    private var valueInput: some View {
        switch rule.field {
        case .rating:
            Picker("", selection: Binding(
                get: { Int(rule.value) ?? 0 },
                set: { rule.value = String($0) }
            )) {
                ForEach(0...5, id: \.self) { rating in
                    HStack(spacing: 2) {
                        ForEach(1...max(1, rating), id: \.self) { _ in
                            Image(systemName: "star.fill")
                        }
                    }
                    .tag(rating)
                }
            }
            .frame(width: 100)

        case .flag:
            Picker("", selection: $rule.value) {
                Text("Pick").tag("1")
                Text("Reject").tag("-1")
                Text("None").tag("0")
            }
            .frame(width: 100)

        case .keyword, .fileName:
            TextField("Value", text: $rule.value)
                .textFieldStyle(.roundedBorder)
                .frame(width: 150)

        case .camera, .lens:
            TextField("Camera/Lens", text: $rule.value)
                .textFieldStyle(.roundedBorder)
                .frame(width: 150)

        case .captureDate, .importDate:
            DatePicker("", selection: Binding(
                get: { dateFromString(rule.value) ?? Date() },
                set: { rule.value = dateToString($0) }
            ), displayedComponents: .date)
            .frame(width: 150)
        }
    }

    private func dateFromString(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: string)
    }

    private func dateToString(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: date)
    }
}

// MARK: - Extensions

extension SmartAlbumField {
    var displayName: String {
        switch self {
        case .rating: return "Rating"
        case .flag: return "Flag"
        case .keyword: return "Keyword"
        case .camera: return "Camera"
        case .lens: return "Lens"
        case .captureDate: return "Date Captured"
        case .importDate: return "Date Imported"
        case .fileName: return "File Name"
        }
    }

    var validComparisons: [SmartAlbumComparison] {
        switch self {
        case .rating:
            return [.equals, .greaterThan, .lessThan]
        case .flag:
            return [.equals, .notEquals]
        case .keyword, .fileName, .camera, .lens:
            return [.equals, .notEquals, .contains]
        case .captureDate, .importDate:
            return [.equals, .greaterThan, .lessThan, .between]
        }
    }
}

extension SmartAlbumComparison {
    var displayName: String {
        switch self {
        case .equals: return "is"
        case .notEquals: return "is not"
        case .contains: return "contains"
        case .greaterThan: return "is greater than"
        case .lessThan: return "is less than"
        case .between: return "is between"
        }
    }
}

#Preview {
    SmartAlbumDialog { name, criteria in
        print("Created: \(name) with \(criteria.rules.count) rules")
    }
}
