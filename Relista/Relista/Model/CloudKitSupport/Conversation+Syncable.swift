//
//  Conversation+Syncable.swift
//  Relista
//
//  CloudKit sync conformance for Conversation.
//  Handles conversion between Conversation class and CloudKit CKRecord.
//

import Foundation
import CloudKit

extension Conversation: Syncable {
    /// CloudKit record type for conversations
    static var recordType: String { "Conversation" }

    /// Convert this Conversation to a CloudKit record
    /// Maps all Conversation properties to CloudKit record fields
    func toCloudKitRecord() throws -> CKRecord {
        let recordID = CKRecord.ID(recordName: id.uuidString)
        let record = CKRecord(recordType: Self.recordType, recordID: recordID)

        // Map all required fields
        record["title"] = title as CKRecordValue
        record["lastInteracted"] = lastInteracted as CKRecordValue
        record["modelUsed"] = modelUsed as CKRecordValue
        record["isArchived"] = isArchived as CKRecordValue
        record["hasMessages"] = hasMessages as CKRecordValue
        record["lastModified"] = lastModified as CKRecordValue

        // Map optional agent field
        if let agentUsed = agentUsed {
            record["agentUsed"] = agentUsed.uuidString as CKRecordValue
        } else {
            record["agentUsed"] = nil
        }

        return record
    }

    /// Create a Conversation from a CloudKit record
    /// - Parameter record: The CloudKit record to convert
    /// - Returns: A Conversation instance
    /// - Throws: SyncError if required fields are missing or invalid
    static func fromCloudKitRecord(_ record: CKRecord) throws -> Conversation {
        // Extract ID from record name
        guard let id = UUID(uuidString: record.recordID.recordName) else {
            throw SyncError.invalidData("Invalid UUID in record ID")
        }

        // Extract required fields with error handling
        guard let title = record["title"] as? String else {
            throw SyncError.missingField("title")
        }

        guard let lastInteracted = record["lastInteracted"] as? Date else {
            throw SyncError.missingField("lastInteracted")
        }

        guard let modelUsed = record["modelUsed"] as? String else {
            throw SyncError.missingField("modelUsed")
        }

        guard let isArchived = record["isArchived"] as? Bool else {
            throw SyncError.missingField("isArchived")
        }

        guard let hasMessages = record["hasMessages"] as? Bool else {
            throw SyncError.missingField("hasMessages")
        }

        guard let lastModified = record["lastModified"] as? Date else {
            throw SyncError.missingField("lastModified")
        }

        // Extract optional agent field
        let agentUsed: UUID?
        if let agentUUIDString = record["agentUsed"] as? String {
            agentUsed = UUID(uuidString: agentUUIDString)
        } else {
            agentUsed = nil
        }

        return Conversation(
            id: id,
            title: title,
            lastInteracted: lastInteracted,
            modelUsed: modelUsed,
            agentUsed: agentUsed,
            isArchived: isArchived,
            hasMessages: hasMessages,
            lastModified: lastModified
        )
    }
}
