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

struct ActivitySummaryItem: Identifiable {
    var id: String { activity }
    let activity: String
    let duration: TimeInterval
    let count: Int
    let color: Color
}

struct DayGroup: Identifiable {
    var id: String { dateString }
    let dateString: String
    let entries: [IndexedEntry]
    let summaryItems: [ActivitySummaryItem]
    let totalDuration: TimeInterval
    let totalEntries: Int
}

struct ActivityColor {
    static let palette: [Color] = [
        .blue, .green, .orange, .purple, .teal, .indigo, .pink, .cyan, .mint
    ]
    
    static func color(for activity: String) -> Color {
        let trimmed = activity.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let hash = abs(trimmed.hashValue)
        return palette[hash % palette.count]
    }
}

func formatDuration(seconds: TimeInterval) -> String {
    let totalMinutes = max(1, Int(round(seconds / 60)))
    let hours = totalMinutes / 60
    let minutes = totalMinutes % 60
    if hours > 0 && minutes > 0 {
        return "\(hours)h \(minutes)m"
    } else if hours > 0 {
        return "\(hours)h"
    } else {
        return "\(minutes)m"
    }
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
    
    // Entries grouped by day with computed summary statistics
    var dayGroups: [DayGroup] {
        let items = filteredEntriesWithIndex
        guard !items.isEmpty else { return [] }
        
        var groupedDict: [String: [IndexedEntry]] = [:]
        var orderedDays: [String] = []
        
        for item in items {
            let day = item.entry.date
            if groupedDict[day] == nil {
                groupedDict[day] = []
                orderedDays.append(day)
            }
            groupedDict[day]?.append(item)
        }
        
        let standardInterval: TimeInterval = {
            let stored = UserDefaults.standard.double(forKey: "promptInterval")
            return stored > 0 ? stored : 1800
        }()
        
        var groups: [DayGroup] = []
        
        for day in orderedDays {
            guard let dayEntries = groupedDict[day] else { continue }
            
            var activityCounts: [String: Int] = [:]
            var displayNames: [String: String] = [:]
            
            for item in dayEntries {
                let trimmed = item.entry.activity.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }
                let key = trimmed.lowercased()
                
                if displayNames[key] == nil {
                    displayNames[key] = trimmed
                }
                
                activityCounts[key, default: 0] += 1
            }
            
            var dayTotalDuration: TimeInterval = 0
            var summaryItems: [ActivitySummaryItem] = []
            
            for (key, count) in activityCounts {
                guard let name = displayNames[key] else { continue }
                let duration = TimeInterval(count) * standardInterval
                dayTotalDuration += duration
                
                summaryItems.append(ActivitySummaryItem(
                    activity: name,
                    duration: duration,
                    count: count,
                    color: ActivityColor.color(for: name)
                ))
            }
            
            summaryItems.sort { $0.duration > $1.duration }
            
            groups.append(DayGroup(
                dateString: day,
                entries: dayEntries,
                summaryItems: summaryItems,
                totalDuration: dayTotalDuration,
                totalEntries: dayEntries.count
            ))
        }
        
        return groups
    }
}

struct DaySummaryCard: View {
    let group: DayGroup
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header of the card
            HStack(alignment: .center) {
                Label {
                    Text("Riepilogo giornaliero")
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.bold)
                } icon: {
                    Image(systemName: "chart.bar.xaxis")
                        .foregroundColor(.accentColor)
                }
                
                Spacer()
                
                HStack(spacing: 5) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 10))
                    Text("Totale: \(formatDuration(seconds: group.totalDuration))")
                        .font(.system(.caption, design: .rounded))
                        .fontWeight(.bold)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.accentColor.opacity(0.12))
                .foregroundColor(.accentColor)
                .cornerRadius(6)
            }
            
            // Highlighted rows for each activity
            VStack(spacing: 5) {
                ForEach(group.summaryItems) { item in
                    HStack(spacing: 8) {
                        // Colored vertical accent bar
                        RoundedRectangle(cornerRadius: 2)
                            .fill(item.color)
                            .frame(width: 4, height: 22)
                        
                        // Activity Name
                        Text(item.activity)
                            .font(.system(.body, design: .rounded))
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        // Count badge
                        Text("\(item.count) \(item.count == 1 ? "voce" : "voci")")
                            .font(.system(.caption, design: .rounded))
                            .foregroundColor(.secondary)
                        
                        // Highlighted duration pill
                        Text(formatDuration(seconds: item.duration))
                            .font(.system(.subheadline, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundColor(item.color)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(item.color.opacity(0.18))
                            .cornerRadius(6)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(item.color.opacity(0.08)) // Clearly highlighted row
                    .cornerRadius(7)
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(item.color.opacity(0.28), lineWidth: 1)
                    )
                }
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.7))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
        )
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
            
            // List of entries grouped by day
            if vm.dayGroups.isEmpty {
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
                    ForEach(vm.dayGroups) { group in
                        Section {
                            // Highlighted summary card at the start of each day
                            DaySummaryCard(group: group)
                                .listRowInsets(EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10))
                                .listRowSeparator(.hidden)
                            
                            // Individual log entries for this day
                            ForEach(group.entries, id: \.entry.id) { item in
                                HStack(spacing: 10) {
                                    Circle()
                                        .fill(ActivityColor.color(for: item.entry.activity))
                                        .frame(width: 8, height: 8)
                                    
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(item.entry.activity)
                                            .font(.system(.body, design: .rounded))
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)
                                        HStack(spacing: 8) {
                                            Text(item.entry.time)
                                            Text("•")
                                            Text(item.entry.date)
                                        }
                                        .font(.system(.caption, design: .rounded))
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
                                .padding(.vertical, 3)
                            }
                        } header: {
                            HStack(spacing: 6) {
                                Image(systemName: "calendar")
                                    .foregroundColor(.accentColor)
                                Text(group.dateString)
                                    .font(.system(.headline, design: .rounded))
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .frame(minWidth: 620, minHeight: 480)
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
