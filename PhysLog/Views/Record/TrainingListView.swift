import SwiftUI
import SwiftData

struct TrainingListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \TrainingSession.date, order: .reverse) private var sessions: [TrainingSession]

    @State private var editing: TrainingSession? = nil
    @State private var isAdding = false

    var body: some View {
        Group {
            if sessions.isEmpty {
                EmptyStateView(
                    icon: "dumbbell",
                    title: "トレーニングの記録がありません",
                    message: "種目・重量・回数・セット数を記録すると、\n総挙上量が自動で計算されます"
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
                        Text("\(session.date.shortJP)（\(session.date.weekdayJP)）")
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

struct ExerciseDraft: Identifiable {
    let id = UUID()
    var name: String = ""
    var weight: String = ""
    var reps: String = ""
    var sets: String = ""

    var isEmpty: Bool { name.trimmingCharacters(in: .whitespaces).isEmpty }
}

// MARK: - 追加・編集

struct TrainingEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let session: TrainingSession?

    @State private var date = Date()
    @State private var sport = "ウェイトトレーニング"
    @State private var memo = ""
    @State private var drafts: [ExerciseDraft] = [ExerciseDraft()]
    @State private var pickerTarget: UUID? = nil

    private var canSave: Bool {
        drafts.contains { !$0.isEmpty }
    }

    private var estimatedVolume: Double {
        drafts.reduce(0) { sum, draft in
            guard let w = Double(draft.weight),
                  let r = Int(draft.reps),
                  let s = Int(draft.sets) else { return sum }
            return sum + w * Double(r) * Double(s)
        }
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
                }

                Section {
                    ForEach($drafts) { $draft in
                        ExerciseDraftRow(draft: $draft) {
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
        guard let session else { return }
        date = session.date
        sport = ExerciseLibrary.sports.contains(session.sport) ? session.sport : "その他"
        memo = session.memo

        let existing = session.sortedExercises.map { set in
            ExerciseDraft(
                name: set.exercise,
                weight: set.weight.map { String($0) } ?? "",
                reps: set.reps.map { String($0) } ?? "",
                sets: set.sets.map { String($0) } ?? ""
            )
        }
        drafts = existing.isEmpty ? [ExerciseDraft()] : existing
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
        } else {
            target = TrainingSession(date: date, sport: sport, memo: memo)
            context.insert(target)
        }

        for (index, draft) in drafts.enumerated() where !draft.isEmpty {
            let set = TrainingSet(
                exercise: draft.name.trimmingCharacters(in: .whitespaces),
                weight: Double(draft.weight),
                reps: Int(draft.reps),
                sets: Int(draft.sets),
                order: index
            )
            set.session = target
            context.insert(set)
        }
        dismiss()
    }
}

// MARK: - 種目1行

struct ExerciseDraftRow: View {
    @Binding var draft: ExerciseDraft
    let onPickerTap: () -> Void

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

            HStack(spacing: 8) {
                CompactField(caption: "重量", placeholder: "kg", text: $draft.weight)
                Text("×").font(.caption).foregroundStyle(.tertiary)
                CompactField(caption: "回数", placeholder: "回", text: $draft.reps)
                Text("×").font(.caption).foregroundStyle(.tertiary)
                CompactField(caption: "セット", placeholder: "set", text: $draft.sets)
            }
        }
        .padding(.vertical, 4)
    }
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
