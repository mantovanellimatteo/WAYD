import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)
            
            VStack(spacing: 4) {
                Text("WAYD")
                    .font(.system(.title2, design: .rounded))
                    .fontWeight(.bold)
                Text("Versione 1.0.0")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Text("Un'applicazione nativa per macOS che monitora la tua produttività chiedendoti periodicamente la tua attività corrente.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            Divider()
            
            Text("Sviluppato con ❤️ per macOS")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button("Chiudi") {
                NSApp.keyWindow?.close()
            }
            .buttonStyle(.bordered)
        }
        .padding(24)
        .frame(width: 320, height: 260)
    }
}
