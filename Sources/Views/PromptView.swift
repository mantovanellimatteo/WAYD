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
                    textField.stringValue = match
                    parent.text = match
                    
                    // Select the autocompleted part
                    let completedRange = NSRange(location: typed.count, length: match.count - typed.count)
                    editor.selectedRange = completedRange
                    isCompleting = false
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

struct PromptView: View {
    @State private var activityText: String
    @State private var pastActivities: [String] = []
    
    // Autocomplete selection state
    @State private var selectedSuggestionIndex: Int? = nil
    
    var title: String
    var onSave: (String) -> Void
    var onCancel: () -> Void
    
    init(title: String = "Cosa stai facendo?", initialText: String = "", onSave: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        self.title = title
        self._activityText = State(initialValue: initialText)
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
                    text: $activityText,
                    selectedIndex: $selectedSuggestionIndex,
                    placeholder: "Sto lavorando a...",
                    onCommit: {
                        saveAndClose()
                    },
                    suggestions: pastActivities,
                    onMoveDown: {
                        selectNextSuggestion()
                    },
                    onMoveUp: {
                        selectPreviousSuggestion()
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
                if !suggestions.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(0..<suggestions.count, id: \.self) { index in
                            let suggestion = suggestions[index]
                            let isSelected = selectedSuggestionIndex == index
                            
                            Button(action: {
                                activityText = suggestion
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
                .disabled(activityText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 360, height: 200)
        .onAppear {
            // Load unique past activities
            let loaded = LogManager.shared.loadEntries()
            let uniqueActivities = Array(Set(loaded.map { $0.activity })).sorted()
            pastActivities = uniqueActivities
        }
    }
    
    private var suggestions: [String] {
        let trimmed = activityText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        
        return pastActivities.filter { activity in
            let actLower = activity.lowercased()
            // Make sure it doesn't match the exact text, otherwise no suggestion needed
            return actLower.hasPrefix(trimmed) && actLower != trimmed
        }
        .prefix(3)
        .map { $0 }
    }
    
    private func selectNextSuggestion() {
        guard !suggestions.isEmpty else { return }
        let nextIndex: Int
        if let current = selectedSuggestionIndex {
            if current < suggestions.count - 1 {
                nextIndex = current + 1
            } else {
                nextIndex = current
            }
        } else {
            nextIndex = 0
        }
        selectedSuggestionIndex = nextIndex
        activityText = suggestions[nextIndex]
    }
    
    private func selectPreviousSuggestion() {
        guard !suggestions.isEmpty else { return }
        if let current = selectedSuggestionIndex {
            if current > 0 {
                let prevIndex = current - 1
                selectedSuggestionIndex = prevIndex
                activityText = suggestions[prevIndex]
            } else {
                selectedSuggestionIndex = nil
                // Optionally reset to what the user typed before?
                // But keeping current is fine.
            }
        }
    }
    
    private func saveAndClose() {
        let trimmed = activityText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        var finalActivity = trimmed
        if !suggestions.isEmpty {
            if let index = selectedSuggestionIndex, index >= 0 && index < suggestions.count {
                finalActivity = suggestions[index]
            } else if selectedSuggestionIndex == nil {
                // If there's an exact suggestion matching prefix, let's use it
                finalActivity = suggestions[0]
            }
        }
        
        let finalTrimmed = finalActivity.trimmingCharacters(in: .whitespacesAndNewlines)
        if !finalTrimmed.isEmpty {
            onSave(finalTrimmed)
        }
    }
}
