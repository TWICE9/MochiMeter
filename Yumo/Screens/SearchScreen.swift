// Screens/SearchScreen.swift

import SwiftUI
import SwiftData

// MARK: - Unified Search Result Type
enum SearchResult: Identifiable {
    case commonFood(CommonFood)
    case masterFood(MasterFoodRow)
    case usdaFood(USDAFoodRow)
    case apiProduct(OFFProduct)

    var id: String {
        switch self {
        case .commonFood(let food): return "common-\(food.id)"
        case .masterFood(let food): return "master-\(food.barcode)"
        case .usdaFood(let food): return "usda-\(food.id)"
        case .apiProduct(let product): return "api-\(product.id)"
        }
    }

    /// Unique key for deduplication (normalized name + calories)
    var dedupeKey: String {
        let name = displayName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let cals = Int(calories)
        return "\(name)-\(cals)"
    }

    var displayName: String {
        switch self {
        case .commonFood(let food): return food.name
        case .masterFood(let food): return food.foodName
        case .usdaFood(let food): return food.foodName
        case .apiProduct(let product): return product.productName ?? "Unknown"
        }
    }

    var calories: Double {
        switch self {
        case .commonFood(let food): return food.caloriesPerServing
        case .masterFood(let food): return food.caloriesPerServing
        case .usdaFood(let food): return food.caloriesPerServing
        case .apiProduct(let product): return product.nutriments?.servingCalories ?? 0
        }
    }

    /// Source priority (lower = higher priority): MasterFood > CommonFood > USDA > API
    var sourcePriority: Int {
        switch self {
        case .masterFood: return 0  // Community data - most relevant
        case .commonFood: return 1  // Local cache
        case .usdaFood: return 2    // USDA database
        case .apiProduct: return 3  // OpenFoodFacts API
        }
    }
}

// Simple shimmer overlay for skeletons
private struct ShimmerView: View {
    @State private var move: CGFloat = -1.1

    var body: some View {
        GeometryReader { geo in
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.white.opacity(0.05),
                    Color.white.opacity(0.35),
                    Color.white.opacity(0.05)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(width: geo.size.width * 1.6, height: geo.size.height * 1.4)
            .offset(x: move * geo.size.width)
            .onAppear {
                withAnimation(.linear(duration: 1.15).repeatForever(autoreverses: false)) {
                    move = 1.3
                }
            }
        }
    }
}

struct SearchScreen: View {

    private let apiService: OpenFoodFactsService
    private let supabaseService: SupabaseService
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme

    @EnvironmentObject private var tabRouter: TabRouter

    @Query private var allCommonFoods: [CommonFood]

    @State private var recentScans: [LoggedFood] = []
    @State private var recentLoggedFoods: [LoggedFood] = []
    @State private var searchResults: [SearchResult] = []
    @State private var searchText = ""
    @FocusState private var searchFocused: Bool
    @State private var isLoadingSupabase = false
    @State private var isLoadingUSDA = false
    @State private var isLoadingAPI = false
    @State private var errorMessage: String?

    @State private var searchTask: Task<Void, Error>?
    @State private var recentSearches: [String] = []
    @State private var page: Int = 1
    @State private var offset1: CGSize = .zero
    @State private var offset2: CGSize = .zero

    init() {
        self.apiService = OpenFoodFactsService()
        self.supabaseService = SupabaseService()
    }

    private var isLoading: Bool {
        isLoadingSupabase || isLoadingUSDA || isLoadingAPI
    }

    // Adaptive colors for light/dark mode
    private var adaptiveTextColor: Color {
        colorScheme == .light ? Color(red: 0.1, green: 0.1, blue: 0.1) : .white
    }

    private var adaptiveSecondaryTextColor: Color {
        colorScheme == .light ? Color(red: 0.3, green: 0.3, blue: 0.3) : .white.opacity(0.7)
    }
    
