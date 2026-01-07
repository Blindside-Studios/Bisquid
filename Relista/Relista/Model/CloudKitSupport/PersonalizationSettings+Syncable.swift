//
//  PersonalizationSettings+Syncable.swift
//  Relista
//
//  Created by Nicolas Helbig on 07.01.26.
//

import Foundation
import CloudKit

// Model for syncable personalization settings
 struct PersonalizationSettingsModel/*: Syncable*/ {
     var id: UUID = UUID()  // Single settings object
     var defaultModel: String
     var sysInstructions: String
     var userName: String
     var lastModified: Date

     static var recordType: String { "PersonalizationSettings" }

     // Implement toCloudKitRecord() and fromCloudKitRecord()
 }

 // TODO: Migrate from @AppStorage to this model when ready
 // Current PersonalizationSettings.swift uses @AppStorage (local only)
