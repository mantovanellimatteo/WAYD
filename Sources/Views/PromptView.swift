import SwiftUI

struct PromptView: View {
    @State private var activityText: String
    @FocusState private var isTextFieldFocused: Bool
    
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
        VStack(spacing: 16) {
            Text(title)
                .font(.system(.title3, design: .rounded))
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
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
        .frame(width: 360, height: 140)
        .onAppear {
            // Force focus on appear
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isTextFieldFocused = true
            }
        }
    }
    
    private func saveAndClose() {
        let trimmed = activityText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            onSave(trimmed)
        }
    }
}
