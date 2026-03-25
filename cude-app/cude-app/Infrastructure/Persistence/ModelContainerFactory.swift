import Foundation
import SwiftData

public enum ModelContainerFactory {
    public static func makeDefaultContainer(inMemoryOnly: Bool = false) -> ModelContainer {
        return makeContainer(
            models: [
                NotificationItem.self,
                PendingStatusSubmission.self,
            ],
            inMemoryOnly: inMemoryOnly
        )
    }

    public static func makeContainer(
        models: [any PersistentModel.Type],
        inMemoryOnly: Bool = false
    ) -> ModelContainer {
        let schema = Schema(models)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemoryOnly)

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }
}
