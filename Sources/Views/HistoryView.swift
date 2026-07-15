import SwiftUI

struct IndexedEntry {
    let entry: LogEntry
    let originalIndex: Int
}

struct HistoryView: View {
    @State private var entries: [LogEntry] = []
    @State private var searchText: String = ""
    @State private var filterDate = Date()
    @State private var useDateFilter = false
    
    @State private var editingEntryIndex: Int? = nil
    @State private var editingText: String = ""
    @State private var isEditing = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with search & filter
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Cerca nelle attività...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(8)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
                
                HStack {
                    Toggle("Filtra per data:", isOn: $useDateFilter)
                        .toggleStyle(.checkbox)
                    
                    DatePicker("", selection: $filterDate, displayedComponents: .date)
                        .labelsHidden()
                        .disabled(!useDateFilter)
                    
                    Spacer()
                    
                    Button(action: refreshData) {
                        Label("Aggiorna", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // List of entries
            if filteredEntriesWithIndex.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock.badge.exclamationmark")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("Nessuna attività trovata")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.controlBackgroundColor))
            } else {
                List {
                    ForEach(filteredEntriesWithIndex, id: \.entry.id) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.entry.activity)
                                    .font(.system(.body, design: .rounded))
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                HStack(spacing: 8) {
                                    Text(item.entry.date)
                                    Text("•")
                                    Text(item.entry.time)
                                }
                                .font(.system(.caption))
                                .foregroundColor(.secondary)
                            }
                            Spacer()
                            
                            HStack(spacing: 8) {
                                Button(action: {
                                    startEditing(entry: item.entry, index: item.originalIndex)
                                }) {
                                    Image(systemName: "pencil")
                                        .foregroundColor(.accentColor)
                                }
                                .buttonStyle(.borderless)
                                .help("Modifica questa attività")
                                
                                Button(action: {
                                    deleteEntry(at: item.originalIndex)
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.borderless)
                                .help("Elimina questa attività")
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.sidebar)
            }
        }
        .frame(minWidth: 500, minHeight: 400)
        .onAppear(perform: refreshData)
        .sheet(isPresented: $isEditing) {
            PromptView(
                title: "Modifica attività",
                initialText: editingText,
                onSave: { newText in
                    if let index = editingEntryIndex {
                        LogManager.shared.updateEntry(at: index, newActivity: newText)
                        refreshData()
                        // Notify the system that the last entry might have changed
                        NotificationCenter.default.post(name: Notification.Name("LastEntryChanged"), object: nil)
                    }
                    isEditing = false
                },
                onCancel: {
                    isEditing = false
                }
            )
        }
    }
    
    private func refreshData() {
        entries = LogManager.shared.loadEntries()
    }
    
    private func deleteEntry(at index: Int) {
        let alert = NSAlert()
        alert.messageText = "Eliminare questa attività?"
        alert.informativeText = "Questa azione rimuoverà permanentemente l'attività selezionata dal file di log."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Elimina")
        alert.addButton(withTitle: "Annulla")
        
        if alert.runModal() == .alertFirstButtonReturn {
            LogManager.shared.deleteEntry(at: index)
            refreshData()
            // Notify the system that the last entry might have changed
            NotificationCenter.default.post(name: Notification.Name("LastEntryChanged"), object: nil)
        }
    }
    
    private func startEditing(entry: LogEntry, index: Int) {
        editingEntryIndex = index
        editingText = entry.activity
        isEditing = true
    }
    
    // Filtered entries zipped with original index, sorted newest first
    private var filteredEntriesWithIndex: [IndexedEntry] {
        var result: [IndexedEntry] = []
        
        let targetDateString: String?
        if useDateFilter {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "it_IT")
            formatter.dateFormat = "EEEE d MMMM yyyy"
            targetDateString = formatter.string(from: filterDate).capitalized
        } else {
            targetDateString = nil
        }
        
        for (index, entry) in entries.enumerated() {
            // Filter by search text
            if !searchText.isEmpty {
                if !entry.activity.localizedCaseInsensitiveContains(searchText) {
                    continue
                }
            }
            
            // Filter by date
            if let targetDate = targetDateString {
                if entry.date != targetDate {
                    continue
                }
            }
            
            result.append(IndexedEntry(entry: entry, originalIndex: index))
        }
        
        // Return reversed (newest first)
        return result.reversed()
    }
}
