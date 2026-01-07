//
//  Agent+Syncable.swift
//  Relista
//
//  Created by Nicolas Helbig on 07.01.26.
//
//  CloudKit sync conformance for Agent.
//  Handles conversion between Agent struct and CloudKit CKRecord.
//

import Foundation
import CloudKit

extension Agent: Syncable {
    /// CloudKit record type for agents
    static var recordType: String { "Agent" }

    /// Convert this Agent to a CloudKit record
    /// Maps all Agent properties to CloudKit record fields
    func toCloudKitRecord() throws -> CKRecord {
        let recordID = CKRecord.ID(recordName: id.uuidString)
        let record = CKRecord(recordType: Self.recordType, recordID: recordID)

        // Map all required fields
        record["name"] = name as CKRecordValue
        record["description"] = description as CKRecordValue
        record["icon"] = icon as CKRecordValue
        record["model"] = model as CKRecordValue
        record["systemPrompt"] = systemPrompt as CKRecordValue
        record["temperature"] = temperature as CKRecordValue
        record["shownInSidebar"] = shownInSidebar as CKRecordValue  // Native Bool support
        record["lastModified"] = lastModified as CKRecordValue

        // Map optional color fields
        if let primaryColor = primaryAccentColor {
            record["primaryAccentColor"] = primaryColor as CKRecordValue
        } else {
            record["primaryAccentColor"] = nil
        }

        if let secondaryColor = secondaryAccentColor {
            record["secondaryAccentColor"] = secondaryColor as CKRecordValue
        } else {
            record["secondaryAccentColor"] = nil
        }

        return record
    }

    /// Create an Agent from a CloudKit record
    /// - Parameter record: The CloudKit record to convert
    /// - Returns: An Agent instance
    /// - Throws: SyncError if required fields are missing or invalid
    static func fromCloudKitRecord(_ record: CKRecord) throws -> Agent {
        // Extract ID from record name
        guard let id = UUID(uuidString: record.recordID.recordName) else {
            throw SyncError.invalidData("Invalid UUID in record ID")
        }

        // Extract required fields with error handling
        guard let name = record["name"] as? String else {
            throw SyncError.missingField("name")
        }

        guard let description = record["description"] as? String else {
            throw SyncError.missingField("description")
        }

        guard let icon = record["icon"] as? String else {
            throw SyncError.missingField("icon")
        }

        guard let model = record["model"] as? String else {
            throw SyncError.missingField("model")
        }

        guard let systemPrompt = record["systemPrompt"] as? String else {
            throw SyncError.missingField("systemPrompt")
        }

        guard let temperature = record["temperature"] as? Double else {
            throw SyncError.missingField("temperature")
        }

        // Handle shownInSidebar (support both Bool and Int for backwards compatibility)
        let shownInSidebar: Bool
        if let boolValue = record["shownInSidebar"] as? Bool {
            shownInSidebar = boolValue
        } else if let intValue = record["shownInSidebar"] as? Int {
            shownInSidebar = intValue == 1
        } else {
            throw SyncError.missingField("shownInSidebar")
        }

        guard let lastModified = record["lastModified"] as? Date else {
            throw SyncError.missingField("lastModified")
        }

        // Extract optional color fields
        let primaryAccentColor = record["primaryAccentColor"] as? String
        let secondaryAccentColor = record["secondaryAccentColor"] as? String

        return Agent(
            id: id,
            name: name,
            description: description,
            icon: icon,
            model: model,
            systemPrompt: systemPrompt,
            temperature: temperature,
            shownInSidebar: shownInSidebar,
            lastModified: lastModified,
            primaryAccentColor: primaryAccentColor,
            secondaryAccentColor: secondaryAccentColor
        )
    }
}
