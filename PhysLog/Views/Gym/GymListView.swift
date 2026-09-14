import SwiftUI
import SwiftData

// MARK: - ジム一覧

struct GymListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Gym.createdAt) private var gyms: [Gym]

    @State private var editing: Gym?
    @State private var isAdding = false

    var body: some View {
        Group {
            if gyms.isEmpty {
                EmptyStateView(
                    icon: "building.2",
                    title: "ジムが登録されていません",
                    message: "バーの重さやプレートの刻みを登録すると、\n記録するときにそのジムで作れる重量だけが候補に出ます"
                )
            } else {
                List {
                    ForEach(gyms) { gym in
                        Button {
                            editing = gym
                        } label: {
                            GymRow(gym: gym)
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                    .onDelete { offsets in
                        for index in offsets { context.delete(gyms[index]) }
                        // 既定のジムを消した場合、残りの先頭を既定にする
                        try? context.save()
                        if !gyms.contains(where: { $0.isDefault }), let first = gyms.first {
                            first.isDefault = true
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("ジム")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isAdding = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $isAdding) { GymEditor(gym: nil) }
        .sheet(item: $editing) { gym in GymEditor(gym: gym) }
    }
}

struct GymRow: View {
    let gym: Gym

    var body: some View {
        Card(padding: 14) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(gym.name)
                        .font(.subheadline.weight(.semibold))
                    if gym.isDefault {
                        Text("既定")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color.physlogPrimary.opacity(0.15), in: Capsule())
                            .foregroundStyle(Color.physlogPrimary)
                    }
                    Spacer()
                }
                Text(gym.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if !gym.memo.isEmpty {
                    Text(gym.memo)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }
}

// MARK: - ジムの追加・編集

struct GymEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var allGyms: [Gym]

    let gym: Gym?

    @State private var name = ""
    @State private var memo = ""
    @State private var isDefault = false

    @State private var barWeights: Set<Double> = [20]
    @State private var plateWeights: Set<Double> = [1.25, 2.5, 5, 10, 15, 20]

    @State private var dumbbellMin = "1"
    @State private var dumbbellMax = "40"
    @State private var dumbbellStep = "2"

    @State private var machineUnit: MachineUnit = .kilogram
    @State private var machineStepWeight = ""

    @State private var showPresets = false

    /// 選べるバーの種類。実際に置いてあるものにチェックを入れる。
    private let barOptions: [Double] = [20, 15, 10, 7.5, 5]
    private let plateOptions: [Double] = [0.5, 1.25, 2.5, 5, 10, 15, 20, 25]

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("ジム名", text: $name)
                    TextField("メモ（店舗名、備考など）", text: $memo, axis: .vertical)
                        .lineLimit(1...3)
                    Toggle("記録するときの既定にする", isOn: $isDefault)
                }

                if gym == nil {
                    Section {
                        Button {
                            showPresets = true
                        } label: {
                            Label("よくある構成から選ぶ", systemImage: "wand.and.stars")
                        }
                    } footer: {
                        Text("近いものを選んでから、違うところだけ直すのが早いです。")
                    }
                }

                // MARK: バーベル

                Section {
                    ForEach(barOptions, id: \.self) { w in
                        Toggle(isOn: Binding(
                            get: { barWeights.contains(w) },
                            set: { on in
                                if on { barWeights.insert(w) } else { barWeights.remove(w) }
                            }
                        )) {
                            Text("\(fmt(w)) kg バー")
                        }
                    }
                } header: {
                    Text("置いてあるバー")
                } footer: {
                    Text("20kg とは限りません。軽量バーがあるジムでは、それも選んでください。")
                }

                Section {
                    ForEach(plateOptions, id: \.self) { w in
                        Toggle(isOn: Binding(
                            get: { plateWeights.contains(w) },
                            set: { on in
                                if on { plateWeights.insert(w) } else { plateWeights.remove(w) }
                            }
                        )) {
                            Text("\(fmt(w)) kg プレート")
                        }
                    }
                } header: {
                    Text("置いてあるプレート")
                } footer: {
                    Text("1.25kg がないジムでは 62.5kg を作れません。実際に置いてあるものだけ選んでください。")
                }

                // MARK: 作れる重量のプレビュー

                Section {
                    let preview = previewWeights
                    if preview.isEmpty {
                        Text("バーとプレートを選ぶと、作れる重量が表示されます")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(preview, id: \.self) { w in
                                    Text(fmt(w))
                                        .font(.caption.weight(.medium))
                                        .padding(.horizontal, 9)
                                        .padding(.vertical, 5)
                                        .background(Color(.tertiarySystemFill), in: Capsule())
                                }
                            }
                        }
                        Text("\(barbellCount)通りの重量が作れます")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("作れる重量（確認用）")
                }

                // MARK: ダンベル

                Section {
                    NumberInputRow(label: "最小", placeholder: "1", unit: "kg", text: $dumbbellMin)
                    NumberInputRow(label: "最大", placeholder: "40", unit: "kg", text: $dumbbellMax)
                    NumberInputRow(label: "刻み", placeholder: "2", unit: "kg", text: $dumbbellStep)
                } header: {
                    Text("ダンベル")
                } footer: {
                    Text(dumbbellFooter)
                }

                // MARK: マシン

                Section {
                    Picker("重量の表記", selection: $machineUnit) {
                        ForEach(MachineUnit.allCases) { unit in
                            Text(unit.label).tag(unit)
                        }
                    }
                    .pickerStyle(.navigationLink)

                    if machineUnit == .stack {
                        NumberInputRow(label: "1段あたり", placeholder: "未設定", unit: "kg",
                                       text: $machineStepWeight)
                    }
                } header: {
                    Text("マシン")
                } footer: {
                    Text(machineFooter)
                }
            }
            .navigationTitle(gym == nil ? "ジムを追加" : "ジムを編集")
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
            .confirmationDialog("よくある構成", isPresented: $showPresets, titleVisibility: .visible) {
                ForEach(Array(Gym.presets.enumerated()), id: \.offset) { _, preset in
                    Button(preset.name) { apply(preset) }
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("選んだあと、違うところだけ直せます")
            }
            .onAppear(perform: load)
        }
    }

    // MARK: - 表示用

    private var previewWeights: [Double] {
        let temp = Gym(name: "", barWeights: Array(barWeights), plateWeights: Array(plateWeights))
        return Array(temp.barbellWeights(maxWeight: 200).prefix(14))
    }

    private var barbellCount: Int {
        let temp = Gym(name: "", barWeights: Array(barWeights), plateWeights: Array(plateWeights))
        return temp.barbellWeights(maxWeight: 200).count
    }

    private var dumbbellFooter: String {
        guard let step = Double(dumbbellStep), step > 0,
              let mn = Double(dumbbellMin), let mx = Double(dumbbellMax), mx >= mn
        else { return "刻みが 2kg のジムには 15kg のダンベルはありません。" }

        let temp = Gym(name: "", dumbbellMin: mn, dumbbellMax: mx, dumbbellStep: step)
        let list = temp.dumbbellWeightList()
        let head = list.prefix(6).map { fmt($0) }.joined(separator: ", ")
        return "\(head)… の \(list.count)種類が候補になります。"
    }

    private var machineFooter: String {
        switch machineUnit {
        case .kilogram:
            return machineUnit.hint
        case .pound:
            return "記録は kg に換算して保存します。ジムを移っても総挙上量が続けて計算できます。"
        case .stack:
            return "1段あたりの重量が分かる場合だけ入力してください。未入力のままでも段数は記録できますが、総挙上量の計算からは除きます（推測値を混ぜると数字が信用できなくなるため）。"
        }
    }

    private func fmt(_ v: Double) -> String {
        v == v.rounded() ? String(Int(v)) : String(format: "%g", v)
    }

    // MARK: - 処理

    private func apply(_ preset: Gym.Preset) {
        let made = preset.make(name)
        barWeights = Set(made.barWeights)
        plateWeights = Set(made.plateWeights)
        dumbbellMin = fmt(made.dumbbellMin)
        dumbbellMax = fmt(made.dumbbellMax)
        dumbbellStep = fmt(made.dumbbellStep)
        machineUnit = made.machineUnit
    }

    private func load() {
        guard let gym else {
            // 最初の1件は自動的に既定にする
            isDefault = allGyms.isEmpty
            return
        }
        name = gym.name
        memo = gym.memo
        isDefault = gym.isDefault
        barWeights = Set(gym.barWeights)
        plateWeights = Set(gym.plateWeights)
        dumbbellMin = fmt(gym.dumbbellMin)
        dumbbellMax = fmt(gym.dumbbellMax)
        dumbbellStep = fmt(gym.dumbbellStep)
        machineUnit = gym.machineUnit
        machineStepWeight = gym.machineStepWeight.map { fmt($0) } ?? ""
    }

    private func save() {
        let target: Gym
        if let gym {
            target = gym
        } else {
            target = Gym(name: "")
            context.insert(target)
        }

        target.name = name.trimmingCharacters(in: .whitespaces)
        target.memo = memo
        target.barWeights = barWeights.sorted()
        target.plateWeights = plateWeights.sorted()
        target.dumbbellMin = Double(dumbbellMin) ?? 1
        target.dumbbellMax = Double(dumbbellMax) ?? 40
        target.dumbbellStep = Double(dumbbellStep) ?? 2
        target.machineUnit = machineUnit
        target.machineStepWeight = machineUnit == .stack ? Double(machineStepWeight) : nil

        // 既定はひとつだけ
        if isDefault {
            for other in allGyms where other !== target {
                other.isDefault = false
            }
            target.isDefault = true
        } else {
            target.isDefault = false
            // 既定が1つもなくなる場合は、自分を既定に戻す
            if !allGyms.contains(where: { $0.isDefault }) {
                target.isDefault = true
            }
        }
        dismiss()
    }
}

#Preview {
    NavigationStack {
        GymListView()
    }
    .modelContainer(PreviewData.container)
}
