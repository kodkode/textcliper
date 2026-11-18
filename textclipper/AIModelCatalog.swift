//
//  AIModelCatalog.swift
//  textclipper
//
//  Single source of truth for the AI model choices shown in the menu and Settings.
//  Models the providers have already shut down are not listed; a saved choice that
//  is no longer listed falls back to the default.
//

import Foundation

enum AIModelCatalog {
    struct Model: Identifiable, Hashable {
        let id: String
        let name: String
    }

    static let openAIKey = "openaiModel"
    static let geminiKey = "geminiModel"

    static let defaultOpenAIModel = "gpt-4o"
    static let defaultGeminiModel = "gemini-2.5-flash"

    static let openAIModels: [Model] = [
        Model(id: "gpt-4o", name: "GPT-4o (Recommended)"),
        Model(id: "gpt-4o-mini", name: "GPT-4o Mini (Faster)")
    ]

    static let geminiModels: [Model] = [
        Model(id: "gemini-2.5-flash", name: "Gemini 2.5 Flash (Recommended)")
    ]

    static var selectedOpenAIModel: String {
        resolve(UserDefaults.standard.string(forKey: openAIKey), in: openAIModels, default: defaultOpenAIModel)
    }

    static var selectedGeminiModel: String {
        resolve(UserDefaults.standard.string(forKey: geminiKey), in: geminiModels, default: defaultGeminiModel)
    }

    /// The saved model if it is still offered, otherwise the default.
    static func resolve(_ saved: String?, in models: [Model], default fallback: String) -> String {
        guard let saved = saved, models.contains(where: { $0.id == saved }) else { return fallback }
        return saved
    }

    /// Replaces saved selections of retired models with the defaults, so the
    /// menu and Settings picker always show a valid checked choice.
    static func migrateRetiredSelections() {
        let defaults = UserDefaults.standard
        if let saved = defaults.string(forKey: openAIKey), saved != selectedOpenAIModel {
            defaults.set(selectedOpenAIModel, forKey: openAIKey)
        }
        if let saved = defaults.string(forKey: geminiKey), saved != selectedGeminiModel {
            defaults.set(selectedGeminiModel, forKey: geminiKey)
        }
    }
}
