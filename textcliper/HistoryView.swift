//
//  HistoryView.swift
//  textcliper
//
//  Created by Michael on 08/10/2025.
//

import SwiftUI

struct HistoryView: View {
    @ObservedObject var historyService = HistoryService.shared
    @ObservedObject var cloudSync = CloudSyncService.shared

    @State private var searchText = ""
    @State private var selectedItem: HistoryItem?

    var filteredItems: [HistoryItem] {
        let items = historyService.items.sorted { $0.timestamp > $1.timestamp }
        if searchText.isEmpty {
            return items
        }
        return items.filter { $0.text.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                HStack {
                    Text("Capture History")
                        .font(.headline)

                    Spacer()

                    // Sync status
                    syncStatusView
                }

                TextField("Search history...", text: $searchText)
                    .textFieldStyle(.roundedBorder)

                // Stats bar
                HStack(spacing: 16) {
                    StatLabel(icon: "doc.text", value: "\(historyService.items.count)", label: "items")
                    StatLabel(icon: "character", value: historyService.storageSize, label: "size")

                    Spacer()

                    Button("Clear All") {
                        clearHistory()
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
                }
                .font(.system(size: 12))
            }
            .padding()

            Divider()

            // List
            if filteredItems.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)

                    Text(searchText.isEmpty ? "No captures yet" : "No matching captures")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredItems) { item in
                            HistoryRow(item: item) {
                                selectedItem = item
                            } onDelete: {
                                deleteItem(item)
                            }
                        }
                    }
                    .padding()
                }
            }

            Divider()

            // Footer
            HStack {
                Toggle("Enable iCloud Sync", isOn: $cloudSync.iCloudSyncEnabled)
                    .font(.system(size: 12))
                    .help("Sync OCR history across your devices via iCloud")

                Spacer()

                Text("Last sync: \(cloudSync.lastSyncText)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .padding()
        }
        .frame(width: 600, height: 500)
        .sheet(item: $selectedItem) { item in
            HistoryDetailView(item: item)
        }
    }

    private var syncStatusView: some View {
        Group {
            switch cloudSync.syncStatus {
            case .idle:
                if cloudSync.iCloudSyncEnabled {
                    Image(systemName: "icloud")
                        .foregroundColor(.blue)
                }
            case .syncing:
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Image(systemName: "icloud")
                        .foregroundColor(.blue)
                }
            case .success:
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.icloud")
                        .foregroundColor(.green)
                }
            case .error(let message):
                Image(systemName: "exclamationmark.icloud")
                    .foregroundColor(.red)
                    .help(message)
            }
        }
        .font(.system(size: 14))
    }

    private func deleteItem(_ item: HistoryItem) {
        withAnimation {
            historyService.deleteItem(item)
        }
    }

    private func clearHistory() {
        let alert = NSAlert()
        alert.messageText = "Clear All History?"
        alert.informativeText = "This will delete all \(historyService.items.count) captured items. This action cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Clear")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            historyService.clearAll()
        }
    }
}

// MARK: - History Row

struct HistoryRow: View {
    let item: HistoryItem
    let onTap: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            // Device indicator
            VStack {
                Image(systemName: item.isSynced ? "icloud.fill" : "desktopcomputer")
                    .font(.system(size: 16))
                    .foregroundColor(item.isSynced ? .blue : .gray)
            }
            .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.preview + (item.text.count > 50 ? "..." : ""))
                    .font(.system(size: 13))
                    .lineLimit(2)
                    .foregroundColor(.primary)

                HStack(spacing: 12) {
                    Label("\(item.wordCount) words", systemImage: "text.word.spacing")
                    Label(item.timeAgo, systemImage: "clock")
                    if item.isSynced {
                        Label(item.deviceName, systemImage: "laptopcomputer")
                    }
                }
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            }

            Spacer()

            if isHovered {
                HStack(spacing: 8) {
                    Button(action: {
                        ClipboardManager.shared.copyToClipboard(item.text)
                    }) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)
                    .help("Copy")

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                    .help("Delete")
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? Color.accentColor.opacity(0.1) : Color.clear)
        )
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture(perform: onTap)
    }
}

// MARK: - Stat Label

struct StatLabel: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
            Text(value)
                .fontWeight(.medium)
            Text(label)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - History Detail View

struct HistoryDetailView: View {
    let item: HistoryItem
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("Captured Text")
                    .font(.headline)

                Spacer()

                Button("Done") {
                    dismiss()
                }
            }

            Divider()

            // Content
            ScrollView {
                Text(item.text)
                    .font(.system(size: 13))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(nsColor: .textBackgroundColor))
                    )
            }

            // Metadata
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("\(item.characterCount) characters", systemImage: "textformat")
                    Spacer()
                    Label("\(item.wordCount) words", systemImage: "text.word.spacing")
                }

                HStack {
                    Label(item.timestamp.formatted(), systemImage: "calendar")
                    Spacer()
                    if item.isSynced {
                        Label(item.deviceName, systemImage: "laptopcomputer")
                    }
                }
            }
            .font(.system(size: 12))
            .foregroundColor(.secondary)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )

            // Actions
            HStack {
                Button("Copy") {
                    ClipboardManager.shared.copyToClipboard(item.text)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)

                Button("Share...") {
                    // Use native macOS share picker
                    let picker = NSSharingServicePicker(items: [item.text])
                    if let window = NSApp.windows.first(where: { $0.isVisible }),
                       let contentView = window.contentView {
                        picker.show(relativeTo: contentView.bounds, of: contentView, preferredEdge: .minY)
                    }
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .frame(width: 500, height: 400)
    }
}

#Preview {
    HistoryView()
}