    var body: some View {
        ZStack {
            _buildDynamicBackground()
            ScrollView {
                VStack(spacing: 18) {

                    // Search Card
                    borderlessCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Search")
                                .font(.headline).foregroundStyle(adaptiveTextColor)
                            HStack(spacing: 10) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundStyle(.gray)
                                TextField("Search by food or brand name...", text: $searchText)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled(true)
                                    .foregroundStyle(adaptiveTextColor)
                                    .focused($searchFocused)
                                if !searchText.isEmpty {
                                    Button(action: { clearSearch() }) {
                                        Image(systemName: "xmark.circle.fill").foregroundStyle(.gray)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
                    .padding(.horizontal, 24)

                    // Quick actions row
                    HStack(spacing: 12) {
                        NavigationLink(value: HomeDestination.recipes) {
                            quickAction(
                                icon: "square.and.pencil",
                                title: "Recipes",
                                subtitle: "Create or edit",
                                accent: Color("AppPrimaryAccent")
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 24)

                    // Results Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Results")
                            .font(.headline)
                            .foregroundStyle(adaptiveTextColor)

                        let trimmedSearch = searchText.trimmingCharacters(in: .whitespaces)
                        let isTooShort = !trimmedSearch.isEmpty && trimmedSearch.count < minimumSearchLength
                        // Show skeletons only when actively searching AND no results yet
                        let showSkeletons = !searchText.isEmpty && !isTooShort && searchResults.isEmpty && searchTask != nil

                        if searchText.isEmpty {
                            _buildRecentScansList()
                            _buildRecentLoggedList()
                            _buildRecentSearches()
                        } else if isTooShort {
                            // Show hint for short queries
                            borderlessCard {
                                HStack {
                                    Image(systemName: "character.cursor.ibeam")
                                        .foregroundStyle(adaptiveSecondaryTextColor)
                                    Text("Type at least \(minimumSearchLength) characters to search")
                                        .font(.subheadline)
                                        .foregroundStyle(adaptiveSecondaryTextColor)
                                    Spacer()
                                }
                            }
                        } else {
                            if showSkeletons {
                                VStack(spacing: 10) {
                                    ForEach(0..<4, id: \.self) { _ in
                                        skeletonRow()
                                    }
                                }
                            } else if !searchResults.isEmpty {
                                LazyVStack(spacing: 12) {
                                    ForEach(searchResults) { result in
                                        _buildSearchResultRow(result: result)
                                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                                    }
                                }
                                .animation(.easeInOut(duration: 0.25), value: searchResults.count)
                            }

                            if let errorMessage {
                                Text(errorMessage).foregroundStyle(.red).padding(.top, 8)
                            } else if searchResults.isEmpty && !showSkeletons {
                                borderlessCard {
                                    VStack(spacing: 8) {
                                        Image(systemName: "magnifyingglass")
                                            .font(.largeTitle)
                                            .foregroundStyle(adaptiveSecondaryTextColor.opacity(0.5))
                                        Text("No results found for \"\(searchText)\"")
                                            .foregroundStyle(adaptiveSecondaryTextColor)
                                        Text("Try a different search term")
                                            .font(.caption)
                                            .foregroundStyle(adaptiveSecondaryTextColor.opacity(0.7))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 20)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)

                    Spacer(minLength: 40)
                }
            }
            .scrollIndicators(.hidden)
            .scrollContentBackground(.hidden)
            .dismissKeyboardOnTap()
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                loadRecentSearches()
                await refreshRecentScans()
                // Focus search on appear
                await MainActor.run {
                    searchFocused = true
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    Task { await refreshRecentScans() }
                }
            }
            .onChange(of: searchText) { _, newSearchText in
                if newSearchText.isEmpty { clearSearch(); return }

                // Don't search for very short queries
                let trimmed = newSearchText.trimmingCharacters(in: .whitespaces)
                guard trimmed.count >= minimumSearchLength else {
                    searchResults = []
                    searchTask = nil
                    return
                }

                // DON'T clear results here - keep showing old results until new ones arrive
                self.page = 1
                errorMessage = nil

                searchTask?.cancel()

                // Capture search term at creation time to avoid race conditions
                // Normalize slang terms (e.g., "maccas" → "McDonald's")
                let capturedTerm = normalizeFoodSlang(trimmed)

                // Store the original trimmed term for comparison
                let originalTrimmed = trimmed

                searchTask = Task {
                    // Debounce - wait for user to stop typing
                    try await Task.sleep(nanoseconds: 150_000_000)

                    // Verify search term is still current after debounce (compare original, not normalized)
                    guard !Task.isCancelled, originalTrimmed == searchText.trimmingCharacters(in: .whitespaces) else {
                        return
                    }

                    // Capture common foods before entering task group
                    let commonFoods = allCommonFoods

                    // Collect all results from all sources
                    var allResults: [SearchResult] = []

                    // Phase 1: Search local + Supabase + USDA in parallel
                    await withTaskGroup(of: [SearchResult].self) { group in
                        // Local CommonFood search with better matching
                        group.addTask {
                            let normalizedSearch = self.normalizeSearchString(capturedTerm)


                            let filtered = commonFoods.filter { food in
                                let normalizedName = self.normalizeSearchString(food.name)

                                // ENFORCED STRICT 95% ACCURACY
                                // Only return cached items if they match the query with >= 95% similarity
                                let similarity = self.calculateSimilarity(normalizedName, normalizedSearch)
                                return similarity >= 0.95
                            }
                            return Array(filtered.prefix(30)).map { .commonFood($0) }
                        }

                        group.addTask {
                            await self.performSupabaseSearch(for: capturedTerm)
                        }

                        group.addTask {
                            await self.performUSDASearch(for: capturedTerm)
                        }

                        for await results in group {
                            allResults.append(contentsOf: results)
                        }
                    }

                    // Check if still valid before updating UI
                    guard !Task.isCancelled, originalTrimmed == searchText.trimmingCharacters(in: .whitespaces) else {
                        return
                    }

                    // Update UI with local/Supabase/USDA results (processed and sorted)
                    let processedLocal = processResults(allResults, query: capturedTerm)
                    await MainActor.run {
                        searchResults = processedLocal
                    }

                    // Phase 2: API search (slightly delayed)
                    guard !Task.isCancelled, originalTrimmed == searchText.trimmingCharacters(in: .whitespaces) else {
                        await MainActor.run { searchTask = nil }
                        return
                    }

                    // Short delay before API call
                    try await Task.sleep(nanoseconds: 200_000_000)

                    guard !Task.isCancelled, originalTrimmed == searchText.trimmingCharacters(in: .whitespaces) else {
                        await MainActor.run { searchTask = nil }
                        return
                    }

                    // Fetch API results
                    do {
                        let products = try await apiService.searchFoodByName(capturedTerm, page: 1)

                        guard !Task.isCancelled, originalTrimmed == searchText.trimmingCharacters(in: .whitespaces) else {
                            await MainActor.run { searchTask = nil }
                            return
                        }

                        let apiResults = products.map { SearchResult.apiProduct($0) }

                        // Combine with existing results and re-process
                        await MainActor.run {
                            var combined = searchResults
                            combined.append(contentsOf: apiResults)
                            searchResults = processResults(combined, query: capturedTerm)
                            if !products.isEmpty { addRecentSearch(capturedTerm) }
                            searchTask = nil
                        }
                    } catch {
                        // API failed, but we still have local results
                        await MainActor.run {
                            searchTask = nil
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Functions

    private func refreshRecentScans() async {
        let userId = await UserSession.shared.getCurrentUserId()

        // Use simple predicate (just userId) to avoid compiler timeout
        // Then filter for barcode and recipe in Swift code
        let descriptor: FetchDescriptor<LoggedFood>

        if let userId = userId {
            // User is signed in - filter by userId only
            let predicate = #Predicate<LoggedFood> { food in
                food.userId == userId
            }
            descriptor = FetchDescriptor(
                predicate: predicate,
                sortBy: [SortDescriptor(\LoggedFood.timestamp, order: .reverse)]
            )
        } else {
            // User is offline - filter by nil userId only
            let predicate = #Predicate<LoggedFood> { food in
                food.userId == nil
            }
            descriptor = FetchDescriptor(
                predicate: predicate,
                sortBy: [SortDescriptor(\LoggedFood.timestamp, order: .reverse)]
            )
        }

        let allLogs = (try? modelContext.fetch(descriptor)) ?? []

        // Filter in Swift: only scanned items (has barcode, not a recipe ingredient)
        let scannedLogs = allLogs.filter { $0.barcode != nil && $0.recipe == nil }

        // Filter to unique barcodes, limit to 5
        var uniqueLogs: [LoggedFood] = []
        var seenBarcodes: Set<String> = []
        for log in scannedLogs {
            if let barcode = log.barcode, !seenBarcodes.contains(barcode) {
                uniqueLogs.append(log)
                seenBarcodes.insert(barcode)
            }
            if uniqueLogs.count >= 5 { break }
        }

        recentScans = uniqueLogs
        recentLoggedFoods = Array(allLogs.prefix(5))
    }

    // MARK: - Search Helpers

    /// Minimum characters required to trigger search
    private let minimumSearchLength = 2

    /// Normalize search strings for flexible matching
    nonisolated private func normalizeSearchString(_ text: String) -> String {
        return text.replacingOccurrences(of: "&", with: "and")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespaces)
            .lowercased()
    }

    /// Normalize slang terms and abbreviations to proper brand names
    private func normalizeFoodSlang(_ input: String) -> String {
        // Dictionary of slang -> proper name (case-insensitive matching)
        let slangMap: [String: String] = [
            // Australian slang
            "maccas": "McDonald's",
            "macca's": "McDonald's",
            "maccies": "McDonald's",
            "macca": "McDonald's",
            "macc": "McDonald's",
            "hungry jacks": "Burger King",
            "hj's": "Hungry Jack's",
            "kfc": "KFC",
            "chook": "chicken",
            "brekkie": "breakfast",

            // Common abbreviations
            "bk": "Burger King",
            "mcd": "McDonald's",
            "mcds": "McDonald's",
            "sbux": "Starbucks",
            "dq": "Dairy Queen",
            "tb": "Taco Bell",
            "cfa": "Chick-fil-A",
            "wendys": "Wendy's",
            "popeyes": "Popeyes",

            // UK slang
            "nandos": "Nando's",
            "greggs": "Greggs",
            "spoons": "Wetherspoons",

            // Common misspellings
            "mcdonalds": "McDonald's",
            "starbucks": "Starbucks",
            "chipotle": "Chipotle"
        ]

        var result = input

        // Replace slang terms (case-insensitive, whole word matching)
        for (slang, proper) in slangMap {
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: slang))\\b"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                result = regex.stringByReplacingMatches(
                    in: result,
                    options: [],
                    range: NSRange(result.startIndex..., in: result),
                    withTemplate: proper
                )
            }
        }

        return result
    }

    /// Get search variations (original and with and/& swapped)
    private func getSearchVariations(_ text: String) -> [String] {
        var variations = [text]

        if text.lowercased().contains(" and ") {
            let withAmpersand = text.replacingOccurrences(of: " and ", with: " & ", options: .caseInsensitive)
            variations.append(withAmpersand)
        }

        if text.contains("&") {
            let withAnd = text.replacingOccurrences(of: "&", with: "and")
                .replacingOccurrences(of: "  ", with: " ")
                .trimmingCharacters(in: .whitespaces)
            variations.append(withAnd)
        }

        return variations
    }

    /// Calculate relevance score for a result (higher = better match)
    nonisolated private func calculateRelevanceScore(name: String, query: String) -> Int {
        let normalizedName = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedQuery = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Exact match = highest score
        if normalizedName == normalizedQuery {
            return 1000
        }

        // Name starts with query = very high score
        if normalizedName.hasPrefix(normalizedQuery) {
            return 900
        }

        // Query starts with name (e.g., query "chicken breast" matches "chicken")
        if normalizedQuery.hasPrefix(normalizedName) {
            return 850
        }

        var score = 0
        let queryWords = Set(normalizedQuery.split(separator: " ").map(String.init))
        let nameWords = normalizedName.split(separator: " ").map(String.init)

        // Check word-level matches
        for (index, nameWord) in nameWords.enumerated() {
            for queryWord in queryWords {
                if nameWord == queryWord {
                    // Exact word match - bonus for being earlier in the name
                    score += 100 - (index * 5)
                } else if nameWord.hasPrefix(queryWord) {
                    // Word starts with query word
                    score += 70 - (index * 3)
                } else if nameWord.contains(queryWord) {
                    // Word contains query word
                    score += 40 - (index * 2)
                }
            }
        }

        // Bonus if name contains the full query as a substring
        if normalizedName.contains(normalizedQuery) {
            score += 50
        }

        return score
    }

    /// Deduplicate and sort results by relevance
    private func processResults(_ results: [SearchResult], query: String) -> [SearchResult] {
        // Deduplicate by keeping highest priority source for each unique food
        var seenKeys: [String: SearchResult] = [:]

        for result in results {
            let key = result.dedupeKey
            if let existing = seenKeys[key] {
                // Keep the one with better source priority
                if result.sourcePriority < existing.sourcePriority {
                    seenKeys[key] = result
                }
            } else {
                seenKeys[key] = result
            }
        }

        // Sort by relevance score (descending), then by source priority
        return seenKeys.values.sorted { a, b in
            let scoreA = calculateRelevanceScore(name: a.displayName, query: query)
            let scoreB = calculateRelevanceScore(name: b.displayName, query: query)

            if scoreA != scoreB {
                return scoreA > scoreB
            }
            return a.sourcePriority < b.sourcePriority
        }
    }

    // ⭐️ NEW HELPER FUNCTION ⭐️
    private func createCleanProduct(from product: OFFProduct) -> OFFProduct {
        let nutriments = product.nutriments
        
        // 1. Create a "clean" nutriments object
        let cleanNutriments = OFFNutriments(
            calories: nutriments?.calories,
            protein: nutriments?.protein,
            carbs: nutriments?.carbs,
            fat: nutriments?.fat,
            fiber: nutriments?.fiber,
            sugars: nutriments?.sugars,
            salt: nutriments?.salt,
            potassium: nutriments?.potassium,
            caloriesServing: nutriments?.caloriesServing,
            proteinServing: nutriments?.proteinServing,
            carbsServing: nutriments?.carbsServing,
            fatServing: nutriments?.fatServing,
            fiberServing: nutriments?.fiberServing,
            sugarsServing: nutriments?.sugarsServing,
            saltServing: nutriments?.saltServing,
            potassiumServing: nutriments?.potassiumServing
        )
        
        // 2. Create the "clean" product
        return OFFProduct(
            id: product.id,
            productName: product.productName,
            brands: product.brands,
            nutriments: cleanNutriments,
            servingSize: product.servingSize,
            labelsTags: product.labelsTags
        )
    }
    
    private func cacheProductIfNeeded(_ product: OFFProduct) {
        let code = product.id
        do {
            let predicate = #Predicate<CommonFood> { $0.barcode == code }
            let descriptor = FetchDescriptor<CommonFood>(predicate: predicate)
            if try modelContext.fetch(descriptor).first != nil { return }

            let nutriments = product.nutriments ?? OFFNutriments.empty

            let newCacheItem = CommonFood(
                name: product.productName ?? "Unknown Product",
                barcode: code,
                caloriesPerServing: nutriments.servingCalories,
                proteinPerServing: nutriments.servingProtein,
                carbsPerServing: nutriments.servingCarbs,
                fatPerServing: nutriments.servingFat,
                fiberPerServing: nutriments.servingFiber,
                sugarPerServing: nutriments.servingSugars,
                saltPerServing: nutriments.servingSalt,
                potassiumPerServing: nutriments.servingPotassium, // This is already in MG
                servingSizeDescription: product.servingSize ?? "1 serving",
                isHalal: product.isHalal
            )
            modelContext.insert(newCacheItem)
        } catch {
            print("Failed to check or save to cache: \(error.localizedDescription)")
        }
    }

    private func cacheMasterFoodIfNeeded(_ masterFood: MasterFoodRow) {
        let code = masterFood.barcode
        do {
            let predicate = #Predicate<CommonFood> { $0.barcode == code }
            let descriptor = FetchDescriptor<CommonFood>(predicate: predicate)
            if try modelContext.fetch(descriptor).first != nil { return }

            let newCacheItem = CommonFood(
                name: masterFood.foodName,
                barcode: code,
                caloriesPerServing: masterFood.caloriesPerServing,
                proteinPerServing: masterFood.proteinPerServing,
                carbsPerServing: masterFood.carbsPerServing,
                fatPerServing: masterFood.fatPerServing,
                fiberPerServing: masterFood.fiberPerServing,
                sugarPerServing: masterFood.sugarPerServing,
                saltPerServing: masterFood.saltPerServing,
                potassiumPerServing: masterFood.potassiumPerServing,
                servingSizeDescription: masterFood.servingSizeDescription,
                isHalal: masterFood.isHalal
            )
            modelContext.insert(newCacheItem)
        } catch {
            print("Failed to cache master food: \(error.localizedDescription)")
        }
    }

    private func cacheUSDAFoodIfNeeded(_ usdaFood: USDAFoodRow) {
        // Check if already cached by name (since USDA foods don't have barcodes)
        do {
            let name = usdaFood.foodName
            let predicate = #Predicate<CommonFood> { $0.name == name && $0.barcode == nil }
            let descriptor = FetchDescriptor<CommonFood>(predicate: predicate)
            if try modelContext.fetch(descriptor).first != nil { return }

            let newCacheItem = CommonFood(
                name: usdaFood.foodName,
                barcode: nil, // No barcode for USDA foods
                caloriesPerServing: usdaFood.caloriesPerServing,
                proteinPerServing: usdaFood.proteinPerServing,
                carbsPerServing: usdaFood.carbsPerServing,
                fatPerServing: usdaFood.fatPerServing,
                fiberPerServing: usdaFood.fiberPerServing,
                sugarPerServing: usdaFood.sugarPerServing,
                saltPerServing: usdaFood.saltPerServing,
                potassiumPerServing: usdaFood.potassiumPerServing,
                servingSizeDescription: usdaFood.servingSizeDescription,
                isHalal: usdaFood.isHalal
            )
            modelContext.insert(newCacheItem)
        } catch {
            print("Failed to cache USDA food: \(error.localizedDescription)")
        }
    }


    private func clearSearch() {
        searchText = ""
        searchResults = []
        errorMessage = nil
        searchTask?.cancel()
        searchTask = nil
        self.page = 1
    }

    private func performSupabaseSearch(for term: String) async -> [SearchResult] {
        guard !term.isEmpty, !Task.isCancelled else {
            await MainActor.run { isLoadingSupabase = false }
            return []
        }

        await MainActor.run { isLoadingSupabase = true }

        do {
            // Search for all variations (original, with &, with 'and')
            let variations = getSearchVariations(term)
            var allResults: [MasterFoodRow] = []
            var seenBarcodes = Set<String>()

            for searchTerm in variations {
                guard !Task.isCancelled else { break }
                let results = try await supabaseService.searchFoodsByName(searchTerm, limit: 25)
                // Deduplicate by barcode
                for food in results {
                    if !seenBarcodes.contains(food.barcode) {
                        allResults.append(food)
                        seenBarcodes.insert(food.barcode)
                    }
                }
            }

            await MainActor.run { isLoadingSupabase = false }
            guard !Task.isCancelled else { return [] }
            return Array(allResults.prefix(25)).map { .masterFood($0) }
        } catch {
            print("Supabase search failed: \(error.localizedDescription)")
            await MainActor.run { isLoadingSupabase = false }
            return []
        }
    }

    private func performUSDASearch(for term: String) async -> [SearchResult] {
        guard !term.isEmpty, !Task.isCancelled else {
            await MainActor.run { isLoadingUSDA = false }
            return []
        }

        await MainActor.run { isLoadingUSDA = true }

        do {
            // Search for all variations (original, with &, with 'and')
            let variations = getSearchVariations(term)
            var allResults: [USDAFoodRow] = []
            var seenNames = Set<String>()

            for searchTerm in variations {
                guard !Task.isCancelled else { break }
                let results = try await supabaseService.searchUSDAFoodsByName(searchTerm, limit: 25)
                // Deduplicate by food name
                for food in results {
                    if !seenNames.contains(food.foodName) {
                        allResults.append(food)
                        seenNames.insert(food.foodName)
                    }
                }
            }

            await MainActor.run { isLoadingUSDA = false }
            guard !Task.isCancelled else { return [] }
            return Array(allResults.prefix(25)).map { .usdaFood($0) }
        } catch {
            print("USDA search failed: \(error.localizedDescription)")
            await MainActor.run { isLoadingUSDA = false }
            return []
        }
    }

    private func performAPISearch(for term: String) async {
        guard !term.isEmpty, !Task.isCancelled else {
            await MainActor.run { isLoadingAPI = false }
            return
        }

        await MainActor.run { isLoadingAPI = true }

        do {
            let products = try await apiService.searchFoodByName(term, page: self.page)

            guard !Task.isCancelled else {
                await MainActor.run { isLoadingAPI = false }
                return
            }

            await MainActor.run {
                let apiResults = products.map { SearchResult.apiProduct($0) }
                searchResults.append(contentsOf: apiResults)
                if !products.isEmpty && self.page == 1 { addRecentSearch(term) }
                isLoadingAPI = false
            }
        } catch let error as NetworkError {
            await MainActor.run {
                if error.localizedDescription != "No product was found." {
                    errorMessage = error.localizedDescription
                }
                isLoadingAPI = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "An unexpected error occurred."
                isLoadingAPI = false
            }
        }
    }
    
    private func loadMoreResults() {
        guard !isLoading && !searchText.isEmpty else { return }
        let currentQuery = searchText.trimmingCharacters(in: .whitespaces)
        self.page += 1
        isLoadingAPI = true

        Task {
            do {
                let products = try await apiService.searchFoodByName(currentQuery, page: self.page)
                let apiResults = products.map { SearchResult.apiProduct($0) }

                await MainActor.run {
                    // Append and re-process to dedupe
                    var combined = searchResults
                    combined.append(contentsOf: apiResults)
                    searchResults = processResults(combined, query: currentQuery)
                    isLoadingAPI = false
                }
            } catch {
                print("Failed to load more results: \(error.localizedDescription)")
                await MainActor.run {
                    isLoadingAPI = false
                }
            }
        }
    }
    private func addRecentSearch(_ term: String) { /* ... */ }
    private func saveRecentSearches() { /* ... */ }
    private func loadRecentSearches() { /* ... */ }

    // MARK: - View Builders
    
    private let cardCornerRadius: CGFloat = 18
    
    private func cardBackground() -> some View {
        let lightFill = Color.black.opacity(0.04)
        let darkFill = Color.white.opacity(0.06)
        return RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
            .fill(colorScheme == .light ? lightFill : darkFill)
    }
    
    private func borderlessCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(16)
            .background(cardBackground())
    }

    private func skeletonRow() -> some View {
        let thumb = RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color.white.opacity(0.14))
            .frame(width: 52, height: 52)

        let lines = VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.white.opacity(0.12))
                .frame(width: 150, height: 10)
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.white.opacity(0.12))
                .frame(width: 110, height: 9)
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.white.opacity(0.12))
                .frame(width: 80, height: 9)
        }

        let content = HStack(spacing: 12) {
            thumb
            lines
            Spacer()
        }

        return content
            .padding(12)
            .background(cardBackground())
            .overlay(
                ShimmerView()
                    .mask(content.padding(12))
            )
    }
    
    private func quickAction(icon: String, title: String, subtitle: String, accent: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(accent)
                .frame(width: 40, height: 40)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(adaptiveTextColor)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(adaptiveSecondaryTextColor)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(adaptiveSecondaryTextColor)
        }
        .padding(16)
        .background(cardBackground())
    }
    
    @ViewBuilder
    private func _buildRecentScansList() -> some View {
        if !recentScans.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Recently Scanned").font(.headline).foregroundStyle(adaptiveTextColor).frame(maxWidth: .infinity, alignment: .leading)
                LazyVStack(spacing: 12) {
                    ForEach(recentScans) { log in
                        NavigationLink(value: HomeDestination.logProduct(log.toOFFProduct())) {
                            _buildCommonFoodRow(
                                food: CommonFood(
                                    name: log.name,
                                    barcode: log.barcode,
                                    caloriesPerServing: log.caloriesPerServing,
                                    proteinPerServing: log.proteinPerServing,
                                    carbsPerServing: log.carbsPerServing,
                                    fatPerServing: log.fatPerServing,
                                    fiberPerServing: log.fiberPerServing,
                                    sugarPerServing: log.sugarPerServing,
                                    saltPerServing: log.saltPerServing,
                                    potassiumPerServing: log.potassiumPerServing,
                                    servingSizeDescription: log.servingSizeDescription,
                                    isHalal: log.isHalal
                                )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func _buildRecentLoggedList() -> some View {
        if !recentLoggedFoods.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Recently Logged").font(.headline).foregroundStyle(adaptiveTextColor).frame(maxWidth: .infinity, alignment: .leading)
                LazyVStack(spacing: 12) {
                    ForEach(recentLoggedFoods) { log in
                        NavigationLink(value: HomeDestination.logProduct(log.toOFFProduct())) {
                            _buildCommonFoodRow(food: CommonFood.fromLoggedFood(log))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func _buildAPIResultRow(product: OFFProduct) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(product.productName ?? "Unknown Product").font(.headline).foregroundStyle(adaptiveTextColor).lineLimit(1)
                Text(product.servingSize ?? "1 serving").font(.caption).foregroundStyle(adaptiveSecondaryTextColor)
            }
            Spacer()
            if product.isHalal {
                Text("✅").font(.caption).padding(5).background(.green.opacity(0.2)).clipShape(Circle())
            }

            let nutriments = product.nutriments ?? OFFNutriments.empty
            Text("\(nutriments.servingCalories, specifier: "%.0f") kcal")
                .font(.callout).bold()
                .foregroundStyle(Color("AppSecondaryAccent"))
        }
        .padding().background(cardBackground())
    }

    @ViewBuilder
    private func _buildCommonFoodRow(food: CommonFood) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(food.name).font(.headline).foregroundStyle(adaptiveTextColor)
                Text(food.servingSizeDescription).font(.caption).foregroundStyle(adaptiveSecondaryTextColor)
            }
            Spacer()
            if food.isHalal {
                Text("✅").font(.caption).padding(5).background(.green.opacity(0.2)).clipShape(Circle())
            }
            Text("\(food.caloriesPerServing, specifier: "%.0f") kcal").font(.callout).bold().foregroundStyle(Color("AppSecondaryAccent"))
            }
        .padding().background(cardBackground())
    }

    @ViewBuilder
    private func _buildMasterFoodRow(masterFood: MasterFoodRow) -> some View {
        HStack {
            VStack(alignment: .leading) {
                HStack(spacing: 6) {
                    Text(masterFood.foodName).font(.headline).foregroundStyle(adaptiveTextColor).lineLimit(1)
                    // Badge to show it's from community database
                    Text("🌐").font(.caption2)
                }
                HStack(spacing: 8) {
                    Text(masterFood.servingSizeDescription).font(.caption).foregroundStyle(adaptiveSecondaryTextColor)
                    if masterFood.scanCount > 1 {
                        Text("• \(masterFood.scanCount) scans").font(.caption2).foregroundStyle(adaptiveSecondaryTextColor)
                    }
                }
            }
            Spacer()
            if masterFood.isHalal {
                Text("✅").font(.caption).padding(5).background(.green.opacity(0.2)).clipShape(Circle())
            }
            Text("\(masterFood.caloriesPerServing, specifier: "%.0f") kcal").font(.callout).bold().foregroundStyle(Color("AppSecondaryAccent"))
        }
        .padding().background(cardBackground())
    }

    @ViewBuilder
    private func _buildUSDAFoodRow(usdaFood: USDAFoodRow) -> some View {
        HStack {
            VStack(alignment: .leading) {
                HStack(spacing: 6) {
                    Text(usdaFood.foodName).font(.headline).foregroundStyle(adaptiveTextColor).lineLimit(1)
                    // Badge to show it's from USDA database
                    Text("🇺🇸").font(.caption2)
                }
                Text(usdaFood.servingSizeDescription).font(.caption).foregroundStyle(adaptiveSecondaryTextColor)
            }
            Spacer()
            Text("\(usdaFood.caloriesPerServing, specifier: "%.0f") kcal").font(.callout).bold().foregroundStyle(Color("AppSecondaryAccent"))
        }
        .padding().background(cardBackground())
    }

    @ViewBuilder
    private func _buildSearchResultRow(result: SearchResult) -> some View {
        switch result {
        case .commonFood(let food):
            NavigationLink(value: HomeDestination.logProduct(food.toOFFProduct())) {
                _buildCommonFoodRow(food: food)
            }
            .buttonStyle(.plain)

        case .masterFood(let masterFood):
            NavigationLink(value: HomeDestination.logProduct(masterFood.toOFFProduct())) {
                _buildMasterFoodRow(masterFood: masterFood)
            }
            .simultaneousGesture(TapGesture().onEnded {
                cacheMasterFoodIfNeeded(masterFood)
            })
            .buttonStyle(.plain)

        case .usdaFood(let usdaFood):
            NavigationLink(value: HomeDestination.logProduct(usdaFood.toOFFProduct())) {
                _buildUSDAFoodRow(usdaFood: usdaFood)
            }
            .simultaneousGesture(TapGesture().onEnded {
                cacheUSDAFoodIfNeeded(usdaFood)
            })
            .buttonStyle(.plain)

        case .apiProduct(let product):
            let cleanProduct = createCleanProduct(from: product)
            NavigationLink(value: HomeDestination.logProduct(cleanProduct)) {
                _buildAPIResultRow(product: product)
                    .onAppear {
                        // Check if this is the last item for pagination
                        if result.id == searchResults.last?.id {
                            loadMoreResults()
                        }
                    }
            }
            .simultaneousGesture(TapGesture().onEnded {
                cacheProductIfNeeded(product)
            })
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func _buildRecentSearches() -> some View {
        if !recentSearches.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Recent Searches").font(.headline).foregroundStyle(Color("AppTextPrimary")).padding(.leading, 16)
                ForEach(recentSearches, id: \.self) { term in
                    Button { searchText = term } label: {
                        HStack {
                            Image(systemName: "clock.arrow.circlepath").foregroundStyle(Color("AppTextPrimary").opacity(0.7))
                            Text(term).font(.body).foregroundStyle(Color("AppTextPrimary"))
                            Spacer()
                        }
                        .padding().background(cardBackground())
                    }
                    .buttonStyle(.plain)
                }
            }
        } else {
            if recentScans.isEmpty {
                Text("Your recent searches will appear here.").foregroundStyle(Color("AppTextPrimary").opacity(0.8)).padding()
            }
        }
    }
    
    // MARK: - Background Functions
    
    @ViewBuilder
    private func _buildDynamicBackground() -> some View {
        ZStack {
            Color("AppPrimaryDark", bundle: nil).ignoresSafeArea()
            RadialGradient(gradient: Gradient(colors: [Color("AppSecondaryAccent").opacity(0.3), .clear]), center: .topLeading, startRadius: 50, endRadius: 450).offset(offset1).offset(x: -150, y: -150).ignoresSafeArea()
            RadialGradient(gradient: Gradient(colors: [Color("AppPrimaryAccent").opacity(0.4), .clear]), center: .bottomTrailing, startRadius: 100, endRadius: 500).offset(offset2).offset(x: 100, y: 150).ignoresSafeArea()
        }
        .blur(radius: 60)
        .onAppear { animateOrbs() }
    }
    
    private func animateOrbs() {
        withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) { offset1 = CGSize(width: 80, height: 60) }
        withAnimation(.easeInOut(duration: 10).repeatForever(autoreverses: true)) { offset2 = CGSize(width: -100, height: -70) }
    }
    // MARK: - Accuracy Helpers
    
    nonisolated private func calculateSimilarity(_ source: String, _ target: String) -> Double {
        if source == target { return 1.0 }
        let distance = levenshteinDist(source, target)
        let maxLength = max(source.count, target.count)
        guard maxLength > 0 else { return 1.0 }
        return 1.0 - (Double(distance) / Double(maxLength))
    }

    nonisolated private func levenshteinDist(_ s1: String, _ s2: String) -> Int {
        let empty = [Int](repeating: 0, count: s2.count)
        var last = [Int](0...s2.count)

        for (i, char1) in s1.enumerated() {
            var cur = [i + 1] + empty
            for (j, char2) in s2.enumerated() {
                cur[j + 1] = char1 == char2 ? last[j] : min(last[j], last[j + 1], cur[j]) + 1
            }
            last = cur
        }
        return last.last ?? 0
    }
}
