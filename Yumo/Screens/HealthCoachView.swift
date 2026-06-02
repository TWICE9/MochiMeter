import SwiftUI

struct ChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
    let timestamp = Date()
}

struct HealthCoachView: View {
    static var hasAnalyzedSession = false
    let initialContext: CoachContext
    @Environment(\.dismiss) var dismiss
    
    // State
    @State private var messages: [ChatMessage] = [] // Start empty for "Thinking" effect
    @State private var inputText: String = ""
    @State private var isTyping: Bool = false
    @State private var isContextExpanded: Bool = false
    @State private var isInitializing: Bool = !HealthCoachView.hasAnalyzedSession
    
    // Colors
    private let primaryTextColor = Color("AppPrimaryText")
    private let secondaryTextColor = Color("AppSecondaryText")
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                _buildDynamicBackground()
                    .onTapGesture {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                
                // Content Switcher
                if isInitializing {
                    MochiLoadingView()
                        .transition(.opacity.animation(.easeInOut(duration: 0.5)))
                } else {
                    mainChatContent
                        .transition(.move(edge: .bottom).combined(with: .opacity).animation(.spring(response: 0.6, dampingFraction: 0.8)))
                }
            }
            .navigationTitle("Mochi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                performInitialAnalysis()
            }
        }
    }
    
    // Extracted Main Content to keep body clean
    var mainChatContent: some View {
        VStack(spacing: 0) {
            
            // --- 1. Mochi's Context Header ---
            CoachContextHeader(context: initialContext, isExpanded: $isContextExpanded)
                .padding(.horizontal)
                .padding(.top, 8)
            
            // --- 2. Chat List ---
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(messages) { msg in
                            ChatBubble(message: msg)
                                .transition(.scale(scale: 0.9, anchor: .bottomLeading).combined(with: .opacity))
                        }
                        
                        if isTyping {
                            HStack {
                                TypingIndicator()
                                Spacer()
                            }
                            .padding(.horizontal)
                            .id("typingIndicator")
                            .transition(.opacity)
                        }
                        
                        // Spacer for bottom content
                        Color.clear.frame(height: 60)
                    }
                    .padding()
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: messages.count) { _, _ in
                    if let last = messages.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: isTyping) { _, typing in
                    if typing {
                        withAnimation {
                            proxy.scrollTo("typingIndicator", anchor: .bottom)
                        }
                    }
                }
            }
            
            // --- 3. Quick Prompt Chips ---
            if !isTyping && messages.count > 0 {
                QuickPromptChips { prompt in
                    inputText = prompt
                    sendMessage()
                }
                .padding(.bottom, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // --- 4. Input Area ---
            HStack(alignment: .bottom) {
                TextField("Ask Mochi...", text: $inputText, axis: .vertical)
                    .lineLimit(1...5)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(uiColor: .secondarySystemBackground))
                            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )
                    .submitLabel(.send)
                    .onSubmit(sendMessage)
                
                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(inputText.isEmpty ? .gray : Color("AppPrimaryAccent"))
                }
                .disabled(inputText.isEmpty || isTyping)
            }
            .padding()
            .background(.regularMaterial)
        }
    }
    
    // MARK: - Actions
    
    func performInitialAnalysis() {
        // If we've already done this in the current session, skip animation
        if Self.hasAnalyzedSession {
            if messages.isEmpty {
                 messages.append(ChatMessage(text: "Welcome back! How can I help?", isUser: false))
            }
            return
        }
        
        // Only run if empty
        guard messages.isEmpty else { return }
        
        Self.hasAnalyzedSession = true
        
        // Simulate "Thinking" delay
        triggerHaptic(style: .light)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation {
                isInitializing = false
                messages.append(ChatMessage(text: "Hi! I'm Mochi. I've analyzed your recent activity and nutrition. How can I help you optimize your day?", isUser: false))
                triggerHaptic(style: .medium) // Success haptic
            }
        }
    }
    
    func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        triggerHaptic(style: .light) // Sent haptic
        
        let userMsg = ChatMessage(text: text, isUser: true)
        withAnimation {
            messages.append(userMsg)
            inputText = ""
            isTyping = true
        }
        
        Task {
            do {
                // Call AI with full conversation history
                let currentHistory = Array(messages.dropLast()) // Exclude the user message we JUST added
                
                let reply = try await AICoachService.shared.askCoach(
                    message: text,
                    history: currentHistory,
                    context: initialContext
                )
                
                await MainActor.run {
                    withAnimation {
                        let aiMsg = ChatMessage(text: reply, isUser: false)
                        messages.append(aiMsg)
                        isTyping = false
                        triggerHaptic(style: .medium) // Received haptic
                    }
                }
            } catch {
                await MainActor.run {
                    withAnimation {
                        messages.append(ChatMessage(text: "Error: \(error.localizedDescription)", isUser: false))
                        isTyping = false
                        triggerHaptic(style: .heavy) // Error haptic
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func _buildDynamicBackground() -> some View {
        ZStack {
            Color("AppPrimaryDark").ignoresSafeArea()
            
            // Modern Static Mesh-like Glow (No Animation)
            GeometryReader { proxy in
                ZStack {
                    // Top Left Glow
                    Circle()
                        .fill(Color("AppSecondaryAccent").opacity(0.1))
                        .frame(width: proxy.size.width * 0.8)
                        .blur(radius: 80)
                        .offset(x: -proxy.size.width * 0.2, y: -proxy.size.height * 0.2)
                    
                    // Bottom Right Glow
                    Circle()
                        .fill(Color("AppPrimaryAccent").opacity(0.08))
                        .frame(width: proxy.size.width * 0.8)
                        .blur(radius: 80)
                        .offset(x: proxy.size.width * 0.2, y: proxy.size.height * 0.2)
                }
            }
            .ignoresSafeArea()
        }
    }

    func triggerHaptic(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
}

// MARK: - Subviews

struct MochiLoadingView: View {
    @State private var isPulsing = false
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "waveform.path.ecg")
                .resizable()
                .scaledToFit()
                .frame(width: 60, height: 60)
                .foregroundStyle(Color("AppPrimaryAccent").gradient)
                .scaleEffect(isPulsing ? 1.1 : 0.9)
                .opacity(isPulsing ? 1.0 : 0.6)
            
            Text("Mochi is analyzing your data...")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }
}

struct ChatBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isUser { Spacer() }
            
            // AI Icon for AI messages
            if !message.isUser {
                Image(systemName: "brain.head.profile")
                    .foregroundStyle(Color("AppPrimaryAccent"))
                    .font(.caption2)
                    .padding(6)
                    .background(Color("AppPrimaryAccent").opacity(0.1))
                    .clipShape(Circle())
            }
            
            Text(.init(message.text))
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(
                            message.isUser
                            ? AnyShapeStyle(Color("AppPrimaryAccent"))
                            : AnyShapeStyle(.thickMaterial)
                        )
                        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                )
                .foregroundStyle(message.isUser ? .white : .primary)
                // Add a subtle tail effect based on corners
                .clipShape(
                    RoundedRectangle(cornerRadius: 18)
                )
                .frame(maxWidth: 280, alignment: message.isUser ? .trailing : .leading)
            
            if !message.isUser { Spacer() }
        }
    }
}

