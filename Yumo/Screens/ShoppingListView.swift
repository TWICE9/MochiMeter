import SwiftUI

struct ShoppingListView: View {
    @EnvironmentObject var viewModel: ShoppingListViewModel
    @Environment(\.colorScheme) private var colorScheme

    // For animated background
    @State private var offset1: CGSize = .zero
    @State private var offset2: CGSize = .zero

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
                    if viewModel.items.isEmpty {
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
                    List {
                        ForEach($viewModel.items) { $item in
                            _buildListRow(item: $item)
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .padding(.vertical, 6)
                        }
                        .onDelete(perform: viewModel.deleteItems)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
                .padding(.top, 10)
                .onTapGesture { dismissKeyboard() }
            }
            .navigationTitle("Shopping List")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear { animateOrbs() }
    }

    // MARK: - Add Item Bar
    @ViewBuilder
    private func _buildAddItemBar() -> some View {
        HStack(spacing: 16) {
            TextField("", text: $viewModel.newItemName, prompt:
                Text("Add new item...").foregroundColor(placeholderColor)
            )
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(cardBackgroundColor)
                    .stroke(cardBorderColor, lineWidth: 1)
            )
            .foregroundStyle(primaryTextColor)
            .submitLabel(.done)
            .onSubmit(viewModel.addItem)

            Button(action: viewModel.addItem) {
                Image(systemName: "plus.circle.fill")
                    .font(.title)
                    .foregroundStyle(Color("AppSecondaryAccent"))
            }
            .disabled(viewModel.newItemName.isEmpty)
        }
    }
    
    // MARK: - List Row
    @ViewBuilder
    private func _buildListRow(item: Binding<ShoppingItem>) -> some View {
        HStack(spacing: 16) {
            Image(systemName: item.wrappedValue.isCompleted ? "checkmark.square.fill" : "square")
                .font(.title3)
                .foregroundStyle(item.wrappedValue.isCompleted ? Color("AppSecondaryAccent") : secondaryTextColor)
                .onTapGesture {
                    viewModel.toggleCompletion(for: item.wrappedValue)
                }

            Text(item.wrappedValue.name)
                .foregroundStyle(item.wrappedValue.isCompleted ? tertiaryTextColor : primaryTextColor)
                .strikethrough(item.wrappedValue.isCompleted, color: secondaryTextColor)

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

#Preview {
    ShoppingListView()
        .environmentObject(ShoppingListViewModel())
}
