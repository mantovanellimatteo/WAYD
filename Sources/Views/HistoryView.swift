import SwiftUI

struct IndexedEntry {
    let entry: LogEntry
    let originalIndex: Int
}

enum DatePreset: String, CaseIterable, Identifiable {
    case custom = "Personalizzato"
    case thisWeek = "Questa settimana"
    case thisMonth = "Questo mese"
    case lastMonth = "Mese scorso"
    
    var id: String { self.rawValue }
}

class HistoryViewModel: ObservableObject {
    @Published var entries: [LogEntry] = []
    @Published var searchText: String = ""
    
    // Date filter states
    @Published var useDateFilter: Bool = false
    @Published var startDate: Date = Date()
    @Published var endDate: Date = Date()
    @Published var selectedPreset: DatePreset = .custom
    
    @Published var editingEntryIndex: Int? = nil
    @Published var editingText: String = ""
    @Published var isEditing: Bool = false
    
    func refreshData() {
        entries = LogManager.shared.loadEntries()
    }
    
    func deleteEntry(at index: Int) {
        let alert = NSAlert()
        alert.messageText = "Eliminare questa attività?"
        alert.informativeText = "Questa azione rimuoverà permanentemente l'attività selezionata dal file di log."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Elimina")
        alert.addButton(withTitle: "Annulla")
        
        if alert.runModal() == .alertFirstButtonReturn {
            LogManager.shared.deleteEntry(at: index)
            refreshData()
            NotificationCenter.default.post(name: Notification.Name("LastEntryChanged"), object: nil)
        }
    }
    
    func startEditing(entry: LogEntry, index: Int) {
        editingEntryIndex = index
        editingText = entry.activity
        isEditing = true
    }
    
    func applyPreset(_ preset: DatePreset) {
        let calendar = Calendar.current
        let now = Date()
        
        switch preset {
        case .custom:
            break
        case .thisWeek:
            var calendarIt = calendar
            calendarIt.firstWeekday = 2 // Monday (Italian standard)
            if let startOfWeek = calendarIt.date(from: calendarIt.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) {
                startDate = startOfWeek
                endDate = now
            }
        case .thisMonth:
            if let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) {
                startDate = startOfMonth
                endDate = now
            }
        case .lastMonth:
            if let startOfThisMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)),
               let startOfLastMonth = calendar.date(byAdding: .month, value: -1, to: startOfThisMonth),
               let endOfLastMonth = calendar.date(byAdding: .second, value: -1, to: startOfThisMonth) {
                startDate = startOfLastMonth
                endDate = endOfLastMonth
            }
        }
    }
    
    // Filtered entries zipped with original index, sorted newest first
    var filteredEntriesWithIndex: [IndexedEntry] {
        var result: [IndexedEntry] = []
        let calendar = Calendar.current
        
        // Define boundaries for date filtering (inclusive of entire days)
        let start = calendar.startOfDay(for: startDate)
        let startOfNextDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: endDate)) ?? endDate
        let end = calendar.date(byAdding: .second, value: -1, to: startOfNextDay) ?? endDate
        
        for (index, entry) in entries.enumerated() {
            // Filter by search text
            if !searchText.isEmpty {
                if !entry.activity.localizedCaseInsensitiveContains(searchText) {
                    continue
                }
            }
            
            // Filter by date range
            if useDateFilter {
                if let entryDate = entry.parsedDate {
                    if entryDate < start || entryDate > end {
                        continue
                    }
                } else {
                    continue // Exclude if we cannot parse the date
                }
            }
            
            result.append(IndexedEntry(entry: entry, originalIndex: index))
        }
        
        // Return reversed (newest first)
        return result.reversed()
    }
}

struct HistoryView: View {
    @StateObject private var vm = HistoryViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with search & filter
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Cerca nelle attività...", text: $vm.searchText)
                        .textFieldStyle(.plain)
                }
                .padding(8)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
                
                HStack(spacing: 8) {
                    Toggle("Filtra per data:", isOn: $vm.useDateFilter)
                        .toggleStyle(.checkbox)
                    
                    if vm.useDateFilter {
                        Picker("", selection: $vm.selectedPreset) {
                            ForEach(DatePreset.allCases) { preset in
                                Text(preset.rawValue).tag(preset)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 140)
                        .onChange(of: vm.selectedPreset) { _, newValue in
                            vm.applyPreset(newValue)
                        }
                        
                        DatePicker("Da:", selection: $vm.startDate, displayedComponents: .date)
                            .labelsHidden()
                        
                        Text("a:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        DatePicker("A:", selection: $vm.endDate, displayedComponents: .date)
                            .labelsHidden()
                    }
                    
                    Spacer()
                    
                    Button(action: vm.refreshData) {
                        Label("Aggiorna", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // List of entries
            if vm.filteredEntriesWithIndex.isEmpty {
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
                    ForEach(vm.filteredEntriesWithIndex, id: \.entry.id) { item in
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
                                    vm.startEditing(entry: item.entry, index: item.originalIndex)
                                }) {
                                    Image(systemName: "pencil")
                                        .foregroundColor(.accentColor)
                                }
                                .buttonStyle(.borderless)
                                .help("Modifica questa attività")
                                
                                Button(action: {
                                    vm.deleteEntry(at: item.originalIndex)
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
        .frame(minWidth: 600, minHeight: 450)
        .onAppear(perform: vm.refreshData)
        .sheet(isPresented: $vm.isEditing) {
            PromptView(
                title: "Modifica attività",
                initialText: vm.editingText,
                onSave: { newText in
                    if let index = vm.editingEntryIndex {
                        LogManager.shared.updateEntry(at: index, newActivity: newText)
                        vm.refreshData()
                        NotificationCenter.default.post(name: Notification.Name("LastEntryChanged"), object: nil)
                    }
                    vm.isEditing = false
                },
                onCancel: {
                    vm.isEditing = false
                }
            )
        }
    }
}
