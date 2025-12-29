import SwiftUI
import SwiftData

struct ShoppingListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @Query private var items: [ShoppingItem]
    
    @State private var newItemName: String = ""
    private var userId: String

    init(userId: String) {
        self.userId = userId
        let predicate = #Predicate<ShoppingItem> { $0.userId == userId }
        _items = Query(filter: predicate, sort: [SortDescriptor(\ShoppingItem.createdAt, order: .forward)]) 
    }

    // For animated background
    @State private var offset1: CGSize = .zero
    @State private var offset2: CGSize = .zero
    @FocusState private var isInputFocused: Bool

    // MARK: - Adaptive Colors
    private var primaryTextColor: Color {
        colorScheme == .dark ? .white : Color(red: 32/255, green: 32/255, blue: 38/255)
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.7) : Color(red: 100/255, green: 100/255, blue: 110/255)
    }

    private var tertiaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.5) : Color(red: 140/255, green: 140/255, blue: 150/255)
    }

    private var backgroundColor: Color {
        colorScheme == .dark ? Color("AppPrimaryDark") : Color(red: 244/255, green: 245/255, blue: 247/255)
    }

    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.white
    }

    private var cardBorderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.2) : Color.black.opacity(0.08)
    }

    private var placeholderColor: Color {
        colorScheme == .dark ? .white.opacity(0.6) : Color(red: 160/255, green: 160/255, blue: 170/255)
    }

    var body: some View {
        ZStack {
            _buildDynamicBackground()
                .onTapGesture {
                    dismissKeyboard()
                }
            
            VStack(spacing: 0) {
                
                // Input bar
                _buildAddItemBar()
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                
                // List + Empty State
                ZStack {
                    // 📌 Placeholder when list is empty
                    if items.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "cart.badge.plus")
                                .font(.system(size: 48))
                                .foregroundColor(tertiaryTextColor)
                                .symbolEffect(.pulse)

                            Text("Your shopping list is empty")
                                .font(.title3.bold())
                                .foregroundColor(primaryTextColor.opacity(0.85))

                            Text("Add items above to get started")
                                .font(.callout)
                                .foregroundColor(secondaryTextColor)
                        }
                        .padding(.horizontal, 24)
                        .multilineTextAlignment(.center)
                        .transition(.opacity)
                    }
                    
                    // Actual list
                    ScrollViewReader { proxy in
                        List {
                            ForEach(items) { item in
                                _buildListRow(item: item)
                                    .id(item.id)
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(Color.clear)
                                    .padding(.vertical, 0.5)
                            }
                            .onDelete(perform: deleteItems)
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .safeAreaInset(edge: .bottom) {
                            Spacer()
                                .frame(height: 80)
                        }
                        .onChange(of: items.count) { _, _ in
                            if let lastItem = items.last {
                                withAnimation {
                                    proxy.scrollTo(lastItem.id, anchor: .bottom)
                                }
                            }
                        }
                    }

                }
                .padding(.top, 10)
                .onTapGesture { dismissKeyboard() }
            }
            .navigationTitle("Shopping List")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            animateOrbs()
            syncWithCloud()
        }
    }

    // MARK: - Actions
    
    private func syncWithCloud() {
        guard !userId.isEmpty else { return }
        
        Task { @MainActor in
            do {
                let dtos = try await CloudShoppingManager.shared.fetchShoppingItems(userId: userId)
                
                for dto in dtos {
                    let id = dto.id
                    let date = CloudShoppingManager.shared.parseDate(dto.created_at)
                    
                    let descriptor = FetchDescriptor<ShoppingItem>(
                        predicate: #Predicate { $0.id == id }
                    )
                    
                    if let existing = try? modelContext.fetch(descriptor).first {
                        // Update existing if different (Cloud Wins)
                        if existing.isCompleted != dto.is_completed || existing.name != dto.name {
                            existing.isCompleted = dto.is_completed
                            existing.name = dto.name
                            existing.createdAt = date
                        }
                    } else {
                        // Insert new from Cloud
                        let newItem = ShoppingItem(
                            id: dto.id,
                            userId: userId,
                            name: dto.name,
                            isCompleted: dto.is_completed,
                            createdAt: date
                        )
                        modelContext.insert(newItem)
                    }
                }
                try? modelContext.save()
                print("🛒 Synced \(dtos.count) items from cloud")
            } catch {
                print("❌ Cloud Sync Failed: \(error.localizedDescription)")
            }
        }
    }
    
    private func addItem() {
        guard !newItemName.isEmpty else { return }
        
        let uid: String? = userId.isEmpty ? nil : userId
        let newItem = ShoppingItem(userId: uid, name: newItemName)
        modelContext.insert(newItem)
        
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // Cloud Sync
        if let uId = uid {
            let nId = newItem.id
            let nName = newItem.name
            let nComp = newItem.isCompleted
            let nDate = newItem.createdAt
            
            Task {
                await CloudShoppingManager.shared.upsert(id: nId, userId: uId, name: nName, isCompleted: nComp, createdAt: nDate)
            }
        }
        
        newItemName = ""
    }
    
    private func toggleCompletion(item: ShoppingItem) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            item.isCompleted.toggle()
        }
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        // Cloud Sync
        if !userId.isEmpty {
            let id = item.id
            let name = item.name
            let comp = item.isCompleted
            let date = item.createdAt
            let uId = userId
            
            Task {
                await CloudShoppingManager.shared.upsert(id: id, userId: uId, name: name, isCompleted: comp, createdAt: date)
            }
        }
    }
    
    private func deleteItems(at offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                let item = items[index]
                let id = item.id
                
                // Cloud Sync
                Task {
                    await CloudShoppingManager.shared.delete(id: id)
                }
                modelContext.delete(item)
            }
        }
    }

    // MARK: - Add Item Bar
    @ViewBuilder
    private func _buildAddItemBar() -> some View {
        HStack(spacing: 16) {
            TextField("", text: $newItemName, prompt:
                Text("Add new item...").foregroundColor(placeholderColor),
                axis: .vertical
            )
            .focused($isInputFocused)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(cardBackgroundColor)
                    .stroke(cardBorderColor, lineWidth: 1)
            )
            .foregroundStyle(primaryTextColor)
            .lineLimit(1...5)
            .onChange(of: newItemName) { _, newValue in
                if newValue.contains("\n") {
                    newItemName = newValue.replacingOccurrences(of: "\n", with: "")
                    addItem()
                }
            }

            Button(action: addItem) {
                Image(systemName: "plus.circle.fill")
                    .font(.title)
                    .foregroundStyle(Color("AppSecondaryAccent"))
            }
            .disabled(newItemName.isEmpty)
        }
    }
    
    // MARK: - List Row
    @ViewBuilder
    private func _buildListRow(item: ShoppingItem) -> some View {
        HStack(spacing: 16) {
            Image(systemName: item.isCompleted ? "checkmark.square.fill" : "square")
                .font(.title3)
                .foregroundStyle(item.isCompleted ? Color("AppSecondaryAccent") : secondaryTextColor)
                .onTapGesture {
                    toggleCompletion(item: item)
                }

            Text(item.name)
                .foregroundStyle(item.isCompleted ? tertiaryTextColor : primaryTextColor)
                .strikethrough(item.isCompleted, color: secondaryTextColor)

            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardBackgroundColor)
                .stroke(cardBorderColor, lineWidth: 1)
        )
    }

    // MARK: - Animated Background
    @ViewBuilder
    private func _buildDynamicBackground() -> some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            RadialGradient(
                gradient: Gradient(colors: [Color("AppSecondaryAccent").opacity(colorScheme == .dark ? 0.3 : 0.15), .clear]),
                center: .topLeading, startRadius: 50, endRadius: 450
            )
            .offset(offset1)
            .offset(x: -150, y: -150)
            .ignoresSafeArea()

            RadialGradient(
                gradient: Gradient(colors: [Color("AppPrimaryAccent").opacity(colorScheme == .dark ? 0.4 : 0.2), .clear]),
                center: .bottomTrailing, startRadius: 100, endRadius: 500
            )
            .offset(offset2)
            .offset(x: 100, y: 150)
            .ignoresSafeArea()
        }
        .blur(radius: 60)
    }
    
    private func animateOrbs() {
        withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
            offset1 = CGSize(width: 80, height: 60)
        }
        withAnimation(.easeInOut(duration: 10).repeatForever(autoreverses: true)) {
            offset2 = CGSize(width: -100, height: -70)
        }
    }
    
    // MARK: - Keyboard Dismiss
    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
    }
}
