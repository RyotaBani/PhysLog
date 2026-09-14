import SwiftUI
import SwiftData

struct TrainingListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \TrainingSession.date, order: .reverse) private var sessions: [TrainingSession]

    @State private var editing: TrainingSession? = nil
    @State private var isAdding = false
    /// 「この記録をもとに作成」で選ばれた元の記録
    @State private var duplicating: TrainingSession? = nil

    var body: some View {
        Group {
            if sessions.isEmpty {
                EmptyStateView(
                    icon: "dumbbell",
                    title: "トレーニングの記録がありません",
                    message: "セットごとに重量を変えて記録できます。\n総挙上量は自動で計算されます"
                )
            } else {
                List {
                    ForEach(sessions) { session in
                        Button {
                            editing = session
                        } label: {
                            TrainingSessionRow(session: session)
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .contextMenu {
                            // 同じメニューを繰り返す日に、種目と回数を打ち直さずに済む
                            Button {
                                duplicating = session
                            } label: {
                                Label("この記録をもとに作成", systemImage: "doc.on.doc")
                            }
                        }
                    }
                    .onDelete { offsets in
                        for index in offsets { context.delete(sessions[index]) }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }

        }
        .floatingAddButton { isAdding = true }
        .sheet(isPresented: $isAdding) {
            TrainingEditor(session: nil)
        }
        .sheet(item: $editing) { session in
            TrainingEditor(session: session)
        }
        .sheet(item: $duplicating) { session in
            TrainingEditor(session: nil, basedOn: session)
        }
    }
}

// MARK: - 行

struct TrainingSessionRow: View {
    let session: TrainingSession

    var body: some View {
        Card(padding: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.displayTitle)
                            .font(.subheadline.weight(.semibold))
                        HStack(spacing: 6) {
                            Text("\(session.date.shortJP)（\(session.date.weekdayJP)）")
                            if !session.gymName.isEmpty {
                                Text("・")
                                Text(session.gymName)
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if session.totalVolume > 0 {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("総挙上量")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(String(format: "%.0f kg", session.totalVolume))
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Color.physlogOrange)
                        }
                    }
                }

                if !session.sortedExercises.isEmpty {
                    Divider()
                    VStack(spacing: 5) {
                        ForEach(session.sortedExercises) { set in
                            HStack {
                                Text(set.exercise)
                                    .font(.caption)
                                Spacer()
                                Text(set.summary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                if !session.memo.isEmpty {
                    Text(session.memo)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - 編集用の一時データ

struct SetDraft: Identifiable {
    let id = UUID()
    var weight: String = ""
    var reps: String = ""

    var isEmpty: Bool {
        weight.trimmingCharacters(in: .whitespaces).isEmpty
            && reps.trimmingCharacters(in: .whitespaces).isEmpty
    }
}

struct ExerciseDraft: Identifiable {
    let id = UUID()
    var name: String = ""
    var sets: [SetDraft] = [SetDraft()]

    var isEmpty: Bool { name.trimmingCharacters(in: .whitespaces).isEmpty }

    /// この種目の挙上量
    var volume: Double {
        sets.reduce(0) { sum, set in
            guard let w = Double(set.weight), let r = Int(set.reps) else { return sum }
            return sum + w * Double(r)
        }
    }
}

// MARK: - 追加・編集

struct TrainingEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let session: TrainingSession?
    /// 内容をコピーする元の記録。新規作成のときだけ使う。
    var basedOn: TrainingSession? = nil

    @State private var date = Date()
    @State private var sport = "ウェイトトレーニング"
    @State private var memo = ""
    @State private var drafts: [ExerciseDraft] = [ExerciseDraft()]
    @State private var pickerTarget: UUID? = nil
    @State private var gymName = ""

    @Query(sort: \Gym.createdAt) private var gyms: [Gym]

    /// 選択中のジム。候補の生成に使う。
    private var selectedGym: Gym? {
        gyms.first { $0.name == gymName }
    }

    private var canSave: Bool {
        drafts.contains { !$0.isEmpty }
    }

    private var estimatedVolume: Double {
        drafts.reduce(0) { $0 + $1.volume }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("日付", selection: $date, displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "ja_JP"))

                    Picker("種別", selection: $sport) {
                        ForEach(ExerciseLibrary.sports, id: \.self) { Text($0).tag($0) }
                    }

                    if !gyms.isEmpty {
                        Picker("場所", selection: $gymName) {
                            Text("指定しない").tag("")
                            ForEach(gyms) { gym in
                                Text(gym.name).tag(gym.name)
                            }
                        }
                    }
                }

                Section {
                    ForEach($drafts) { $draft in
                        ExerciseDraftRow(draft: $draft, gym: selectedGym) {
                            pickerTarget = draft.id
                        }
                    }
                    .onDelete { offsets in
                        drafts.remove(atOffsets: offsets)
                        if drafts.isEmpty { drafts.append(ExerciseDraft()) }
                    }

                    Button {
                        drafts.append(ExerciseDraft())
                    } label: {
                        Label("種目を追加", systemImage: "plus.circle.fill")
                            .foregroundStyle(Color.physlogOrange)
                    }
                } header: {
                    Text("種目")
                } footer: {
                    if estimatedVolume > 0 {
                        Text(String(format: "総挙上量: %.0f kg", estimatedVolume))
                            .font(.caption.weight(.semibold))
                    } else {
                        Text("重量・回数・セット数をすべて入力すると総挙上量が計算されます")
                    }
                }

                Section("メモ") {
                    TextField("調子・意識したポイントなど", text: $memo, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .navigationTitle(session == nil ? "トレーニングを記録" : "記録を編集")
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
            .sheet(item: Binding(
                get: { pickerTarget.map { IdentifiableUUID(id: $0) } },
                set: { pickerTarget = $0?.id }
            )) { target in
                ExercisePickerSheet { picked in
                    if let index = drafts.firstIndex(where: { $0.id == target.id }) {
                        drafts[index].name = picked
                    }
                    pickerTarget = nil
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard let session else {
            // 新規作成時は既定のジムを初期値にする。
            // 毎回選び直すのは手間なので、普段の場所が自動で入るようにしている。
            gymName = gyms.first(where: { $0.isDefault })?.name ?? ""

            // 「この記録をもとに作成」の場合、種目と重量を引き継ぐ。
            // 日付だけ今日にして、重量を直せばすぐ保存できる。
            if let basedOn {
                sport = ExerciseLibrary.sports.contains(basedOn.sport) ? basedOn.sport : "その他"
                gymName = basedOn.gymName
                drafts = Self.makeDrafts(from: basedOn)
            }
            return
        }
        gymName = session.gymName
        date = session.date
        sport = ExerciseLibrary.sports.contains(session.sport) ? session.sport : "その他"
        memo = session.memo

        drafts = Self.makeDrafts(from: session)
    }

    private func save() {
        let target: TrainingSession

        if let session {
            target = session
            // 既存の種目を一旦すべて削除して作り直す
            for set in session.sortedExercises {
                context.delete(set)
            }
            target.date = date
            target.sport = sport
            target.memo = memo
            target.gymName = gymName
        } else {
            target = TrainingSession(date: date, sport: sport, memo: memo, gymName: gymName)
            context.insert(target)
        }

        for (index, draft) in drafts.enumerated() where !draft.isEmpty {
            let set = TrainingSet(
                exercise: draft.name.trimmingCharacters(in: .whitespaces),
                order: index
            )
            set.session = target
            context.insert(set)

            // セットごとに1件ずつ作る。
            // 旧フィールド（weight / reps / sets）は使わない。
            for (setIndex, setDraft) in draft.sets.enumerated() where !setDraft.isEmpty {
                let entry = SetEntry(
                    weight: Double(setDraft.weight),
                    reps: Int(setDraft.reps),
                    order: setIndex
                )
                entry.exerciseSet = set
                context.insert(entry)
            }
        }
        dismiss()
    }

    /// 既存の記録から入力用の下書きを作る。
    /// 「前回から作成」でも使うので、型メソッドに切り出している。
    static func makeDrafts(from session: TrainingSession) -> [ExerciseDraft] {
        let existing = session.sortedExercises.map { set -> ExerciseDraft in
            var draft = ExerciseDraft(name: set.exercise)
            let resolved = set.resolvedSets
            draft.sets = resolved.isEmpty
                ? [SetDraft()]
                : resolved.map { entry in
                    var sd = SetDraft()
                    sd.weight = entry.weight.map { fmt($0) } ?? ""
                    sd.reps = entry.reps.map { String($0) } ?? ""
                    return sd
                }
            return draft
        }
        return existing.isEmpty ? [ExerciseDraft()] : existing
    }
}

// MARK: - 種目1行

struct ExerciseDraftRow: View {
    @Binding var draft: ExerciseDraft
    /// 選択中のジム。候補チップの生成に使う。nil なら候補は出ない。
    var gym: Gym? = nil
    let onPickerTap: () -> Void

    /// 種目名から、バーベル種目かダンベル種目かを推測する。
    /// 完全な判定は難しいので、候補を出す手がかりに使うだけ。
    /// 外れても自由入力できるので実害はない。
    private var weightCandidates: [Double] {
        guard let gym else { return [] }
        let name = draft.name
        guard !name.isEmpty else { return [] }

        if name.contains("ダンベル") || name.localizedCaseInsensitiveContains("dumbbell") {
            return gym.dumbbellWeightList()
        }
        // バーベル種目とみなせるもの
        let barbellKeywords = ["ベンチプレス", "スクワット", "デッドリフト", "ロウ",
                               "カール", "プレス", "クリーン", "バーベル"]
        if barbellKeywords.contains(where: { name.contains($0) }) {
            return gym.barbellWeights(maxWeight: 250)
        }
        return []
    }

    /// いま入力されている値の近くだけ見せる。
    /// 全候補を出すと数十件になり、探すほうが手間になるため。
    private func nearbyCandidates(for current: String) -> [Double]? {
        let all = weightCandidates
        guard !all.isEmpty else { return nil }

        if let value = Double(current), value > 0 {
            let sorted = all.sorted { abs($0 - value) < abs($1 - value) }
            return Array(sorted.prefix(6)).sorted()
        }
        return Array(all.prefix(6))
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                TextField("種目名", text: $draft.name)
                    .font(.subheadline.weight(.medium))
                Button(action: onPickerTap) {
                    Image(systemName: "list.bullet.rectangle")
                        .foregroundStyle(Color.physlogOrange)
                }
                .buttonStyle(.plain)
            }

            // セットごとに重量を持つ。
            // ウォームアップから本番へ上げていく記録に対応するため。
            ForEach(Array($draft.sets.enumerated()), id: \.element.id) { index, $set in
                VStack(spacing: 6) {
                    HStack(spacing: 8) {
                        Text("\(index + 1)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 16)

                        CompactField(caption: index == 0 ? "重量" : "",
                                     placeholder: "kg", text: $set.weight)
                        Text("×").font(.caption).foregroundStyle(.tertiary)
                            .padding(.top, index == 0 ? 14 : 0)
                        CompactField(caption: index == 0 ? "回数" : "",
                                     placeholder: "回", text: $set.reps)

                        // 同じ内容をもう1セット足す。
                        // 「60kg×10を3セット」のような繰り返しを、
                        // 打ち直さずに増やせるようにしている。
                        Button {
                            duplicate(at: index)
                        } label: {
                            Image(systemName: "plus.square.on.square")
                                .font(.subheadline)
                                .foregroundStyle(Color.physlogOrange)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, index == 0 ? 14 : 0)

                        if draft.sets.count > 1 {
                            Button {
                                draft.sets.remove(at: index)
                            } label: {
                                Image(systemName: "minus.circle")
                                    .font(.subheadline)
                                    .foregroundStyle(.tertiary)
                            }
                            .buttonStyle(.plain)
                            .padding(.top, index == 0 ? 14 : 0)
                        }
                    }

                    // そのジムで作れる重量を候補として出す。
                    // タップで入るが、手入力もそのままできる（他店舗で借りた、
                    // 自前のプレートを使ったなどの例外に対応するため）。
                    if let candidates = nearbyCandidates(for: set.weight), !candidates.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(candidates, id: \.self) { w in
                                    Button {
                                        set.weight = fmt(w)
                                    } label: {
                                        Text(fmt(w))
                                            .font(.caption2.weight(.medium))
                                            .padding(.horizontal, 9)
                                            .padding(.vertical, 4)
                                            .background(
                                                Double(set.weight) == w
                                                    ? Color.physlogOrange
                                                    : Color(.tertiarySystemFill),
                                                in: Capsule()
                                            )
                                            .foregroundStyle(
                                                Double(set.weight) == w ? .white : Color.primary
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.leading, 24)
                        }
                    }
                }
            }

            HStack {
                Button {
                    draft.sets.append(SetDraft())
                } label: {
                    Label("セットを追加", systemImage: "plus.circle")
                        .font(.caption)
                        .foregroundStyle(Color.physlogOrange)
                }
                .buttonStyle(.plain)

                Spacer()

                if draft.volume > 0 {
                    Text("\(Int(draft.volume).formatted()) kg")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    /// 直前のセットと同じ内容を1本足す
    private func duplicate(at index: Int) {
        guard draft.sets.indices.contains(index) else { return }
        let source = draft.sets[index]
        var copy = SetDraft()
        copy.weight = source.weight
        copy.reps = source.reps
        draft.sets.insert(copy, at: index + 1)
    }
}

private func fmt(_ v: Double) -> String {
    v == v.rounded() ? String(Int(v)) : String(format: "%g", v)
}

struct CompactField: View {
    let caption: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(spacing: 3) {
            Text(caption)
                .font(.caption2)
                .foregroundStyle(.secondary)
            TextField(placeholder, text: $text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .font(.subheadline)
                .padding(.vertical, 7)
                .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

// MARK: - 種目選択シート

struct IdentifiableUUID: Identifiable {
    let id: UUID
}

struct ExercisePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    let onPick: (String) -> Void

    private var categories: [(category: String, items: [String])] {
        guard !search.isEmpty else { return ExerciseLibrary.byCategory }
        return ExerciseLibrary.byCategory.compactMap { group in
            let matched = group.items.filter { $0.localizedStandardContains(search) }
            return matched.isEmpty ? nil : (group.category, matched)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(categories, id: \.category) { group in
                    Section(group.category) {
                        ForEach(group.items, id: \.self) { item in
                            Button(item) {
                                onPick(item)
                                dismiss()
                            }
                            .foregroundStyle(.primary)
                        }
                    }
                }
            }
            .searchable(text: $search, prompt: "種目を検索")
            .navigationTitle("種目を選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    TrainingListView()
        .modelContainer(PreviewData.container)
}
