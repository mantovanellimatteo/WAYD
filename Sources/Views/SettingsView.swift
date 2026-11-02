import SwiftUI

class SettingsViewModel: ObservableObject {
    @Published var workHoursEnabled: Bool {
        didSet {
            UserDefaults.standard.set(workHoursEnabled, forKey: "workHoursEnabled")
            notifyChange()
        }
    }
    
    @Published var workDaysOption: String {
        didSet {
            UserDefaults.standard.set(workDaysOption, forKey: "workDaysOption")
            notifyChange()
        }
    }
    
    @Published var startDate: Date {
        didSet {
            let hour = Calendar.current.component(.hour, from: startDate)
            let minute = Calendar.current.component(.minute, from: startDate)
            UserDefaults.standard.set(hour, forKey: "workStartHour")
            UserDefaults.standard.set(minute, forKey: "workStartMinute")
            notifyChange()
        }
    }
    
    @Published var endDate: Date {
        didSet {
            let hour = Calendar.current.component(.hour, from: endDate)
            let minute = Calendar.current.component(.minute, from: endDate)
            UserDefaults.standard.set(hour, forKey: "workEndHour")
            UserDefaults.standard.set(minute, forKey: "workEndMinute")
            notifyChange()
        }
    }
    
    @Published var promptInterval: TimeInterval {
        didSet {
            UserDefaults.standard.set(promptInterval, forKey: "promptInterval")
            notifyChange()
        }
    }
    
    init() {
        let storedEnabled = UserDefaults.standard.object(forKey: "workHoursEnabled") == nil ? true : UserDefaults.standard.bool(forKey: "workHoursEnabled")
        self.workHoursEnabled = storedEnabled
        
        self.workDaysOption = UserDefaults.standard.string(forKey: "workDaysOption") ?? "weekdays"
        
        let startH = UserDefaults.standard.object(forKey: "workStartHour") == nil ? 9 : UserDefaults.standard.integer(forKey: "workStartHour")
        let startM = UserDefaults.standard.integer(forKey: "workStartMinute")
        self.startDate = SettingsViewModel.dateWith(hour: startH, minute: startM)
        
        let endH = UserDefaults.standard.object(forKey: "workEndHour") == nil ? 18 : UserDefaults.standard.integer(forKey: "workEndHour")
        let endM = UserDefaults.standard.integer(forKey: "workEndMinute")
        self.endDate = SettingsViewModel.dateWith(hour: endH, minute: endM)
        
        let interval = UserDefaults.standard.double(forKey: "promptInterval")
        self.promptInterval = interval > 0 ? interval : 1800
    }
    
    private static func dateWith(hour: Int, minute: Int) -> Date {
        var comp = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comp.hour = hour
        comp.minute = minute
        comp.second = 0
        return Calendar.current.date(from: comp) ?? Date()
    }
    
    private func notifyChange() {
        NotificationCenter.default.post(name: Notification.Name("SettingsChanged"), object: nil)
    }
}

struct SettingsView: View {
    @StateObject private var vm = SettingsViewModel()
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: "clock.badge.checkmark.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Orario di Lavoro & Preferenze")
                        .font(.system(.headline, design: .rounded))
                        .fontWeight(.bold)
                    Text("Configura quando WAYD deve chiederti cosa stai facendo")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.bottom, 4)
            
            Divider()
            
            // Working hours section
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Attiva orario di lavoro", isOn: $vm.workHoursEnabled)
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.medium)
                
                if vm.workHoursEnabled {
                    VStack(alignment: .leading, spacing: 10) {
                        Picker("Giorni attivi:", selection: $vm.workDaysOption) {
                            Text("Lunedì – Venerdì (Giorni feriali)").tag("weekdays")
                            Text("Tutti i giorni (Inclusi weekend)").tag("all")
                        }
                        .pickerStyle(.menu)
                        
                        HStack(spacing: 20) {
                            HStack(spacing: 6) {
                                Text("Inizio:")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                DatePicker("", selection: $vm.startDate, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                            }
                            
                            HStack(spacing: 6) {
                                Text("Fine:")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                DatePicker("", selection: $vm.endDate, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                            }
                            
                            Spacer()
                        }
                        
                        Text("💡 Fuori orario lavorativo WAYD andrà in pausa automaticamente. La sera potrai riattivarlo temporaneamente dal menu.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.leading, 18)
                }
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
            )
            
            // Frequency section
            VStack(alignment: .leading, spacing: 8) {
                Text("Frequenza dei Prompt:")
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.semibold)
                
                Picker("", selection: $vm.promptInterval) {
                    Text("15 Minuti").tag(TimeInterval(900))
                    Text("30 Minuti").tag(TimeInterval(1800))
                    Text("1 Ora").tag(TimeInterval(3600))
                    Text("2 Ore").tag(TimeInterval(7200))
                }
                .pickerStyle(.segmented)
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
            )
            
            Spacer()
            
            // Bottom actions
            HStack {
                Spacer()
                Button("Chiudi") {
                    DispatchQueue.main.async {
                        NSApp.keyWindow?.close()
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 450, height: 400)
    }
}
