import SwiftUI

struct QuickRefCard: View {
    let title: String
    let description: String
    let icon: String
    let action: (() -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
            Text(title)
                .font(.headline)
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
            if let action = action {
                Divider()
                Button("Learn More", action: action)
                    .buttonStyle(.plain)
                    .font(.caption)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct WalkthroughSection: View {
    let title: String
    let steps: [String]
    let tip: String?
    let warning: String?
    
    var body: some View {
        DisclosureGroup(title) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(index + 1).")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.accentColor)
                        Text(step)
                            .font(.subheadline)
                    }
                }
                
                if let tip = tip {
                    TipBox(text: tip, style: .tip)
                }
                
                if let warning = warning {
                    TipBox(text: warning, style: .warning)
                }
            }
            .padding(.top, 8)
        }
        .padding(.vertical, 4)
    }
}

struct TipBox: View {
    let text: String
    let style: TipStyle
    
    enum TipStyle {
        case tip, warning
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: style == .warning ? "exclamationmark.triangle.fill" : "lightbulb.fill")
                .foregroundColor(style == .warning ? .orange : Color(red: 0.85, green: 0.65, blue: 0.125))
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(8)
        .background(style == .warning ? Color.orange.opacity(0.1) : Color.yellow.opacity(0.1))
        .cornerRadius(6)
    }
}

struct HelpSectionHeader: View {
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.bottom, 16)
    }
}
