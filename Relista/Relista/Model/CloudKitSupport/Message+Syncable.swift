//
//  Message+Syncable.swift
//  Relista
//
//  CloudKit sync conformance for Message.
//  Handles conversion between Message struct and CloudKit CKRecord.
//

import Foundation
import CloudKit

extension Message: Syncable {
    /// CloudKit record type for messages
    static var recordType: String { "Message" }

    /// Convert this Message to a CloudKit record
    /// Maps all Message properties to CloudKit record fields
    /// Note: Annotations are serialized as JSON string since CloudKit doesn't support nested arrays
    func toCloudKitRecord() throws -> CKRecord {
        let recordID = CKRecord.ID(recordName: id.uuidString)
        let record = CKRecord(recordType: Self.recordType, recordID: recordID)

        // Map all required fields
        record["text"] = text as CKRecordValue
        record["role"] = role.rawValue as CKRecordValue
        record["modelUsed"] = modelUsed as CKRecordValue
        record["attachmentLinks"] = attachmentLinks as CKRecordValue  // CloudKit array (STRING_LIST)
        record["timeStamp"] = timeStamp as CKRecordValue
        record["lastModified"] = lastModified as CKRecordValue
        record["conversationID"] = conversationID.uuidString as CKRecordValue  // Required for querying messages by conversation
        print("  📤 Pushing message \(id.uuidString.prefix(8))... for conversation \(conversationID.uuidString.prefix(8))...")

        // Serialize annotations as JSON string (CloudKit doesn't support nested arrays)
        if let annotations = annotations {
            let encoder = JSONEncoder()
            if let annotationsData = try? encoder.encode(annotations),
               let annotationsJSON = String(data: annotationsData, encoding: .utf8) {
                record["annotations"] = annotationsJSON as CKRecordValue
            } else {
                record["annotations"] = nil
            }
        } else {
            record["annotations"] = nil
        }

        return record
    }

    /// Create a Message from a CloudKit record
    /// - Parameter record: The CloudKit record to convert
    /// - Returns: A Message instance
    /// - Throws: SyncError if required fields are missing or invalid
    static func fromCloudKitRecord(_ record: CKRecord) throws -> Message {
        // Extract ID from record name
        guard let id = UUID(uuidString: record.recordID.recordName) else {
            throw SyncError.invalidData("Invalid UUID in record ID")
        }

        // Extract required fields with error handling
        guard let text = record["text"] as? String else {
            throw SyncError.missingField("text")
        }

        guard let roleString = record["role"] as? String,
              let role = MessageRole(rawValue: roleString) else {
            throw SyncError.missingField("role")
        }

        guard let modelUsed = record["modelUsed"] as? String else {
            throw SyncError.missingField("modelUsed")
        }

        guard let timeStamp = record["timeStamp"] as? Date else {
            throw SyncError.missingField("timeStamp")
        }

        guard let lastModified = record["lastModified"] as? Date else {
            throw SyncError.missingField("lastModified")
        }

        // Extract attachment links (CloudKit array, may be empty)
        let attachmentLinks = record["attachmentLinks"] as? [String] ?? []

        // Extract conversationID (required for syncing messages by conversation)
        guard let conversationIDString = record["conversationID"] as? String,
              let conversationID = UUID(uuidString: conversationIDString) else {
            throw SyncError.missingField("conversationID")
        }

        // Decode annotations from JSON string (optional, backwards compatible)
        var annotations: [MessageAnnotation]? = nil
        if let annotationsJSON = record["annotations"] as? String,
           let annotationsData = annotationsJSON.data(using: .utf8) {
            let decoder = JSONDecoder()
            annotations = try? decoder.decode([MessageAnnotation].self, from: annotationsData)
        }

        return Message(
            id: id,
            text: text,
            role: role,
            modelUsed: modelUsed,
            attachmentLinks: attachmentLinks,
            timeStamp: timeStamp,
            lastModified: lastModified,
            annotations: annotations,
            conversationID: conversationID
        )
    }
}
