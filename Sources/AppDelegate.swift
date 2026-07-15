import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var timer: Timer?
    
    // Settings state (defaults)
    var promptInterval: TimeInterval = 1800 // 30 minutes (1800 seconds)
    var promptEnabled: Bool = true
    
    // Windows
    var promptWindow: NSWindow?
    var historyWindow: NSWindow?
    var aboutWindow: NSWindow?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create Status Item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            if let image = NSImage(systemSymbolName: "clock", accessibilityDescription: "WAYD") {
                image.isTemplate = true
                button.image = image
            }
            updateStatusBarTitle()
        }
        
        // Build Menu
        buildMenu()
        
        // Start Timer
        startTimer()
        
        // Listen for changes
        NotificationCenter.default.addObserver(self, selector: #selector(lastEntryChanged), name: Notification.Name("LastEntryChanged"), object: nil)
        
        // Prompt immediately on launch after a small delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            if self?.promptEnabled == true {
                self?.showPromptWindow()
            }
        }
    }
    
    @objc func lastEntryChanged() {
        updateStatusBarTitle()
        buildMenu() // Rebuild menu to update the "Ultimo log" label
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
        
        let viewLogItem = NSMenuItem(title: "Visualizza registro log...", action: #selector(viewLogClicked), keyEquivalent: "l")
        viewLogItem.target = self
        menu.addItem(viewLogItem)
        
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
        showPromptWindow()
    }
    
    @objc func viewLogClicked() {
        showHistoryWindow()
    }
    
    @objc func togglePromptClicked() {
        promptEnabled.toggle()
        buildMenu()
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
            if self?.promptEnabled == true {
                self?.showPromptWindow()
            }
        }
    }
    
    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    // Windows Management
    func showPromptWindow() {
        // Force the app to take focus, bringing the popup to the front
        NSApp.activate(ignoringOtherApps: true)
        
        if promptWindow != nil {
            promptWindow?.makeKeyAndOrderFront(nil)
            return
        }
        
        let contentView = PromptView(
            onSave: { [weak self] text in
                LogManager.shared.logActivity(text)
                self?.promptWindow?.close()
                self?.promptWindow = nil
                self?.updateStatusBarTitle()
                self?.buildMenu()
            },
            onCancel: { [weak self] in
                self?.promptWindow?.close()
                self?.promptWindow = nil
            }
        )
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 140),
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
            contentRect: NSRect(x: 0, y: 0, width: 550, height: 450),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Registro Attività (WAYD)"
        window.contentView = NSHostingView(rootView: contentView)
        window.isMovableByWindowBackground = true
        
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: nil) { [weak self] _ in
            self?.historyWindow = nil
        }
        
        self.historyWindow = window
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
        
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: nil) { [weak self] _ in
            self?.aboutWindow = nil
        }
        
        self.aboutWindow = window
        window.makeKeyAndOrderFront(nil)
    }
}
