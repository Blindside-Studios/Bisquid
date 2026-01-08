//
//  PersonalizationSettings+Syncable.swift
//  Relista
//
//  Created by Nicolas Helbig on 07.01.26.
//

import Foundation
import CloudKit

// MARK: - PersonalizationSettings Model (for future sync)

/// Syncable model for personalization settings
/// TODO: Migrate from @AppStorage in PersonalizationSettings.swift to this model
/// when ready to enable settings sync across devices
struct PersonalizationSettingsModel: Syncable {
    var id: UUID = UUID()  // Single settings object per user
    var defaultModel: String
    var sysInstructions: String
    var userName: String
    var lastModified: Date

    static var recordType: String { "PersonalizationSettings" }

    // Default initializer
    init(
        id: UUID = UUID(),
        defaultModel: String = "mistralai/mistral-medium-3.1",
        sysInstructions: String = "",
        userName: String = "",
        lastModified: Date = Date.now
    ) {
        self.id = id
        self.defaultModel = defaultModel
        self.sysInstructions = sysInstructions
        self.userName = userName
        self.lastModified = lastModified
    }

    // MARK: - CloudKit Record Conversion

    func toCloudKitRecord() throws -> CKRecord {
        let recordID = CKRecord.ID(recordName: id.uuidString)
        let record = CKRecord(recordType: Self.recordType, recordID: recordID)

        record["defaultModel"] = defaultModel as CKRecordValue
        record["sysInstructions"] = sysInstructions as CKRecordValue
        record["userName"] = userName as CKRecordValue
        record["lastModified"] = lastModified as CKRecordValue

        return record
    }

    static func fromCloudKitRecord(_ record: CKRecord) throws -> PersonalizationSettingsModel {
        guard let defaultModel = record["defaultModel"] as? String else {
            throw SyncError.missingField("defaultModel")
        }
        guard let sysInstructions = record["sysInstructions"] as? String else {
            throw SyncError.missingField("sysInstructions")
        }
        guard let userName = record["userName"] as? String else {
            throw SyncError.missingField("userName")
        }
        guard let lastModified = record["lastModified"] as? Date else {
            throw SyncError.missingField("lastModified")
        }

        guard let idString = record.recordID.recordName.split(separator: "/").last,
              let id = UUID(uuidString: String(idString)) else {
            throw SyncError.invalidData("Invalid UUID in record ID")
        }

        return PersonalizationSettingsModel(
            id: id,
            defaultModel: defaultModel,
            sysInstructions: sysInstructions,
            userName: userName,
            lastModified: lastModified
        )
    }
}

// MARK: - Future PersonalizationSettings Manager (Template)

/// TODO: When ready to enable settings sync, create a manager like this:
///
/// ```swift
/// class PersonalizationSettingsManager: ObservableObject {
///     static let shared = PersonalizationSettingsManager()
///
///     @Published var settings: PersonalizationSettingsModel
///
///     private let syncEngine: SyncEngine<PersonalizationSettingsModel>
///
///     private init() {
///         let container = CKContainer(identifier: "iCloud.Blindside-Studios.Relista")
///         self.syncEngine = SyncEngine(database: container.privateCloudDatabase)
///
///         // Load from local storage
///         if let loaded = try? loadFromDisk() {
///             self.settings = loaded
///         } else {
///             self.settings = PersonalizationSettingsModel()
///         }
///     }
///
///     func updateSettings(_ changes: (inout PersonalizationSettingsModel) -> Void) throws {
///         changes(&settings)
///         settings.lastModified = Date.now
///         try saveToDisk()
///
///         Task {
///             await syncEngine.markForPush(settings.id)
///             await syncEngine.startDebouncedPush { [weak self] in
///                 guard let self = self else { return [] }
///                 return [self.settings]
///             }
///         }
///     }
///
///     func refreshFromCloud() async throws {
///         let cloudSettings = try await syncEngine.pull(since: syncEngine.lastSyncDate)
///         if let cloudSetting = cloudSettings.first,
///            cloudSetting.lastModified > settings.lastModified {
///             settings = cloudSetting
///             try saveToDisk()
///         }
///     }
///
///     private func saveToDisk() throws {
///         let encoder = JSONEncoder()
///         encoder.dateEncodingStrategy = .iso8601
///         encoder.outputFormatting = .prettyPrinted
///
///         let data = try encoder.encode(settings)
///         let fileURL = FileManager.default
///             .urls(for: .documentDirectory, in: .userDomainMask)[0]
///             .appendingPathComponent("Relista")
///             .appendingPathComponent("settings.json")
///
///         try data.write(to: fileURL)
///     }
///
///     private func loadFromDisk() throws -> PersonalizationSettingsModel {
///         let fileURL = FileManager.default
///             .urls(for: .documentDirectory, in: .userDomainMask)[0]
///             .appendingPathComponent("Relista")
///             .appendingPathComponent("settings.json")
///
///         let data = try Data(contentsOf: fileURL)
///         let decoder = JSONDecoder()
///         decoder.dateDecodingStrategy = .iso8601
///         return try decoder.decode(PersonalizationSettingsModel.self, from: data)
///     }
/// }
/// ```
///
/// Migration Steps:
/// 1. Uncomment and implement PersonalizationSettingsManager above
/// 2. Replace @AppStorage properties in PersonalizationSettings.swift with @Published settings from manager
/// 3. Update all UI bindings to use PersonalizationSettingsManager.shared.settings
/// 4. Add refreshFromCloud() call to app refresh logic
/// 5. Test settings sync across devices
