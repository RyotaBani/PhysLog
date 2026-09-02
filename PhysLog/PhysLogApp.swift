import SwiftUI
import SwiftData

@main
struct PhysLogApp: App {

    @Environment(\.scenePhase) private var scenePhase
    @State private var hasRequestedTracking = false

    let container: ModelContainer

    init() {
        let schema = Schema([
            BodyMeasurement.self,
            PhysicalAbility.self,
            TrainingSession.self,
            TrainingSet.self,
            ConditionRecord.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            // ストアが壊れている場合はメモリ内で起動してアプリが落ちないようにする
            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            container = try! ModelContainer(for: schema, configurations: [fallback])
        }

        AdManager.start()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, !hasRequestedTracking else { return }
            hasRequestedTracking = true
            Task { await AdManager.requestTrackingAuthorizationIfNeeded() }
        }
    }
}
