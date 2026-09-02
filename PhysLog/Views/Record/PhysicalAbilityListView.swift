import SwiftUI
import SwiftData

struct PhysicalAbilityListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \PhysicalAbility.date, order: .reverse) private var records: [PhysicalAbility]

    @State private var filter: String? = nil
    @State private var editing: PhysicalAbility? = nil
    @State private var isAdding = false

    private var types: [String] {
        Array(Set(records.map(\.type))).sorted()
    }

    private var filtered: [PhysicalAbility] {
        guard let filter else { return records }
        return records.filter { $0.type == filter }
    }

    /// 種目ごとのベスト記録値を求める（自己ベスト判定用）
    private var bestValues: [String: Double] {
        var result: [String: Double] = [:]
        for record in records {
            let lowerBetter = AbilityPreset.isLowerBetter(record.type)
            if let current = result[record.type] {
                result[record.type] = lowerBetter ? min(current, record.value) : max(current, record.value)
            } else {
                result[record.type] = record.value
            }
        }
        return result
    }

    var body: some View {
        VStack(spacing: 0) {
                if !types.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            Chip(label: "すべて", isSelected: filter == nil, color: .physlogAccent) {
                                filter = nil
                            }
                            ForEach(types, id: \.self) { type in
                                Chip(label: type, isSelected: filter == type, color: .physlogAccent) {
                                    filter = (filter == type) ? nil : type
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                    .fadeTrailingEdge()
                }

                if filtered.isEmpty {
                    EmptyStateView(
                        icon: "figure.run",
                        title: "身体能力の記録がありません",
                        message: "垂直跳び・50m走・握力など、\nスポーツの土台となる数値を残していきましょう"
                    )
                } else {
                    List {
                        ForEach(filtered) { record in
                            Button {
                                editing = record
                            } label: {
                                PhysicalAbilityRow(
                                    record: record,
                                    isBest: bestValues[record.type] == record.value
                                )
                            }
                            .buttonStyle(.plain)
                            .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        }
                        .onDelete { offsets in
                            for index in offsets { context.delete(filtered[index]) }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
        }
        .floatingAddButton { isAdding = true }
        .sheet(isPresented: $isAdding) {
            PhysicalAbilityEditor(record: nil)
        }
        .sheet(item: $editing) { record in
            PhysicalAbilityEditor(record: record)
        }
    }
}

// MARK: - 行

struct PhysicalAbilityRow: View {
    let record: PhysicalAbility
    let isBest: Bool

    var body: some View {
        Card(padding: 14) {
            HStack(spacing: 12) {
                Image(systemName: AbilityPreset.icon(for: record.type))
                    .foregroundStyle(Color.physlogAccent)
                    .frame(width: 42, height: 42)
                    .background(Color.physlogAccent.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(record.type)
                            .font(.subheadline.weight(.semibold))
                        if isBest {
                            Text("自己ベスト")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.physlogOrange.opacity(0.16), in: Capsule())
                                .foregroundStyle(Color.physlogOrange)
                        }
                    }
                    Text(record.date.shortJP)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text(record.formattedValue)
                        .font(.title3.bold())
                        .foregroundStyle(Color.physlogAccent)
                    Text(record.unit)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - 追加・編集

struct PhysicalAbilityEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let record: PhysicalAbility?

    @State private var date = Date()
    @State private var selectedPreset: String = AbilityPreset.all[0].name
    @State private var isCustom = false
    @State private var customName = ""
    @State private var customUnit = ""
    @State private var valueText = ""
    @State private var memo = ""

    private var effectiveName: String {
        isCustom ? customName.trimmingCharacters(in: .whitespaces) : selectedPreset
    }

    private var effectiveUnit: String {
        isCustom ? customUnit.trimmingCharacters(in: .whitespaces)
                 : (AbilityPreset.find(selectedPreset)?.unit ?? "")
    }

    private var canSave: Bool {
        !effectiveName.isEmpty && Double(valueText) != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("日付", selection: $date, displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "ja_JP"))
                }

                Section("種目") {
                    Toggle("自由入力", isOn: $isCustom.animation())

                    if isCustom {
                        TextField("種目名（例：ベンチプレス1RM）", text: $customName)
                        TextField("単位（例：kg / 秒 / cm）", text: $customUnit)
                    } else {
                        Picker("種目", selection: $selectedPreset) {
                            ForEach(AbilityPreset.all) { preset in
                                Text("\(preset.name)（\(preset.unit)）").tag(preset.name)
                            }
                        }
                        .pickerStyle(.navigationLink)
                    }
                }

                Section("記録値") {
                    HStack {
                        TextField("数値を入力", text: $valueText)
                            .keyboardType(.decimalPad)
                        Text(effectiveUnit)
                            .foregroundStyle(.secondary)
                    }
                    if !isCustom, AbilityPreset.isLowerBetter(selectedPreset) {
                        Text("この種目はタイムが短いほど良い記録として扱われます")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("メモ") {
                    TextField("計測条件・コンディションなど", text: $memo, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .navigationTitle(record == nil ? "身体能力を記録" : "記録を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard let record else { return }
        date = record.date
        valueText = String(record.value)
        memo = record.memo
        if AbilityPreset.find(record.type) != nil {
            selectedPreset = record.type
        } else {
            isCustom = true
            customName = record.type
            customUnit = record.unit
        }
    }

    private func save() {
        guard let value = Double(valueText) else { return }

        if let record {
            record.date = date
            record.type = effectiveName
            record.value = value
            record.unit = effectiveUnit
            record.memo = memo
        } else {
            context.insert(PhysicalAbility(
                date: date, type: effectiveName, value: value, unit: effectiveUnit, memo: memo
            ))
        }
        dismiss()
    }
}

#Preview {
    PhysicalAbilityListView()
        .modelContainer(PreviewData.container)
}
