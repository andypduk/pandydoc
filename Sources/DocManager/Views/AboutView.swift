import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Image(pdfNamed: "PandaHead")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 128, height: 128)
            
            Text("PandyDoc")
                .font(.title)
                .fontWeight(.bold)
            
            VStack(spacing: 4) {
                Text("Version \(appVersion) (\(buildNumber))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("macOS Document Management System")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            Text("Copyright © 2026 PandyDoc. All rights reserved.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(width: 320, height: 280)
        .padding()
    }
}

#Preview {
    AboutView()
}
