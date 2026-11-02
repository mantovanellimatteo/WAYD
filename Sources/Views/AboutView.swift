import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 64, height: 64)
                .cornerRadius(14)
                .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
            
            VStack(spacing: 4) {
                Text("WAYD")
                    .font(.system(.title2, design: .rounded))
                    .fontWeight(.bold)
                Text("Versione 2.0")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Text("Un'applicazione nativa per macOS che monitora la tua produttività chiedendoti periodicamente la tua attività corrente.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            Divider()
            
            Text("Developed by Matteo Mantovanelli - Smeup ICS srl")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button("Chiudi") {
                DispatchQueue.main.async {
                    NSApp.keyWindow?.close()
                }
            }
            .buttonStyle(.bordered)
        }
        .padding(24)
        .frame(width: 320, height: 260)
    }
}
