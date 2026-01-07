//
//  Syncable.swift
//  Relista
//
//  Created by Nicolas Helbig on 07.01.26.
//
//  Protocol for types that can be synced to CloudKit.
//  Any type conforming to Syncable can be automatically synced using SyncEngine<T>.
//

import Foundation
import CloudKit

// MARK: - Sync Error Types

/// Errors that can occur during CloudKit sync operations
enum SyncError: Error, LocalizedError {
    case missingField(String)
    case invalidData(String)
    case networkFailure
    case unauthorized
    case serverError(String)
    case notFound

    var errorDescription: String? {
        switch self {
        case .missingField(let field):
            return "Missing required field: \(field)"
        case .invalidData(let reason):
            return "Invalid data: \(reason)"
        case .networkFailure:
            return "Network connection failed"
        case .unauthorized:
            return "Not authorized to access CloudKit"
        case .serverError(let message):
            return "Server error: \(message)"
        case .notFound:
            return "Item not found"
        }
    }
}

// MARK: - Syncable Protocol

/// Protocol for objects that can be synced to CloudKit
///
/// Types conforming to this protocol can be automatically synced using `SyncEngine<T>`.
/// Requirements:
/// - UUID identifier for consistent referencing
/// - Codable for local JSON storage
/// - lastModified timestamp for conflict resolution
/// - Conversion to/from CloudKit records
///
/// Example:
/// ```swift
/// extension Agent: Syncable {
///     static var recordType: String { "Agent" }
///
///     func toCloudKitRecord() throws -> CKRecord {
///         let record = CKRecord(recordType: Self.recordType,
///                              recordID: CKRecord.ID(recordName: id.uuidString))
///         record["name"] = name as CKRecordValue
///         return record
///     }
///
///     static func fromCloudKitRecord(_ record: CKRecord) throws -> Agent {
///         guard let name = record["name"] as? String else {
///             throw SyncError.missingField("name")
///         }
///         return Agent(id: UUID(uuidString: record.recordID.recordName)!, name: name, ...)
///     }
/// }
/// ```
protocol Syncable: Identifiable, Codable where ID == UUID {
    /// The CloudKit record type name (e.g., "Agent", "Conversation", "Message")
    static var recordType: String { get }

    /// Timestamp for conflict resolution - MUST be updated before every save
    /// During merge, the item with the newest lastModified wins ("Last Write Wins" strategy)
    var lastModified: Date { get set }

    /// Convert this object to a CloudKit record
    /// - Returns: A CKRecord representing this object
    /// - Throws: SyncError if conversion fails
    func toCloudKitRecord() throws -> CKRecord

    /// Create an object from a CloudKit record
    /// - Parameter record: The CloudKit record to convert
    /// - Returns: An instance of this type
    /// - Throws: SyncError if the record is invalid or missing required fields
    static func fromCloudKitRecord(_ record: CKRecord) throws -> Self
}

// MARK: - Default Implementations

extension Syncable {
    /// Check if this item is newer than another item (for conflict resolution)
    /// - Parameter other: The other item to compare against
    /// - Returns: true if this item's lastModified is newer (strictly greater)
    func isNewerThan(_ other: Self) -> Bool {
        return self.lastModified > other.lastModified
    }

    /// Check if this item should replace another during merge
    /// - Parameter other: The other item to compare against
    /// - Returns: true if this item should be kept (newer or equal timestamp)
    func shouldReplaceOnMerge(_ other: Self) -> Bool {
        // Use >= to handle equal timestamps (keep whichever we check first)
        return self.lastModified >= other.lastModified
    }
}

// MARK: - Merge Helpers

/// Helper functions for merging local and cloud data
struct SyncMerge {
    /// Merge cloud items into local items using timestamp-based conflict resolution
    ///
    /// Strategy: "Last Write Wins" - Items with newer `lastModified` timestamps always win.
    /// - New items from cloud are added to local collection
    /// - Existing items are updated only if cloud version is newer
    /// - Local items not in cloud are kept (they may not have synced yet or sync is pending)
    ///
    /// - Parameters:
    ///   - cloudItems: Items fetched from CloudKit
    ///   - localItems: Items currently stored locally
    ///   - itemName: Name for logging (e.g., "agent", "conversation")
    /// - Returns: Merged array with newest versions of all items
    static func merge<T: Syncable>(
        cloudItems: [T],
        into localItems: [T],
        itemName: String
    ) -> [T] {
        var merged = localItems
        var changes = (updated: 0, added: 0, kept: 0)

        // Update or add cloud items
        for cloudItem in cloudItems {
            if let index = merged.firstIndex(where: { $0.id == cloudItem.id }) {
                // Item exists locally - check which is newer
                if cloudItem.isNewerThan(merged[index]) {
                    print("  📝 Updating \(itemName) from CloudKit (cloud version newer)")
                    merged[index] = cloudItem
                    changes.updated += 1
                } else {
                    print("  ⏭️ Keeping local \(itemName) (local version newer or equal)")
                    changes.kept += 1
                }
            } else {
                // New item from cloud
                print("  ➕ Adding new \(itemName) from CloudKit")
                merged.append(cloudItem)
                changes.added += 1
            }
        }

        // Log summary
        if changes.updated > 0 || changes.added > 0 {
            print("  ✅ Merge complete: \(changes.updated) updated, \(changes.added) added, \(changes.kept) kept local")
        } else if changes.kept > 0 {
            print("  ✅ Merge complete: All local items were up to date (\(changes.kept) items)")
        }

        return merged
    }
}
