import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var timer: Timer?
    var minuteTimer: Timer?
    
    // Settings state (defaults)
    var promptInterval: TimeInterval {
        get {
            let stored = UserDefaults.standard.double(forKey: "promptInterval")
            return stored > 0 ? stored : 1800
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "promptInterval")
        }
    }
    var promptEnabled: Bool = true
    
    var workHoursEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: "workHoursEnabled") == nil { return true }
            return UserDefaults.standard.bool(forKey: "workHoursEnabled")
        }
        set { UserDefaults.standard.set(newValue, forKey: "workHoursEnabled") }
    }
    
    var workDaysOption: String {
        get { UserDefaults.standard.string(forKey: "workDaysOption") ?? "weekdays" }
        set { UserDefaults.standard.set(newValue, forKey: "workDaysOption") }
    }
    
    var workStartHour: Int {
        get {
            if UserDefaults.standard.object(forKey: "workStartHour") == nil { return 9 }
            return UserDefaults.standard.integer(forKey: "workStartHour")
        }
        set { UserDefaults.standard.set(newValue, forKey: "workStartHour") }
    }
    
    var workStartMinute: Int {
        get { UserDefaults.standard.integer(forKey: "workStartMinute") }
        set { UserDefaults.standard.set(newValue, forKey: "workStartMinute") }
    }
    
    var workEndHour: Int {
        get {
            if UserDefaults.standard.object(forKey: "workEndHour") == nil { return 18 }
            return UserDefaults.standard.integer(forKey: "workEndHour")
        }
        set { UserDefaults.standard.set(newValue, forKey: "workEndHour") }
    }
    
    var workEndMinute: Int {
        get { UserDefaults.standard.integer(forKey: "workEndMinute") }
        set { UserDefaults.standard.set(newValue, forKey: "workEndMinute") }
    }
    
    var overtimeUntil: Date? {
        get {
            let ts = UserDefaults.standard.double(forKey: "overtimeUntil")
            return ts > 0 ? Date(timeIntervalSince1970: ts) : nil
        }
        set {
            if let date = newValue {
                UserDefaults.standard.set(date.timeIntervalSince1970, forKey: "overtimeUntil")
            } else {
                UserDefaults.standard.removeObject(forKey: "overtimeUntil")
            }
        }
    }
    
    var isOvertimeActive: Bool {
        guard let until = overtimeUntil else { return false }
        if Date() < until {
            return true
        } else {
            overtimeUntil = nil
            return false
        }
    }
    
    func isWithinWorkingHours() -> Bool {
        guard workHoursEnabled else { return true }
        
        let now = Date()
        let calendar = Calendar.current
        
        if workDaysOption == "weekdays" {
            let weekday = calendar.component(.weekday, from: now)
            // 1 = Sunday, 7 = Saturday
            if weekday == 1 || weekday == 7 {
                return false
            }
        }
        
        let currentMinutes = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)
        let startMinutes = workStartHour * 60 + workStartMinute
        let endMinutes = workEndHour * 60 + workEndMinute
        
        if startMinutes <= endMinutes {
            return currentMinutes >= startMinutes && currentMinutes < endMinutes
        } else {
            return currentMinutes >= startMinutes || currentMinutes < endMinutes
        }
    }
    
    func isActivityAllowed() -> Bool {
        if isOvertimeActive {
            return true
        }
        return isWithinWorkingHours()
    }
    
    // Windows
    var promptWindow: NSWindow?
    var historyWindow: NSWindow?
    var aboutWindow: NSWindow?
    var settingsWindow: NSWindow?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create Status Item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if statusItem.button != nil {
            updateStatusBarImage()
            updateStatusBarTitle()
        }
        
        // Build Menu
        buildMenu()
        
        // Start Timer
        startTimer()
        startMinuteCheck()
        
        // Listen for changes
        NotificationCenter.default.addObserver(self, selector: #selector(lastEntryChanged), name: Notification.Name("LastEntryChanged"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(settingsChanged), name: Notification.Name("SettingsChanged"), object: nil)
        
        // Prompt immediately on launch after a small delay only if in activity time
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            if self.promptEnabled && self.isActivityAllowed() {
                self.showPromptWindow(isCorrection: false)
            }
        }
    }
    
    @objc func lastEntryChanged() {
        updateStatusBarTitle()
        buildMenu() // Rebuild menu to update the "Ultimo log" label
    }
    
    @objc func settingsChanged() {
        startTimer()
        updateStatusBarImage()
        updateStatusBarTitle()
        buildMenu()
    }
    
    func updateStatusBarTitle() {
        guard let button = statusItem.button else { return }
        let lastEntry = LogManager.shared.getLastEntry()
        if !lastEntry.isEmpty {
            // Trim to prevent menu bar overflow
            let trimmed = lastEntry.count > 25 ? String(lastEntry.prefix(22)) + "..." : lastEntry
            button.title = " " + trimmed
        } else {
            button.title = ""
        }
    }
    
    func updateStatusBarImage() {
        guard let button = statusItem.button else { return }
        
        if !promptEnabled {
            if let image = NSImage(systemSymbolName: "clock", accessibilityDescription: "WAYD (Disattivato)") {
                image.isTemplate = true
                button.image = image
            }
            button.alphaValue = 0.35
        } else if isOvertimeActive {
            if let image = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: "WAYD (Straordinario)") {
                image.isTemplate = true
                button.image = image
            }
            button.alphaValue = 1.0
        } else if !isWithinWorkingHours() {
            if let image = NSImage(systemSymbolName: "moon.fill", accessibilityDescription: "WAYD (Fuori orario)") {
                image.isTemplate = true
                button.image = image
            }
            button.alphaValue = 0.55
        } else {
            if let image = NSImage(systemSymbolName: "clock", accessibilityDescription: "WAYD") {
                image.isTemplate = true
                button.image = image
            }
            button.alphaValue = 1.0
        }
    }
    
    func buildMenu() {
        let menu = NSMenu()
        
        let lastEntry = LogManager.shared.getLastEntry()
        if !lastEntry.isEmpty {
            let lastItem = NSMenuItem(title: "Ultimo log: \(lastEntry)", action: nil, keyEquivalent: "")
            lastItem.isEnabled = false
            menu.addItem(lastItem)
            menu.addItem(NSMenuItem.separator())
        }
        
        let newEntryItem = NSMenuItem(title: "Inserisci nuova attività...", action: #selector(newEntryClicked), keyEquivalent: "n")
        newEntryItem.target = self
        menu.addItem(newEntryItem)
        
        let correctLastItem = NSMenuItem(title: "Modifica ultima voce...", action: #selector(correctLastClicked), keyEquivalent: "e")
        correctLastItem.target = self
        correctLastItem.isEnabled = !lastEntry.isEmpty
        menu.addItem(correctLastItem)
        
        let viewLogItem = NSMenuItem(title: "Visualizza registro log...", action: #selector(viewLogClicked), keyEquivalent: "l")
        viewLogItem.target = self
        menu.addItem(viewLogItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Status & Overtime Section
        if !promptEnabled {
            let disabledItem = NSMenuItem(title: "⚠️ Prompt disattivato manualmente", action: nil, keyEquivalent: "")
            disabledItem.isEnabled = false
            menu.addItem(disabledItem)
        } else if isOvertimeActive {
            let df = DateFormatter()
            df.dateFormat = "HH:mm"
            let untilStr = overtimeUntil != nil ? df.string(from: overtimeUntil!) : ""
            let otItem = NSMenuItem(title: "⚡ Straordinario attivo (fino alle \(untilStr))", action: nil, keyEquivalent: "")
            otItem.isEnabled = false
            menu.addItem(otItem)
            
            let stopOtItem = NSMenuItem(title: "Termina straordinario", action: #selector(stopOvertimeClicked), keyEquivalent: "")
            stopOtItem.target = self
            menu.addItem(stopOtItem)
        } else if !isWithinWorkingHours() {
            let restItem = NSMenuItem(title: "🌙 Fuori orario lavorativo (In pausa)", action: nil, keyEquivalent: "")
            restItem.isEnabled = false
            menu.addItem(restItem)
            
            let overtimeMenu = NSMenu()
            
            let item1h = NSMenuItem(title: "Attiva per 1 ora", action: #selector(overtime1HourClicked), keyEquivalent: "")
            item1h.target = self
            overtimeMenu.addItem(item1h)
            
            let item2h = NSMenuItem(title: "Attiva per 2 ore", action: #selector(overtime2HoursClicked), keyEquivalent: "")
            item2h.target = self
            overtimeMenu.addItem(item2h)
            
            let itemMidnight = NSMenuItem(title: "Attiva per questa sera (fino a mezzanotte)", action: #selector(overtimeMidnightClicked), keyEquivalent: "")
            itemMidnight.target = self
            overtimeMenu.addItem(itemMidnight)
            
            let resumeSubmenu = NSMenuItem(title: "Riprendi temporaneamente...", action: nil, keyEquivalent: "")
            resumeSubmenu.submenu = overtimeMenu
            menu.addItem(resumeSubmenu)
        } else {
            let activeItem = NSMenuItem(title: "🟢 In orario lavorativo (Attivo)", action: nil, keyEquivalent: "")
            activeItem.isEnabled = false
            menu.addItem(activeItem)
        }
        
        menu.addItem(NSMenuItem.separator())
        
        // Enable/Disable Prompt
        let togglePromptItem = NSMenuItem(title: "Prompt attivo", action: #selector(togglePromptClicked), keyEquivalent: "")
        togglePromptItem.target = self
        togglePromptItem.state = promptEnabled ? .on : .off
        menu.addItem(togglePromptItem)
        
        // Frequency Submenu
        let freqMenu = NSMenu()
        let intervals: [(String, TimeInterval)] = [
            ("15 Minuti", 900),
            ("30 Minuti", 1800),
            ("1 Ora", 3600),
            ("2 Ore", 7200)
        ]
        for (label, seconds) in intervals {
            let item = NSMenuItem(title: label, action: #selector(changeIntervalClicked(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = seconds
            item.state = (promptInterval == seconds) ? .on : .off
            freqMenu.addItem(item)
        }
        
        let freqSubmenuItem = NSMenuItem(title: "Frequenza prompt", action: nil, keyEquivalent: "")
        freqSubmenuItem.submenu = freqMenu
        menu.addItem(freqSubmenuItem)
        
        let settingsItem = NSMenuItem(title: "Impostazioni orario di lavoro...", action: #selector(settingsClicked), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        let startupItem = NSMenuItem(title: "Avvia all'avvio...", action: #selector(launchAtStartupClicked), keyEquivalent: "")
        startupItem.target = self
        menu.addItem(startupItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let aboutItem = NSMenuItem(title: "Info su WAYD", action: #selector(aboutClicked), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)
        
        let quitItem = NSMenuItem(title: "Esci", action: #selector(quitClicked), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem.menu = menu
    }
    
    @objc func newEntryClicked() {
        showPromptWindow(isCorrection: false)
    }
    
    @objc func correctLastClicked() {
        showPromptWindow(isCorrection: true)
    }
    
    @objc func launchAtStartupClicked() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }
    
    @objc func viewLogClicked() {
        showHistoryWindow()
    }
    
    @objc func settingsClicked() {
        showSettingsWindow()
    }
    
    @objc func overtime1HourClicked() {
        startOvertime(hours: 1.0)
    }
    
    @objc func overtime2HoursClicked() {
        startOvertime(hours: 2.0)
    }
    
    @objc func overtimeMidnightClicked() {
        startOvertimeUntilMidnight()
    }
    
    @objc func stopOvertimeClicked() {
        cancelOvertime()
    }
    
    func startOvertime(hours: Double) {
        overtimeUntil = Date().addingTimeInterval(hours * 3600)
        updateStatusBarImage()
        updateStatusBarTitle()
        buildMenu()
        showPromptWindow(isCorrection: false)
    }
    
    func startOvertimeUntilMidnight() {
        let calendar = Calendar.current
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()),
           let midnight = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: tomorrow) {
            overtimeUntil = midnight
        } else {
            overtimeUntil = Date().addingTimeInterval(4 * 3600)
        }
        updateStatusBarImage()
        updateStatusBarTitle()
        buildMenu()
        showPromptWindow(isCorrection: false)
    }
    
    func cancelOvertime() {
        overtimeUntil = nil
        updateStatusBarImage()
        updateStatusBarTitle()
        buildMenu()
    }
    
    @objc func togglePromptClicked() {
        promptEnabled.toggle()
        buildMenu()
        updateStatusBarImage()
        if promptEnabled {
            startTimer()
        } else {
            stopTimer()
        }
    }
    
    @objc func changeIntervalClicked(_ sender: NSMenuItem) {
        if let seconds = sender.representedObject as? TimeInterval {
            promptInterval = seconds
            buildMenu()
            if promptEnabled {
                startTimer()
            }
        }
    }
    
    @objc func aboutClicked() {
        showAboutWindow()
    }
    
    @objc func quitClicked() {
        NSApplication.shared.terminate(self)
    }
    
    // Timer Control
    func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: promptInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            _ = self.isOvertimeActive
            self.updateStatusBarImage()
            self.buildMenu()
            
            if self.promptEnabled && self.isActivityAllowed() {
                self.showPromptWindow(isCorrection: false)
            }
        }
    }
    
    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    func startMinuteCheck() {
        minuteTimer?.invalidate()
        minuteTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            _ = self.isOvertimeActive
            self.updateStatusBarImage()
            self.buildMenu()
        }
    }
    
    // Windows Management
    func showPromptWindow(isCorrection: Bool = false) {
        // Force the app to take focus, bringing the popup to the front
        NSApp.activate(ignoringOtherApps: true)
        
        if promptWindow != nil {
            promptWindow?.makeKeyAndOrderFront(nil)
            return
        }
        
        let title = isCorrection ? "Modifica ultima attività:" : "Cosa stai facendo?"
        let initialText = isCorrection ? LogManager.shared.getLastEntry() : ""
        
        let contentView = PromptView(
            title: title,
            initialText: initialText,
            onSave: { [weak self] text in
                print("[WAYD DEBUG] onSave closure triggered. Logging/Correcting activity...")
                if isCorrection {
                    LogManager.shared.correctLastEntry(newActivity: text)
                } else {
                    LogManager.shared.logActivity(text)
                }
                print("[WAYD DEBUG] Activity logged. Scheduling window close on main queue...")
                DispatchQueue.main.async {
                    print("[WAYD DEBUG] Async close block started.")
                    guard let self = self else {
                        print("[WAYD DEBUG] Self is nil in async block!")
                        return
                    }
                    print("[WAYD DEBUG] Closing prompt window...")
                    self.promptWindow?.close()
                    print("[WAYD DEBUG] Setting prompt window reference to nil...")
                    self.promptWindow = nil
                    print("[WAYD DEBUG] Updating status bar title...")
                    self.updateStatusBarTitle()
                    print("[WAYD DEBUG] Rebuilding menu...")
                    self.buildMenu()
                    print("[WAYD DEBUG] Rebuilt menu complete.")
                }
            },
            onCancel: { [weak self] in
                print("[WAYD DEBUG] onCancel closure triggered. Scheduling window close...")
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.promptWindow?.close()
                    self.promptWindow = nil
                }
            }
        )
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 200),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "WAYD"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.contentView = NSHostingView(rootView: contentView)
        window.isMovableByWindowBackground = true
        window.level = .floating // Keep it on top of other app windows
        window.isReleasedWhenClosed = false
        
        // Handle window manual close by clicking 'x'
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: nil) { [weak self] _ in
            self?.promptWindow = nil
        }
        
        self.promptWindow = window
        window.makeKeyAndOrderFront(nil)
    }
    
    func showHistoryWindow() {
        NSApp.activate(ignoringOtherApps: true)
        
        if historyWindow != nil {
            historyWindow?.makeKeyAndOrderFront(nil)
            return
        }
        
        let contentView = HistoryView()
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 480),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Registro Attività (WAYD)"
        window.contentView = NSHostingView(rootView: contentView)
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: nil) { [weak self] _ in
            self?.historyWindow = nil
        }
        
        self.historyWindow = window
        window.makeKeyAndOrderFront(nil)
    }
    
    func showSettingsWindow() {
        NSApp.activate(ignoringOtherApps: true)
        
        if settingsWindow != nil {
            settingsWindow?.makeKeyAndOrderFront(nil)
            return
        }
        
        let contentView = SettingsView()
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Impostazioni"
        window.contentView = NSHostingView(rootView: contentView)
        window.isReleasedWhenClosed = false
        
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: nil) { [weak self] _ in
            self?.settingsWindow = nil
        }
        
        self.settingsWindow = window
        window.makeKeyAndOrderFront(nil)
    }
    
    func showAboutWindow() {
        NSApp.activate(ignoringOtherApps: true)
        
        if aboutWindow != nil {
            aboutWindow?.makeKeyAndOrderFront(nil)
            return
        }
        
        let contentView = AboutView()
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 260),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Informazioni"
        window.contentView = NSHostingView(rootView: contentView)
        window.isReleasedWhenClosed = false
        
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: nil) { [weak self] _ in
            self?.aboutWindow = nil
        }
        
        self.aboutWindow = window
        window.makeKeyAndOrderFront(nil)
    }
}

