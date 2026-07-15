import Foundation

struct LogEntry: Identifiable, Hashable, Codable {
    let id: UUID
    var date: String
    var time: String
    var activity: String
    
    init(id: UUID = UUID(), date: String, time: String, activity: String) {
        self.id = id
        self.date = date
        self.time = time
        self.activity = activity
    }
    
    var csvLine: String {
        let escapedActivity = activity.replacingOccurrences(of: "\"", with: "\"\"")
        return "\(date),\(time),\"\(escapedActivity)\"\n"
    }
}

class LogManager {
    static let shared = LogManager()
    
    private var logFileURL: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent("WAYD_log.csv")
    }
    
    private var lastEntryFileURL: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".last_entry.txt")
    }
    
    // Ensure files exist
    init() {
        if !FileManager.default.fileExists(atPath: logFileURL.path) {
            FileManager.default.createFile(atPath: logFileURL.path, contents: nil)
        }
    }
    
    // Write new activity
    func logActivity(_ activity: String) {
        let trimmed = activity.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let now = Date()
        
        // Formatting date and time separately to match old style
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "it_IT")
        dateFormatter.dateFormat = "EEEE d MMMM yyyy" // e.g. "mercoledì 15 luglio 2026"
        let dateString = dateFormatter.string(from: now).capitalized
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"
        let timeString = timeFormatter.string(from: now)
        
        let entry = LogEntry(date: dateString, time: timeString, activity: trimmed)
        
        // Append to CSV
        appendLine(entry.csvLine)
        
        // Write to last entry
        writeLastEntry(trimmed)
    }
    
    // Read all entries
    func loadEntries() -> [LogEntry] {
        var content = ""
        if let utf8Content = try? String(contentsOf: logFileURL, encoding: .utf8) {
            content = utf8Content
        } else if let latin1Content = try? String(contentsOf: logFileURL, encoding: .isoLatin1) {
            content = latin1Content
        } else if let macOSRomanContent = try? String(contentsOf: logFileURL, encoding: .macOSRoman) {
            content = macOSRomanContent
        } else {
            return []
        }
        
        var entries: [LogEntry] = []
        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            if let entry = parseLine(line) {
                entries.append(entry)
            }
        }
        return entries
    }
    
    // Rewrite last entry in log and file
    func correctLastEntry(newActivity: String) {
        let trimmed = newActivity.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        var entries = loadEntries()
        guard !entries.isEmpty else {
            // If empty, just log as new
            logActivity(trimmed)
            return
        }
        
        // Update the last entry
        entries[entries.count - 1].activity = trimmed
        
        // Re-write entire file
        let newContent = entries.map { $0.csvLine }.joined()
        try? newContent.write(to: logFileURL, atomically: true, encoding: .utf8)
        
        // Update last entry file
        writeLastEntry(trimmed)
    }
    
    // Update a specific entry by its index
    func updateEntry(at index: Int, newActivity: String) {
        let trimmed = newActivity.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        var entries = loadEntries()
        guard index >= 0 && index < entries.count else { return }
        
        entries[index].activity = trimmed
        
        // Re-write entire file
        let newContent = entries.map { $0.csvLine }.joined()
        try? newContent.write(to: logFileURL, atomically: true, encoding: .utf8)
        
        // If it was the last entry, also update the last entry file
        if index == entries.count - 1 {
            writeLastEntry(trimmed)
        }
    }
    
    // Delete a specific entry by its index
    func deleteEntry(at index: Int) {
        var entries = loadEntries()
        guard index >= 0 && index < entries.count else { return }
        
        entries.remove(at: index)
        
        // Re-write entire file
        let newContent = entries.map { $0.csvLine }.joined()
        try? newContent.write(to: logFileURL, atomically: true, encoding: .utf8)
        
        // Update last entry file if necessary
        if entries.isEmpty {
            writeLastEntry("")
        } else {
            writeLastEntry(entries.last!.activity)
        }
    }
    
    // Get last entry string
    func getLastEntry() -> String {
        if let content = try? String(contentsOf: lastEntryFileURL, encoding: .utf8) {
            return content.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return ""
    }
    
    // Helpers
    private func writeLastEntry(_ text: String) {
        try? text.write(to: lastEntryFileURL, atomically: true, encoding: .utf8)
    }
    
    private func appendLine(_ line: String) {
        if let fileHandle = try? FileHandle(forWritingTo: logFileURL) {
            fileHandle.seekToEndOfFile()
            if let data = line.data(using: .utf8) {
                fileHandle.write(data)
            }
            fileHandle.closeFile()
        } else {
            try? line.write(to: logFileURL, atomically: true, encoding: .utf8)
        }
    }
    
    private func parseLine(_ line: String) -> LogEntry? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        
        // Find first comma
        guard let firstCommaIndex = trimmed.firstIndex(of: ",") else { return nil }
        let datePart = String(trimmed[..<firstCommaIndex])
        
        let afterFirstComma = trimmed[trimmed.index(after: firstCommaIndex)...]
        // Find second comma
        guard let secondCommaIndex = afterFirstComma.firstIndex(of: ",") else { return nil }
        let timePart = String(afterFirstComma[..<secondCommaIndex])
        
        var activityPart = String(afterFirstComma[afterFirstComma.index(after: secondCommaIndex)...])
        
        // Trim surrounding quotes if they exist
        if activityPart.hasPrefix("\"") && activityPart.hasSuffix("\"") {
            activityPart = String(activityPart.dropFirst().dropLast())
        }
        
        let activity = activityPart.replacingOccurrences(of: "\"\"", with: "\"")
        return LogEntry(date: datePart, time: timePart, activity: activity)
    }
}