struct QuickPromptChips: View {
    var onTap: (String) -> Void
    
    let prompts = [
        "📊 Analyze my day",
        "🥗 What should I eat?",
        "💪 Recovery status?",
        "📉 Macro breakdown",
        "🚀 Motivation!"
    ]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(prompts, id: \.self) { prompt in
                    Button {
                        onTap(prompt)
                    } label: {
                        Text(prompt)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color("AppPrimaryAccent"))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Color("AppPrimaryAccent").opacity(0.1))
                            )
                            .overlay(
                                Capsule()
                                    .stroke(Color("AppPrimaryAccent").opacity(0.3), lineWidth: 1)
                            )
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

struct CoachContextHeader: View {
    let context: CoachContext
    @Binding var isExpanded: Bool
    
    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 12) {
                Divider()
                    .padding(.vertical, 4)
                
                HStack(spacing: 0) {
                    // Calories
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Calories")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("\(Int(context.currentCalories)) / \(Int(context.goalCalories))")
                            .font(.caption.bold())
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Protein
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Protein")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("\(Int(context.currentProtein)) / \(Int(context.goalProtein))g")
                            .font(.caption.bold())
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Activity
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Activity")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(context.recentActivity)
                            .font(.caption.bold())
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        } label: {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundStyle(Color.purple)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 0) {
                    Text("Mochi's Context")
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                    
                    if !isExpanded {
                        Text(context.readinessStatus)
                            .font(.caption2)
                            .foregroundStyle(statusColor)
                    }
                }
                
                Spacer()
                
                if isExpanded {
                    Text(context.readinessStatus)
                        .font(.caption.bold())
                        .foregroundStyle(statusColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(statusColor.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
        .animation(.snappy, value: isExpanded)
    }
    
    var statusColor: Color {
        let status = context.readinessStatus
        if status.contains("High") || status.contains("Fuel") || status.contains("Needs") {
            return .red
        } else if status.contains("Recovery") || status.contains("Moderate") {
            return .orange
        } else {
            return .green
        }
    }
}

struct TypingIndicator: View {
    @State private var offset: CGFloat = 0
    
    var body: some View {
        HStack(spacing: 4) {
            Circle().frame(width: 8, height: 8).opacity(0.5).offset(y: offset)
            Circle().frame(width: 8, height: 8).opacity(0.5).offset(y: -offset)
            Circle().frame(width: 8, height: 8).opacity(0.5).offset(y: offset)
        }
        .foregroundStyle(.gray)
        .padding(12)
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(16)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5).repeatForever()) {
                offset = 4
            }
        }
    }
}
