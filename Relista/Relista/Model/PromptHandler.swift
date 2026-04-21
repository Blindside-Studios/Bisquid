//
//  PromptHandler.swift
//  Bisquid
//
//  Created by Nicolas Helbig on 21.04.26.
//

import Foundation
#if os(iOS)
import UIKit
#endif

class PromptHandler{
    public static func populateInstructionsWithData(basePrompt: String) -> String{
        let currentDateTrigger = "b/CurrentDate"
        let currentDateValue = Date.now.formatted(date: .numeric, time: .omitted)
        
        let currentDeviceTrigger = "b/CurrentDevice"
        #if os(macOS)
        let currentDeviceValue = "Mac"
        #else
        let cUID = UIDevice.current
        let currentDeviceValue = "\(cUID.model) / \(cUID.systemName) \(cUID.systemVersion)"
        #endif
        
        let appInfoTrigger = "b/AppInfo"
        let appInfoValue = """
        You are interfacing with the user through "Bisquid", a SwiftUI-powered Mistral chat application.
        It was developed by Blindside Studios as a response to Le Chat not providing a satisfactory user experience.
        It supports agents, called "Squidlets", with unique personalities, akin to GPTs in ChatGPT and Gems in Gemini.
        The app is currently available on iOS, iPadOS and macOS.
        """
        
        let toolsInfoTrigger = "b/AllTools"
        let toolsInfoValue = ToolRegistry.allTools
            .map { "- \($0.displayName) (\($0.name)): \($0.description)" }
            .joined(separator: "\n")
        
        return basePrompt
            .replacingOccurrences(of: currentDateTrigger, with: currentDateValue)
            .replacingOccurrences(of: currentDeviceTrigger, with: currentDeviceValue)
            .replacingOccurrences(of: appInfoTrigger, with: appInfoValue)
            .replacingOccurrences(of: toolsInfoTrigger, with: toolsInfoValue)
    }
}
