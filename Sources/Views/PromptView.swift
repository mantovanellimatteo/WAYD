import SwiftUI

struct PromptView: View {
    @State private var activityText: String
    @FocusState private var isTextFieldFocused: Bool
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
                TextField("Sto lavorando a...", text: $activityText)
                    .textFieldStyle(.plain)
                    .padding(10)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.accentColor.opacity(isTextFieldFocused ? 0.8 : 0.2), lineWidth: 1.5)
                    )
                    .focused($isTextFieldFocused)
                    .onSubmit {
                        saveAndClose()
                    }
                    .onChange(of: activityText) { _ in
                        // Reset selection when user types or edits text
                        selectedSuggestionIndex = nil
                    }
                
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
            
            // Hidden buttons to capture Arrow Up/Down keyboard events
            if !suggestions.isEmpty {
                Button("") {
                    selectNextSuggestion()
                }
                .keyboardShortcut(.downArrow, modifiers: [])
                .buttonStyle(.plain)
                .frame(width: 0, height: 0)
                .opacity(0)
                
                Button("") {
                    selectPreviousSuggestion()
                }
                .keyboardShortcut(.upArrow, modifiers: [])
                .buttonStyle(.plain)
                .frame(width: 0, height: 0)
                .opacity(0)
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
            
            // Focus text field
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isTextFieldFocused = true
            }
        }
    }
    
    private var suggestions: [String] {
        let trimmed = activityText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        
        return pastActivities.filter { activity in
            let actLower = activity.lowercased()
            return actLower.hasPrefix(trimmed) && actLower != trimmed
        }
        .prefix(3)
        .map { $0 }
    }
    
    private func selectNextSuggestion() {
        guard !suggestions.isEmpty else { return }
        if let current = selectedSuggestionIndex {
            if current < suggestions.count - 1 {
                selectedSuggestionIndex = current + 1
            }
        } else {
            selectedSuggestionIndex = 0
        }
    }
    
    private func selectPreviousSuggestion() {
        guard !suggestions.isEmpty else { return }
        if let current = selectedSuggestionIndex {
            if current > 0 {
                selectedSuggestionIndex = current - 1
            } else {
                selectedSuggestionIndex = nil
            }
        }
    }
    
    private func saveAndClose() {
        let trimmed = activityText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        var finalActivity = trimmed
        if !suggestions.isEmpty {
            if let index = selectedSuggestionIndex, index >= 0 && index < suggestions.count {
                // If a suggestion was explicitly selected via arrow keys
                finalActivity = suggestions[index]
            } else if selectedSuggestionIndex == nil {
                // Default: automatically take the first suggestion on submit if none is selected
                finalActivity = suggestions[0]
            }
        }
        
        let finalTrimmed = finalActivity.trimmingCharacters(in: .whitespacesAndNewlines)
        if !finalTrimmed.isEmpty {
            onSave(finalTrimmed)
        }
    }
}
