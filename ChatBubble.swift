import SwiftUI

struct ChatBubble: View {
    let message: Message
    var onShowTimestamp: ((Date) -> Void)? = nil

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isUser {
                Spacer(minLength: 52)
                bubbleCore
            } else {
                Text("🤖")
                    .font(.system(size: 20))
                    .accessibilityHidden(true)
                bubbleCore
                Spacer(minLength: 52)
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var bubbleCore: some View {
        // Verbatim: dynamic strings must not go through LocalizedStringKey (wrong or clipped text in the sheet).
        let text = Text(verbatim: message.text)
            .font(.system(size: 16, weight: .medium, design: .rounded))
            .foregroundStyle(message.isUser ? Color.white : BuddyColors.transcriptBuddyText)
            .multilineTextAlignment(message.isUser ? .trailing : .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(message.isUser ? BuddyColors.kidBubble : BuddyColors.transcriptBuddyFill)
                    .shadow(color: Color.black.opacity(message.isUser ? 0 : 0.06), radius: message.isUser ? 0 : 2, y: 1)
            }
            .overlay {
                if !message.isUser {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.black.opacity(0.07), lineWidth: 1)
                }
            }

        if let onShowTimestamp {
            text.contextMenu {
                Button("Show time") {
                    onShowTimestamp(message.date)
                }
            }
        } else {
            text
        }
    }
}
