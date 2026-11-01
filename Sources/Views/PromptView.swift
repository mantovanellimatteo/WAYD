import SwiftUI
import AppKit

struct AutocompleteTextField: NSViewRepresentable {
    @Binding var text: String
    @Binding var selectedIndex: Int?
    var placeholder: String
    var onCommit: () -> Void
    var suggestions: [String]
    var onMoveDown: () -> Void
    var onMoveUp: () -> Void
    
    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: AutocompleteTextField
        var isCompleting = false
        var isDeleting = false
        
        init(_ parent: AutocompleteTextField) {
            self.parent = parent
        }
        
        func controlTextDidChange(_ obj: Notification) {
            guard let textField = obj.object as? NSTextField else { return }
            let currentText = textField.stringValue
            
            parent.text = currentText
            
            // Reset selection because the user is typing manually
            parent.selectedIndex = nil
            
            if isDeleting {
                isDeleting = false
                return
            }
            
            guard let editor = textField.currentEditor() else { return }
            let selection = editor.selectedRange
            let isAtEnd = selection.location == currentText.count
            
            if isAtEnd && !isCompleting {
                let typed = currentText
                // Find matching prefix in suggestions
                if let match = parent.suggestions.first(where: { 
                    $0.lowercased().hasPrefix(typed.lowercased()) && $0.count > typed.count 
                }) {
                    isCompleting = true
                    DispatchQueue.main.async {
                        textField.stringValue = match
                        self.parent.text = match
                        
                        if let editor = textField.currentEditor() {
                            let completedRange = NSRange(location: typed.count, length: match.count - typed.count)
                            editor.selectedRange = completedRange
                        }
                        self.isCompleting = false
                    }
                }
            }
        }
        
        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.deleteBackward(_:)) ||
               commandSelector == #selector(NSResponder.deleteForward(_:)) {
                isDeleting = true
            } else if commandSelector == #selector(NSResponder.moveDown(_:)) {
                parent.onMoveDown()
                return true // Handled: don't move cursor
            } else if commandSelector == #selector(NSResponder.moveUp(_:)) {
                parent.onMoveUp()
                return true // Handled: don't move cursor
            }
            return false
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.placeholderString = placeholder
        textField.delegate = context.coordinator
        textField.isBezeled = false
        textField.drawsBackground = false
        textField.focusRingType = .none
        textField.font = .systemFont(ofSize: NSFont.systemFontSize)
        
        // Trigger focus
        DispatchQueue.main.async {
            textField.window?.makeFirstResponder(textField)
        }
        
        return textField
    }
    
    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }
}

class PromptViewModel: ObservableObject {
    @Published var activityText: String = ""
    @Published var pastActivities: [String] = []
    @Published var selectedSuggestionIndex: Int? = nil
    
    init(initialText: String = "") {
        self.activityText = initialText
    }
    
    func loadPastActivities() {
        let loaded = LogManager.shared.loadEntries()
        var unique: [String] = []
        var seen = Set<String>()
        for entry in loaded.reversed() {
            let activity = entry.activity.trimmingCharacters(in: .whitespacesAndNewlines)
            if !seen.contains(activity) && !activity.isEmpty {
                seen.insert(activity)
                unique.append(activity)
            }
        }
        self.pastActivities = unique
    }
    
    var suggestions: [String] {
        let trimmed = activityText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        
        return pastActivities.filter { activity in
            let actLower = activity.lowercased()
            return actLower.hasPrefix(trimmed) && actLower != trimmed
        }
        .prefix(3)
        .map { $0 }
    }
    
    func selectNextSuggestion() {
        let currentSuggestions = suggestions
        guard !currentSuggestions.isEmpty else { return }
        let nextIndex: Int
        if let current = selectedSuggestionIndex {
            if current < currentSuggestions.count - 1 {
                nextIndex = current + 1
            } else {
                nextIndex = current
            }
        } else {
            nextIndex = 0
        }
        selectedSuggestionIndex = nextIndex
        activityText = currentSuggestions[nextIndex]
    }
    
    func selectPreviousSuggestion() {
        let currentSuggestions = suggestions
        guard !currentSuggestions.isEmpty else { return }
        if let current = selectedSuggestionIndex {
            if current > 0 {
                let prevIndex = current - 1
                selectedSuggestionIndex = prevIndex
                activityText = currentSuggestions[prevIndex]
            } else {
                selectedSuggestionIndex = nil
            }
        }
    }
}

struct PromptView: View {
    @StateObject private var vm: PromptViewModel
    
    var title: String
    var onSave: (String) -> Void
    var onCancel: () -> Void
    
    init(title: String = "Cosa stai facendo?", initialText: String = "", onSave: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        self.title = title
        self._vm = StateObject(wrappedValue: PromptViewModel(initialText: initialText))
        self.onSave = onSave
        self.onCancel = onCancel
    }
    
    var body: some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.system(.title3, design: .rounded))
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 6) {
                // Using our native AppKit text field with autocomplete
                AutocompleteTextField(
                    text: $vm.activityText,
                    selectedIndex: $vm.selectedSuggestionIndex,
                    placeholder: "Sto lavorando a...",
                    onCommit: {
                        saveAndClose()
                    },
                    suggestions: vm.pastActivities,
                    onMoveDown: {
                        vm.selectNextSuggestion()
                    },
                    onMoveUp: {
                        vm.selectPreviousSuggestion()
                    }
                )
                .frame(height: 22)
                .padding(10)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.accentColor.opacity(0.3), lineWidth: 1.5)
                )
                
                // Dynamic autocomplete suggestions
                if !vm.suggestions.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(0..<vm.suggestions.count, id: \.self) { index in
                            let suggestion = vm.suggestions[index]
                            let isSelected = vm.selectedSuggestionIndex == index
                            
                            Button(action: {
                                vm.activityText = suggestion
                            }) {
                                HStack {
                                    Image(systemName: "arrow.uturn.left")
                                        .font(.caption)
                                        .foregroundColor(isSelected ? .accentColor : .secondary)
                                    Text(suggestion)
                                        .font(.system(.subheadline, design: .rounded))
                                        .fontWeight(isSelected ? .semibold : .regular)
                                        .foregroundColor(isSelected ? .accentColor : .secondary)
                                        .lineLimit(1)
                                    Spacer()
                                }
                                .padding(.vertical, 4)
                                .padding(.horizontal, 8)
                                .background(isSelected ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.08))
                                .cornerRadius(4)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .transition(.opacity)
                }
            }
            
            Spacer(minLength: 8)
            
            HStack(spacing: 12) {
                Button("Annulla") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Salva") {
                    saveAndClose()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(vm.activityText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 360, height: 200)
        .onAppear {
            vm.loadPastActivities()
        }
    }
    
    private func saveAndClose() {
        let trimmed = vm.activityText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        var finalActivity = trimmed
        if !vm.suggestions.isEmpty {
            if let index = vm.selectedSuggestionIndex, index >= 0 && index < vm.suggestions.count {
                finalActivity = vm.suggestions[index]
            } else if vm.selectedSuggestionIndex == nil {
                // If there's an exact suggestion matching prefix, let's use it
                finalActivity = vm.suggestions[0]
            }
        }
        
        let finalTrimmed = finalActivity.trimmingCharacters(in: .whitespacesAndNewlines)
        if !finalTrimmed.isEmpty {
            onSave(finalTrimmed)
        }
    }
}
