import SwiftUI

struct PromptView: View {
    @State private var activityText: String
    @FocusState private var isTextFieldFocused: Bool
    @State private var pastActivities: [String] = []
    
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
                
                // Dynamic autocomplete suggestions
                if !suggestions.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(suggestions, id: \.self) { suggestion in
                            Button(action: {
                                activityText = suggestion
                            }) {
                                HStack {
                                    Image(systemName: "arrow.uturn.left")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(suggestion)
                                        .font(.system(.subheadline, design: .rounded))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                    Spacer()
                                }
                                .padding(.vertical, 4)
                                .padding(.horizontal, 8)
                                .background(Color.secondary.opacity(0.08))
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
    
    private func saveAndClose() {
        let trimmed = activityText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            onSave(trimmed)
        }
    }
}
