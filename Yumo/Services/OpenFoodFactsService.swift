// Services/OpenFoodFactsService.swift

import Foundation

// A simple enum for our specific networking errors
enum NetworkError: Error, LocalizedError {
    case invalidURL
    case productNotFound
    case decodingError(String)
    case serverError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: "The URL was invalid."
        case .productNotFound: "No product was found."
        case .decodingError(let msg): "Failed to decode product: \(msg)"
        case .serverError(let msg): "Server error: \(msg)"
        }
    }
}

class OpenFoodFactsService {
    
    private let barcodeBaseURL = "https://world.openfoodfacts.org/api/v2/product"
    private let searchBaseURL = "https://world.openfoodfacts.org/cgi/search.pl"
    
    /// Fetches a single product by its barcode
    func fetchFoodByBarcode(_ barcode: String) async throws -> OFFProduct {
        // 1. Construct the URL
        guard let url = URL(string: "\(barcodeBaseURL)/\(barcode)") else {
            throw NetworkError.invalidURL
        }
        
        // 2. Perform the async network call
        let (data, _) = try await URLSession.shared.data(from: url)
        
        // 3. Decode the JSON response
        do {
            let decoder = JSONDecoder()
            let response = try decoder.decode(OFFResponse.self, from: data)
            
            // 4. Check the response status
            if response.status == 1, let product = response.product {
                return product
            } else {
                throw NetworkError.productNotFound
            }
        } catch (let error) {
            throw NetworkError.decodingError(error.localizedDescription)
        }
    }
    
    // ⭐️ 1. ADDED 'page' PARAMETER
    /// Searches for products by a name or search term
    func searchFoodByName(_ searchTerm: String, page: Int) async throws -> [OFFProduct] {
        
        // 1. Create URL Components
        guard var components = URLComponents(string: searchBaseURL) else {
            throw NetworkError.invalidURL
        }
        
        // 2. Add query parameters for the search.pl endpoint
        components.queryItems = [
            URLQueryItem(name: "search_terms", value: searchTerm),
            URLQueryItem(name: "search_simple", value: "1"),
            URLQueryItem(name: "json", value: "1"),
            URLQueryItem(name: "page_size", value: "25"),
            URLQueryItem(name: "sort_by", value: "unique_scans_n"),
            // ⭐️ 2. ADDED PAGE TO API CALL
            URLQueryItem(name: "page", value: String(page))
        ]
        
        guard let url = components.url else {
            throw NetworkError.invalidURL
        }
        
        // 3. Perform network call
        let (data, _) = try await URLSession.shared.data(from: url)
        
        // 4. Decode using the OFFSearchResponse struct
        do {
            let decoder = JSONDecoder()
            let response = try decoder.decode(OFFSearchResponse.self, from: data)
            
            // 5. Check response
            if response.count > 0 {
                let validProducts = response.products.filter { $0.nutriments != nil }
                return validProducts
            } else {
                // If we are on page 1 and get no results, it's an error
                if page == 1 {
                    throw NetworkError.productNotFound
                } else {
                    // If we are on page 2+ and get no results,
                    // it just means we've reached the end.
                    return []
                }
            }
        } catch (let error) {
            throw NetworkError.decodingError(error.localizedDescription)
        }
    }
}
