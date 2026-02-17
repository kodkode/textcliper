//
//  APIKeyConfigView.swift
//  textclipper
//
//  Created by Claude on 17/02/2026.
//

import SwiftUI

struct APIKeyConfigView: View {
    @Binding var isPresented: Bool
    
    @State private var openAIKey: String = ""
    @State private var geminiKey: String = ""
    @State private var ocrSpaceKey: String = ""
    @State private var selectedTab = 0
    @State private var showSuccessMessage = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Configure API Keys")
                    .font(.headline)
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Content
            VStack(spacing: 20) {
                Text("Enter your API keys to enable AI-enhanced features. Keys are stored securely in your Keychain.")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Picker("", selection: $selectedTab) {
                    Text("OpenAI").tag(0)
                    Text("Google Gemini").tag(1)
                    Text("OCR.space").tag(2)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 16) {
                    if selectedTab == 0 {
                        // OpenAI
                        VStack(alignment: .leading, spacing: 8) {
                            Text("OpenAI API Key")
                                .font(.headline)
                            SecureField("sk-...", text: $openAIKey)
                                .textFieldStyle(.roundedBorder)
                            
                            Link("Get an API Key", destination: URL(string: "https://platform.openai.com/api-keys")!)
                                .font(.caption)
                                .foregroundColor(.accentColor)
                        }
                    } else if selectedTab == 1 {
                        // Gemini
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Gemini API Key")
                                .font(.headline)
                            SecureField("AIza...", text: $geminiKey)
                                .textFieldStyle(.roundedBorder)
                            
                            Link("Get an API Key", destination: URL(string: "https://aistudio.google.com/app/apikey")!)
                                .font(.caption)
                                .foregroundColor(.accentColor)
                        }
                    } else {
                        // OCR.space
                        VStack(alignment: .leading, spacing: 8) {
                            Text("OCR.space API Key")
                                .font(.headline)
                            SecureField("K8...", text: $ocrSpaceKey)
                                .textFieldStyle(.roundedBorder)
                            
                            Link("Get a Free API Key", destination: URL(string: "https://ocr.space/ocrapi")!)
                                .font(.caption)
                                .foregroundColor(.accentColor)
                        }
                    }
                }
                .padding(.horizontal)
                .frame(height: 100, alignment: .top)
                
                if showSuccessMessage {
                    Text("Settings saved successfully!")
                        .foregroundColor(.green)
                        .font(.caption)
                        .transition(.opacity)
                }
                
                HStack {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .keyboardShortcut(.cancelAction)
                    
                    Spacer()
                    
                    Button("Save Keys") {
                        saveKeys()
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
            .padding(.top)
        }
        .frame(width: 400, height: 350)
        .onAppear {
            loadKeys()
        }
    }
    
    private func loadKeys() {
        if let key = KeychainService.shared.getOpenAIKey() {
            openAIKey = key
        }
        if let key = KeychainService.shared.getGeminiKey() {
            geminiKey = key
        }
        if let key = KeychainService.shared.getOCRSpaceKey() {
            ocrSpaceKey = key
        }
    }
    
    private func saveKeys() {
        // Save OpenAI Key
        if !openAIKey.isEmpty {
            _ = KeychainService.shared.saveOpenAIKey(openAIKey)
        } else if KeychainService.shared.getOpenAIKey() != nil {
            // Only delete if it was previously set and now is empty
             _ = KeychainService.shared.deleteOpenAIKey()
        }
        
        // Save Gemini Key
        if !geminiKey.isEmpty {
            _ = KeychainService.shared.saveGeminiKey(geminiKey)
        } else if KeychainService.shared.getGeminiKey() != nil {
             _ = KeychainService.shared.deleteGeminiKey()
        }
        
        // Save OCR Space Key
        if !ocrSpaceKey.isEmpty {
            _ = KeychainService.shared.saveOCRSpaceKey(ocrSpaceKey)
        } else if KeychainService.shared.getOCRSpaceKey() != nil {
             _ = KeychainService.shared.deleteOCRSpaceKey()
        }
        
        // Show success and close
        withAnimation {
            showSuccessMessage = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isPresented = false
        }
    }
}
