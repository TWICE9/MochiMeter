// Services/DatabaseSeeder.swift

import Foundation
import SwiftData

struct DatabaseSeeder {
    
    /// Checks if the database is empty and, if so, adds starter data.
    static func seedIfEmpty(context: ModelContext) {
        // 1. Check if any CommonFood items already exist
        do {
            let descriptor = FetchDescriptor<CommonFood>()
            let count = try context.fetchCount(descriptor)
            
            // If the count is greater than 0, the database is already seeded.
            guard count == 0 else {
                // print("Database already seeded.")
                return
            }
        } catch {
            print("Failed to check database: \(error.localizedDescription)")
            return
        }
        
        // 2. If we're here, the database is empty. Let's add food.
        print("Seeding database with common foods...")
        for food in starterFoods {
            context.insert(food)
        }
        
        print("Database seeding complete.")
    }
    
    /// Our list of common, raw ingredients.
    static let starterFoods: [CommonFood] = [
        
        // --- Fruits ---
        // MARK: - Fast Food: McDonald's Australia (Oct 2025)

        CommonFood(
            name: "McDonald's Big Mac",
            caloriesPerServing: 239,
            proteinPerServing: 10.0,
            carbsPerServing: 19.3,
            fatPerServing: 12.6,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "McDonald's Double Big Mac",
            caloriesPerServing: 246,
            proteinPerServing: 12.8,
            carbsPerServing: 15.4,
            fatPerServing: 13.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "McDonald's Quarter Pounder",
            caloriesPerServing: 251,
            proteinPerServing: 14.2,
            carbsPerServing: 17.5,
            fatPerServing: 12.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "McDonald's Double Quarter Pounder",
            caloriesPerServing: 256,
            proteinPerServing: 16.6,
            carbsPerServing: 10.9,
            fatPerServing: 16.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "McDonald's Cheeseburger",
            caloriesPerServing: 257,
            proteinPerServing: 12.9,
            carbsPerServing: 21.0,
            fatPerServing: 13.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "McDonald's Double Cheeseburger",
            caloriesPerServing: 259,
            proteinPerServing: 14.1,
            carbsPerServing: 18.3,
            fatPerServing: 12.4,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "McDonald's Hamburger",
            caloriesPerServing: 257,
            proteinPerServing: 11.1,
            carbsPerServing: 27.7,
            fatPerServing: 9.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "McDonald's Filet-O-Fish",
            caloriesPerServing: 241,
            proteinPerServing: 10.4,
            carbsPerServing: 24.7,
            fatPerServing: 10.4,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "McDonald's Double Filet-O-Fish",
            caloriesPerServing: 233,
            proteinPerServing: 11.6,
            carbsPerServing: 19.4,
            fatPerServing: 11.6,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "McDonald's McChicken",
            caloriesPerServing: 222,
            proteinPerServing: 8.5,
            carbsPerServing: 22.1,
            fatPerServing: 10.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "McDonald's Double McChicken",
            caloriesPerServing: 229,
            proteinPerServing: 8.4,
            carbsPerServing: 19.7,
            fatPerServing: 12.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "McDonald's McCrispy",
            caloriesPerServing: 227,
            proteinPerServing: 11.4,
            carbsPerServing: 25.9,
            fatPerServing: 12.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "McDonald's McSpicy",
            caloriesPerServing: 230,
            proteinPerServing: 12.3,
            carbsPerServing: 19.5,
            fatPerServing: 11.9,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "McDonald's Chicken 'n' Cheese",
            caloriesPerServing: 298,
            proteinPerServing: 12.1,
            carbsPerServing: 27.6,
            fatPerServing: 15.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "McDonald's Chicken McNuggets (6 pc)",
            caloriesPerServing: 216,
            proteinPerServing: 12.1,
            carbsPerServing: 12.4,
            fatPerServing: 13.0,
            servingSizeDescription: "6 piece"
        ),
        CommonFood(
            name: "McDonald's Chicken McNuggets (10 pc)",
            caloriesPerServing: 360,
            proteinPerServing: 20.1,
            carbsPerServing: 20.6,
            fatPerServing: 21.7,
            servingSizeDescription: "10 piece"
        ),
        CommonFood(
            name: "McDonald's Fries (Medium)",
            caloriesPerServing: 304,
            proteinPerServing: 4.1,
            carbsPerServing: 33.8,
            fatPerServing: 16.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "McDonald's Hash Brown",
            caloriesPerServing: 259,
            proteinPerServing: 2.5,
            carbsPerServing: 22.4,
            fatPerServing: 17.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "McDonald's Bacon & Egg McMuffin",
            caloriesPerServing: 216,
            proteinPerServing: 12.9,
            carbsPerServing: 18.8,
            fatPerServing: 9.7,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "McDonald's Sausage & Egg McMuffin",
            caloriesPerServing: 234,
            proteinPerServing: 13.8,
            carbsPerServing: 15.9,
            fatPerServing: 12.4,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "McDonald's Hotcakes (with Butter & Syrup)",
            caloriesPerServing: 267,
            proteinPerServing: 4.2,
            carbsPerServing: 42.9,
            fatPerServing: 8.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Apple",
            caloriesPerServing: 52,
            proteinPerServing: 0.3,
            carbsPerServing: 13.8,
            fatPerServing: 0.2,
            servingSizeDescription: "100g"
        ),
       
        CommonFood(
            name: "Banana",
            caloriesPerServing: 89,
            proteinPerServing: 1.1,
            carbsPerServing: 22.8,
            fatPerServing: 0.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Strawberries",
            caloriesPerServing: 32,
            proteinPerServing: 0.7,
            carbsPerServing: 7.7,
            fatPerServing: 0.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Blueberries",
            caloriesPerServing: 57,
            proteinPerServing: 0.7,
            carbsPerServing: 14.5,
            fatPerServing: 0.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Avocado",
            caloriesPerServing: 160,
            proteinPerServing: 2,
            carbsPerServing: 8.5,
            fatPerServing: 14.7,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Orange",
            caloriesPerServing: 47,
            proteinPerServing: 0.9,
            carbsPerServing: 11.8,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Grapes (Red/Green)",
            caloriesPerServing: 69,
            proteinPerServing: 0.7,
            carbsPerServing: 18.1,
            fatPerServing: 0.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Watermelon",
            caloriesPerServing: 30,
            proteinPerServing: 0.6,
            carbsPerServing: 7.6,
            fatPerServing: 0.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Pineapple",
            caloriesPerServing: 50,
            proteinPerServing: 0.5,
            carbsPerServing: 13.1,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),

        // --- Vegetables ---
        CommonFood(
            name: "Broccoli",
            caloriesPerServing: 34,
            proteinPerServing: 2.8,
            carbsPerServing: 6.6,
            fatPerServing: 0.4,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Spinach (Raw)",
            caloriesPerServing: 23,
            proteinPerServing: 2.9,
            carbsPerServing: 3.6,
            fatPerServing: 0.4,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Carrot (Raw)",
            caloriesPerServing: 41,
            proteinPerServing: 0.9,
            carbsPerServing: 9.6,
            fatPerServing: 0.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Sweet Potato (Cooked)",
            caloriesPerServing: 90,
            proteinPerServing: 2.0,
            carbsPerServing: 20.7,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "White Potato (Cooked)",
            caloriesPerServing: 87,
            proteinPerServing: 1.9,
            carbsPerServing: 20.1,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Cucumber",
            caloriesPerServing: 15,
            proteinPerServing: 0.7,
            carbsPerServing: 3.6,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Bell Pepper (Red)",
            caloriesPerServing: 31,
            proteinPerServing: 1.0,
            carbsPerServing: 6.0,
            fatPerServing: 0.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Tomato",
            caloriesPerServing: 18,
            proteinPerServing: 0.9,
            carbsPerServing: 3.9,
            fatPerServing: 0.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Onion",
            caloriesPerServing: 40,
            proteinPerServing: 1.1,
            carbsPerServing: 9.3,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Lettuce (Iceberg)",
            caloriesPerServing: 14,
            proteinPerServing: 0.9,
            carbsPerServing: 3.0,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),

        // --- Proteins (Cooked) ---
        CommonFood(
            name: "Chicken Breast (Cooked)",
            caloriesPerServing: 165,
            proteinPerServing: 31,
            carbsPerServing: 0,
            fatPerServing: 3.6,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Chicken Thigh (Cooked)",
            caloriesPerServing: 209,
            proteinPerServing: 26,
            carbsPerServing: 0,
            fatPerServing: 10.9,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Salmon (Cooked)",
            caloriesPerServing: 206,
            proteinPerServing: 22.1,
            carbsPerServing: 0,
            fatPerServing: 12.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Tuna (Canned, in water)",
            caloriesPerServing: 116,
            proteinPerServing: 25.5,
            carbsPerServing: 0,
            fatPerServing: 0.8,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Ground Beef 90/10 (Cooked)",
            caloriesPerServing: 217,
            proteinPerServing: 26.1,
            carbsPerServing: 0,
            fatPerServing: 11.8,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Ground Turkey 93/7 (Cooked)",
            caloriesPerServing: 176,
            proteinPerServing: 27.5,
            carbsPerServing: 0,
            fatPerServing: 7.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Egg (Large, Boiled)",
            caloriesPerServing: 78,
            proteinPerServing: 6.3,
            carbsPerServing: 0.6,
            fatPerServing: 5.3,
            servingSizeDescription: "1 large (50g)"
        ),
        CommonFood(
            name: "Egg White (Large)",
            caloriesPerServing: 17,
            proteinPerServing: 3.6,
            carbsPerServing: 0.2,
            fatPerServing: 0.1,
            servingSizeDescription: "1 white (33g)"
        ),
        CommonFood(
            name: "Tofu (Firm)",
            caloriesPerServing: 76,
            proteinPerServing: 8.1,
            carbsPerServing: 2.8,
            fatPerServing: 4.8,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Lentils (Cooked)",
            caloriesPerServing: 116,
            proteinPerServing: 9.0,
            carbsPerServing: 20.1,
            fatPerServing: 0.4,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Chickpeas (Canned)",
            caloriesPerServing: 139,
            proteinPerServing: 8.9,
            carbsPerServing: 27.4,
            fatPerServing: 2.1,
            servingSizeDescription: "100g"
        ),

        // --- Grains & Carbs ---
        CommonFood(
            name: "White Rice (Cooked)",
            caloriesPerServing: 130,
            proteinPerServing: 2.7,
            carbsPerServing: 28.2,
            fatPerServing: 0.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Brown Rice (Cooked)",
            caloriesPerServing: 111,
            proteinPerServing: 2.6,
            carbsPerServing: 23.0,
            fatPerServing: 0.9,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Quinoa (Cooked)",
            caloriesPerServing: 120,
            proteinPerServing: 4.4,
            carbsPerServing: 21.3,
            fatPerServing: 1.9,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Oats (Dry, Rolled)",
            caloriesPerServing: 389,
            proteinPerServing: 16.9,
            carbsPerServing: 66.3,
            fatPerServing: 6.9,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Pasta (Dry)",
            caloriesPerServing: 371,
            proteinPerServing: 13.0,
            carbsPerServing: 74.7,
            fatPerServing: 1.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Whole Wheat Bread",
            caloriesPerServing: 92,
            proteinPerServing: 4.0,
            carbsPerServing: 17.2,
            fatPerServing: 1.1,
            servingSizeDescription: "1 slice (34g)"
        ),
        
        // --- Dairy & Alternatives ---
        CommonFood(
            name: "Milk (Whole, 3.5%)",
            caloriesPerServing: 61,
            proteinPerServing: 3.3,
            carbsPerServing: 4.7,
            fatPerServing: 3.5,
            servingSizeDescription: "100ml"
        ),
        CommonFood(
            name: "Milk (Skim)",
            caloriesPerServing: 35,
            proteinPerServing: 3.4,
            carbsPerServing: 5.0,
            fatPerServing: 0.1,
            servingSizeDescription: "100ml"
        ),
        CommonFood(
            name: "Almond Milk (Unsweetened)",
            caloriesPerServing: 13,
            proteinPerServing: 0.4,
            carbsPerServing: 1.4,
            fatPerServing: 0.6,
            servingSizeDescription: "100ml"
        ),
        CommonFood(
            name: "Greek Yogurt (Plain, 0%)",
            caloriesPerServing: 59,
            proteinPerServing: 10.3,
            carbsPerServing: 3.6,
            fatPerServing: 0.4,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Cottage Cheese (Low Fat)",
            caloriesPerServing: 72,
            proteinPerServing: 12.4,
            carbsPerServing: 2.7,
            fatPerServing: 1.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Cheddar Cheese",
            caloriesPerServing: 404,
            proteinPerServing: 24.9,
            carbsPerServing: 1.3,
            fatPerServing: 33.3,
            servingSizeDescription: "100g"
        ),
        
        // --- Fats, Oils & Supplements ---
        CommonFood(
            name: "Olive Oil",
            caloriesPerServing: 119,
            proteinPerServing: 0,
            carbsPerServing: 0,
            fatPerServing: 13.5,
            servingSizeDescription: "1 tbsp (15ml)"
        ),
        CommonFood(
            name: "Peanut Butter",
            caloriesPerServing: 188,
            proteinPerServing: 7.0,
            carbsPerServing: 7.7,
            fatPerServing: 16.1,
            servingSizeDescription: "2 tbsp (32g)"
        ),
        CommonFood(
            name: "Almonds",
            caloriesPerServing: 579,
            proteinPerServing: 21.2,
            carbsPerServing: 21.6,
            fatPerServing: 49.9,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Whey Protein Powder",
            caloriesPerServing: 120,
            proteinPerServing: 24.0,
            carbsPerServing: 3.0,
            fatPerServing: 1.5,
            servingSizeDescription: "1 scoop (30g)"
        ),
        CommonFood(
            name: "Asparagus",
            caloriesPerServing: 20,
            proteinPerServing: 2.2,
            carbsPerServing: 3.9,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Mushroom (White)",
            caloriesPerServing: 22,
            proteinPerServing: 3.1,
            carbsPerServing: 3.3,
            fatPerServing: 0.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Zucchini",
            caloriesPerServing: 17,
            proteinPerServing: 1.2,
            carbsPerServing: 3.1,
            fatPerServing: 0.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Kale (Raw)",
            caloriesPerServing: 49,
            proteinPerServing: 4.3,
            carbsPerServing: 8.8,
            fatPerServing: 0.9,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Cauliflower",
            caloriesPerServing: 25,
            proteinPerServing: 1.9,
            carbsPerServing: 5.0,
            fatPerServing: 0.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Mango",
            caloriesPerServing: 60,
            proteinPerServing: 0.8,
            carbsPerServing: 15.0,
            fatPerServing: 0.4,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Pear",
            caloriesPerServing: 57,
            proteinPerServing: 0.4,
            carbsPerServing: 15.2,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Kiwi",
            caloriesPerServing: 61,
            proteinPerServing: 1.1,
            carbsPerServing: 14.7,
            fatPerServing: 0.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Raspberries",
            caloriesPerServing: 52,
            proteinPerServing: 1.2,
            carbsPerServing: 11.9,
            fatPerServing: 0.7,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Shrimp (Cooked)",
            caloriesPerServing: 99,
            proteinPerServing: 24.0,
            carbsPerServing: 0.2,
            fatPerServing: 0.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Cod (Cooked)",
            caloriesPerServing: 105,
            proteinPerServing: 22.8,
            carbsPerServing: 0,
            fatPerServing: 0.7,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Steak (Sirloin, Cooked)",
            caloriesPerServing: 206,
            proteinPerServing: 29.0,
            carbsPerServing: 0,
            fatPerServing: 9.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Bacon (Cooked, Crispy)",
            caloriesPerServing: 541,
            proteinPerServing: 37.0,
            carbsPerServing: 1.4,
            fatPerServing: 42.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Soy Milk (Unsweetened)",
            caloriesPerServing: 33,
            proteinPerServing: 2.8,
            carbsPerServing: 1.7,
            fatPerServing: 1.6,
            servingSizeDescription: "100ml"
        ),
        CommonFood(
            name: "Bagel (Plain)",
            caloriesPerServing: 257,
            proteinPerServing: 10.4,
            carbsPerServing: 50.9,
            fatPerServing: 1.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Walnuts",
            caloriesPerServing: 654,
            proteinPerServing: 15.2,
            carbsPerServing: 13.7,
            fatPerServing: 65.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Butter (Salted)",
            caloriesPerServing: 102,
            proteinPerServing: 0.1,
            carbsPerServing: 0.0,
            fatPerServing: 11.5,
            servingSizeDescription: "1 tbsp (14g)"
        ),
        CommonFood(
            name: "Cream Cheese",
            caloriesPerServing: 342,
            proteinPerServing: 6.2,
            carbsPerServing: 4.1,
            fatPerServing: 34.4,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Sugar (White, Granulated)",
            caloriesPerServing: 387,
            proteinPerServing: 0,
            carbsPerServing: 100,
            fatPerServing: 0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Brown Sugar (Packed)",
            caloriesPerServing: 380,
            proteinPerServing: 0,
            carbsPerServing: 98.1,
            fatPerServing: 0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Honey",
            caloriesPerServing: 64,
            proteinPerServing: 0.1,
            carbsPerServing: 17.3,
            fatPerServing: 0,
            servingSizeDescription: "1 tbsp (21g)"
        ),
        CommonFood(
            name: "Maple Syrup",
            caloriesPerServing: 52,
            proteinPerServing: 0,
            carbsPerServing: 13.4,
            fatPerServing: 0,
            servingSizeDescription: "1 tbsp (20g)"
        ),
        CommonFood(
            name: "Flour (All-Purpose)",
            caloriesPerServing: 364,
            proteinPerServing: 10.3,
            carbsPerServing: 76.3,
            fatPerServing: 1.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Vegetable Oil",
            caloriesPerServing: 124,
            proteinPerServing: 0,
            carbsPerServing: 0,
            fatPerServing: 14.0,
            servingSizeDescription: "1 tbsp (15ml)"
        ),
        CommonFood(
            name: "Coconut Oil",
            caloriesPerServing: 117,
            proteinPerServing: 0,
            carbsPerServing: 0,
            fatPerServing: 13.5,
            servingSizeDescription: "1 tbsp (15ml)"
        ),
        CommonFood(
            name: "Mayonnaise",
            caloriesPerServing: 94,
            proteinPerServing: 0.1,
            carbsPerServing: 0.1,
            fatPerServing: 10.3,
            servingSizeDescription: "1 tbsp (15g)"
        ),
        CommonFood(
            name: "Ketchup",
            caloriesPerServing: 17,
            proteinPerServing: 0.2,
            carbsPerServing: 4.5,
            fatPerServing: 0.1,
            servingSizeDescription: "1 tbsp (17g)"
        ),
        CommonFood(
            name: "Mustard (Yellow)",
            caloriesPerServing: 3,
            proteinPerServing: 0.2,
            carbsPerServing: 0.3,
            fatPerServing: 0.2,
            servingSizeDescription: "1 tsp (5g)"
        ),
        CommonFood(
            name: "Soy Sauce",
            caloriesPerServing: 8,
            proteinPerServing: 1.3,
            carbsPerServing: 0.8,
            fatPerServing: 0,
            servingSizeDescription: "1 tbsp (16g)"
        ),
        CommonFood(
            name: "Sriracha",
            caloriesPerServing: 5,
            proteinPerServing: 0.1,
            carbsPerServing: 1.2,
            fatPerServing: 0,
            servingSizeDescription: "1 tsp (5g)"
        ),
        CommonFood(
            name: "Pillsbury golden layer buttermilk biscuits",
            caloriesPerServing: 307.0,
            proteinPerServing: 5.9,
            carbsPerServing: 41.2,
            fatPerServing: 13.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Pillsbury",
            caloriesPerServing: 330.0,
            proteinPerServing: 4.3,
            carbsPerServing: 53.4,
            fatPerServing: 11.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Kraft foods",
            caloriesPerServing: 377.0,
            proteinPerServing: 6.1,
            carbsPerServing: 79.8,
            fatPerServing: 3.7,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "George weston bakeries",
            caloriesPerServing: 232.0,
            proteinPerServing: 8.0,
            carbsPerServing: 46.0,
            fatPerServing: 1.8,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Waffles",
            caloriesPerServing: 273.0,
            proteinPerServing: 6.6,
            carbsPerServing: 41.0,
            fatPerServing: 9.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Waffle",
            caloriesPerServing: 309.0,
            proteinPerServing: 7.4,
            carbsPerServing: 48.4,
            fatPerServing: 9.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Pie crust",
            caloriesPerServing: 501.0,
            proteinPerServing: 5.1,
            carbsPerServing: 64.3,
            fatPerServing: 24.8,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Pie",
            caloriesPerServing: 290.0,
            proteinPerServing: 2.2,
            carbsPerServing: 44.5,
            fatPerServing: 11.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Tostada shells",
            caloriesPerServing: 474.0,
            proteinPerServing: 6.2,
            carbsPerServing: 64.4,
            fatPerServing: 23.4,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Bread",
            caloriesPerServing: 374.0,
            proteinPerServing: 7.1,
            carbsPerServing: 47.8,
            fatPerServing: 17.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Pastry",
            caloriesPerServing: 379.0,
            proteinPerServing: 5.5,
            carbsPerServing: 47.8,
            fatPerServing: 18.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Crackers",
            caloriesPerServing: 433.0,
            proteinPerServing: 14.2,
            carbsPerServing: 64.3,
            fatPerServing: 13.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Bagels",
            caloriesPerServing: 250.0,
            proteinPerServing: 10.2,
            carbsPerServing: 48.9,
            fatPerServing: 1.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Cream puff",
            caloriesPerServing: 334.0,
            proteinPerServing: 4.4,
            carbsPerServing: 37.4,
            fatPerServing: 18.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Tortillas",
            caloriesPerServing: 297.0,
            proteinPerServing: 8.0,
            carbsPerServing: 49.3,
            fatPerServing: 7.6,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Snacks",
            caloriesPerServing: 410.0,
            proteinPerServing: 33.2,
            carbsPerServing: 11.0,
            fatPerServing: 25.6,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Candies",
            caloriesPerServing: 473.0,
            proteinPerServing: 8.7,
            carbsPerServing: 67.4,
            fatPerServing: 20.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Baking chocolate",
            caloriesPerServing: 472.0,
            proteinPerServing: 12.1,
            carbsPerServing: 36.2,
            fatPerServing: 47.7,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Ice creams",
            caloriesPerServing: 180.0,
            proteinPerServing: 4.8,
            carbsPerServing: 29.5,
            fatPerServing: 4.8,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Desserts",
            caloriesPerServing: 145.0,
            proteinPerServing: 4.5,
            carbsPerServing: 22.8,
            fatPerServing: 4.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Sherbet",
            caloriesPerServing: 144.0,
            proteinPerServing: 1.1,
            carbsPerServing: 30.4,
            fatPerServing: 2.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Syrups",
            caloriesPerServing: 291.0,
            proteinPerServing: 0.0,
            carbsPerServing: 72.4,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Puddings",
            caloriesPerServing: 105.0,
            proteinPerServing: 2.8,
            carbsPerServing: 19.7,
            fatPerServing: 1.7,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Andrea's",
            caloriesPerServing: 257.0,
            proteinPerServing: 5.7,
            carbsPerServing: 40.2,
            fatPerServing: 8.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Crunchmaster",
            caloriesPerServing: 456.0,
            proteinPerServing: 10.9,
            carbsPerServing: 67.2,
            fatPerServing: 15.9,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Glutino",
            caloriesPerServing: 474.0,
            proteinPerServing: 2.2,
            carbsPerServing: 76.0,
            fatPerServing: 17.9,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Pepperidge farm",
            caloriesPerServing: 467.0,
            proteinPerServing: 9.4,
            carbsPerServing: 65.8,
            fatPerServing: 18.4,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Rudi's",
            caloriesPerServing: 320.0,
            proteinPerServing: 3.1,
            carbsPerServing: 52.8,
            fatPerServing: 10.7,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Udi's",
            caloriesPerServing: 298.0,
            proteinPerServing: 5.4,
            carbsPerServing: 51.1,
            fatPerServing: 8.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Van's",
            caloriesPerServing: 215.0,
            proteinPerServing: 3.3,
            carbsPerServing: 40.3,
            fatPerServing: 4.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Seaweed",
            caloriesPerServing: 259.0,
            proteinPerServing: 15.3,
            carbsPerServing: 46.2,
            fatPerServing: 1.4,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Potatoes",
            caloriesPerServing: 84.0,
            proteinPerServing: 1.8,
            carbsPerServing: 19.2,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Sweet potatoes",
            caloriesPerServing: 182.0,
            proteinPerServing: 2.2,
            carbsPerServing: 35.6,
            fatPerServing: 8.9,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Moose",
            caloriesPerServing: 103.0,
            proteinPerServing: 22.3,
            carbsPerServing: 0.0,
            fatPerServing: 1.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Mashu roots",
            caloriesPerServing: 135.0,
            proteinPerServing: 5.8,
            carbsPerServing: 22.6,
            fatPerServing: 2.4,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Seal",
            caloriesPerServing: 110.0,
            proteinPerServing: 26.7,
            carbsPerServing: 0.0,
            fatPerServing: 0.4,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Oil",
            caloriesPerServing: 899.0,
            proteinPerServing: 0.6,
            carbsPerServing: 0.0,
            fatPerServing: 99.6,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Oopah (tunicate)",
            caloriesPerServing: 67.0,
            proteinPerServing: 11.7,
            carbsPerServing: 0.0,
            fatPerServing: 2.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Owl",
            caloriesPerServing: 136.0,
            proteinPerServing: 22.7,
            carbsPerServing: 0.0,
            fatPerServing: 5.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Fish",
            caloriesPerServing: 150.0,
            proteinPerServing: 23.2,
            carbsPerServing: 0.0,
            fatPerServing: 5.9,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Duck",
            caloriesPerServing: 84.0,
            proteinPerServing: 20.2,
            carbsPerServing: 0.0,
            fatPerServing: 0.4,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Sea cucumber",
            caloriesPerServing: 56.0,
            proteinPerServing: 13.0,
            carbsPerServing: 0.0,
            fatPerServing: 0.4,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Squirrel",
            caloriesPerServing: 111.0,
            proteinPerServing: 19.3,
            carbsPerServing: 0.0,
            fatPerServing: 3.8,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Tea",
            caloriesPerServing: 1.0,
            proteinPerServing: 0.0,
            carbsPerServing: 0.2,
            fatPerServing: 0.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Walrus",
            caloriesPerServing: 251.0,
            proteinPerServing: 57.0,
            carbsPerServing: 0.0,
            fatPerServing: 2.6,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Deer (venison)",
            caloriesPerServing: 116.0,
            proteinPerServing: 21.5,
            carbsPerServing: 0.0,
            fatPerServing: 2.7,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Whale",
            caloriesPerServing: 870.0,
            proteinPerServing: 0.4,
            carbsPerServing: 0.0,
            fatPerServing: 96.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Mush",
            caloriesPerServing: 54.0,
            proteinPerServing: 0.7,
            carbsPerServing: 11.7,
            fatPerServing: 0.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Cornmeal",
            caloriesPerServing: 398.0,
            proteinPerServing: 10.4,
            carbsPerServing: 76.9,
            fatPerServing: 5.4,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Melon",
            caloriesPerServing: 21.0,
            proteinPerServing: 0.8,
            carbsPerServing: 4.1,
            fatPerServing: 0.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Chilchen (red berry beverage) (navajo)",
            caloriesPerServing: 44.0,
            proteinPerServing: 0.8,
            carbsPerServing: 8.7,
            fatPerServing: 0.6,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Corn",
            caloriesPerServing: 386.0,
            proteinPerServing: 9.9,
            carbsPerServing: 74.9,
            fatPerServing: 5.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Squash",
            caloriesPerServing: 16.0,
            proteinPerServing: 0.3,
            carbsPerServing: 3.2,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Mutton",
            caloriesPerServing: 234.0,
            proteinPerServing: 33.4,
            carbsPerServing: 0.1,
            fatPerServing: 11.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Frybread",
            caloriesPerServing: 330.0,
            proteinPerServing: 6.7,
            carbsPerServing: 48.3,
            fatPerServing: 12.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Tamales (navajo)",
            caloriesPerServing: 153.0,
            proteinPerServing: 6.3,
            carbsPerServing: 18.1,
            fatPerServing: 6.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Stew",
            caloriesPerServing: 112.0,
            proteinPerServing: 8.8,
            carbsPerServing: 10.8,
            fatPerServing: 3.8,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Blueberries",
            caloriesPerServing: 61.0,
            proteinPerServing: 1.2,
            carbsPerServing: 12.3,
            fatPerServing: 0.8,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Caribou",
            caloriesPerServing: 255.0,
            proteinPerServing: 52.1,
            carbsPerServing: 0.0,
            fatPerServing: 5.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Buffalo",
            caloriesPerServing: 97.0,
            proteinPerServing: 21.4,
            carbsPerServing: 0.0,
            fatPerServing: 1.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Elk",
            caloriesPerServing: 98.0,
            proteinPerServing: 19.7,
            carbsPerServing: 0.0,
            fatPerServing: 2.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Smelt",
            caloriesPerServing: 386.0,
            proteinPerServing: 56.2,
            carbsPerServing: 0.0,
            fatPerServing: 17.9,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Corned beef and potatoes in tortilla (apache)",
            caloriesPerServing: 224.0,
            proteinPerServing: 7.9,
            carbsPerServing: 29.4,
            fatPerServing: 8.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "On the border",
            caloriesPerServing: 229.0,
            proteinPerServing: 13.2,
            carbsPerServing: 19.3,
            fatPerServing: 11.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Restaurant",
            caloriesPerServing: 219.0,
            proteinPerServing: 12.6,
            carbsPerServing: 17.9,
            fatPerServing: 10.8,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Cracker barrel",
            caloriesPerServing: 255.0,
            proteinPerServing: 3.3,
            carbsPerServing: 30.9,
            fatPerServing: 13.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Denny's",
            caloriesPerServing: 282.0,
            proteinPerServing: 3.4,
            carbsPerServing: 35.2,
            fatPerServing: 14.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Beverages",
            caloriesPerServing: 218.0,
            proteinPerServing: 0.5,
            carbsPerServing: 87.4,
            fatPerServing: 0.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Pectin",
            caloriesPerServing: 11.0,
            proteinPerServing: 0.0,
            carbsPerServing: 2.1,
            fatPerServing: 0.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Frozen novelties",
            caloriesPerServing: 221.0,
            proteinPerServing: 6.4,
            carbsPerServing: 26.1,
            fatPerServing: 10.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Creamy dressing",
            caloriesPerServing: 160.0,
            proteinPerServing: 1.5,
            carbsPerServing: 7.0,
            fatPerServing: 14.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Bologna",
            caloriesPerServing: 230.0,
            proteinPerServing: 11.5,
            carbsPerServing: 2.6,
            fatPerServing: 19.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Milk dessert",
            caloriesPerServing: 167.0,
            proteinPerServing: 4.3,
            carbsPerServing: 37.7,
            fatPerServing: 1.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Whipped topping",
            caloriesPerServing: 224.0,
            proteinPerServing: 3.0,
            carbsPerServing: 23.6,
            fatPerServing: 13.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Cream substitute",
            caloriesPerServing: 431.0,
            proteinPerServing: 1.9,
            carbsPerServing: 73.4,
            fatPerServing: 15.7,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Babyfood",
            caloriesPerServing: 93.0,
            proteinPerServing: 0.8,
            carbsPerServing: 19.5,
            fatPerServing: 1.6,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Vegetable oil-butter spread",
            caloriesPerServing: 465.0,
            proteinPerServing: 0.0,
            carbsPerServing: 0.0,
            fatPerServing: 53.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Salad dressing",
            caloriesPerServing: 86.0,
            proteinPerServing: 2.1,
            carbsPerServing: 13.2,
            fatPerServing: 2.7,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Sausage",
            caloriesPerServing: 307.0,
            proteinPerServing: 22.7,
            carbsPerServing: 0.7,
            fatPerServing: 23.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Mayonnaise",
            caloriesPerServing: 322.0,
            proteinPerServing: 6.0,
            carbsPerServing: 3.1,
            fatPerServing: 31.8,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Frankfurter",
            caloriesPerServing: 140.0,
            proteinPerServing: 12.0,
            carbsPerServing: 1.6,
            fatPerServing: 9.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Milk",
            caloriesPerServing: 56.0,
            proteinPerServing: 4.1,
            carbsPerServing: 5.3,
            fatPerServing: 2.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Pork sausage rice links",
            caloriesPerServing: 407.0,
            proteinPerServing: 13.7,
            carbsPerServing: 2.4,
            fatPerServing: 37.6,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Cheese",
            caloriesPerServing: 74.0,
            proteinPerServing: 12.4,
            carbsPerServing: 3.2,
            fatPerServing: 1.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Jams",
            caloriesPerServing: 151.0,
            proteinPerServing: 0.0,
            carbsPerServing: 37.6,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Tomato and vegetable juice",
            caloriesPerServing: 22.0,
            proteinPerServing: 0.6,
            carbsPerServing: 4.6,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Turkey",
            caloriesPerServing: 221.0,
            proteinPerServing: 27.4,
            carbsPerServing: 0.0,
            fatPerServing: 12.4,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Pork",
            caloriesPerServing: 541.0,
            proteinPerServing: 37.0,
            carbsPerServing: 1.4,
            fatPerServing: 41.8,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Hearts of palm",
            caloriesPerServing: 115.0,
            proteinPerServing: 2.7,
            carbsPerServing: 25.6,
            fatPerServing: 0.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Cereals ready-to-eat",
            caloriesPerServing: 339.0,
            proteinPerServing: 10.9,
            carbsPerServing: 80.7,
            fatPerServing: 2.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Yeast extract spread",
            caloriesPerServing: 185.0,
            proteinPerServing: 23.9,
            carbsPerServing: 20.4,
            fatPerServing: 0.9,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Chicken",
            caloriesPerServing: 234.0,
            proteinPerServing: 21.3,
            carbsPerServing: 8.5,
            fatPerServing: 12.8,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Tofu yogurt",
            caloriesPerServing: 94.0,
            proteinPerServing: 3.5,
            carbsPerServing: 16.0,
            fatPerServing: 1.8,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Alcoholic beverage",
            caloriesPerServing: 134.0,
            proteinPerServing: 0.5,
            carbsPerServing: 5.0,
            fatPerServing: 0.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Millet",
            caloriesPerServing: 354.0,
            proteinPerServing: 13.0,
            carbsPerServing: 80.0,
            fatPerServing: 3.4,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Breakfast bar",
            caloriesPerServing: 376.0,
            proteinPerServing: 4.4,
            carbsPerServing: 72.8,
            fatPerServing: 7.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Mayonnaise dressing",
            caloriesPerServing: 688.0,
            proteinPerServing: 0.0,
            carbsPerServing: 0.3,
            fatPerServing: 77.8,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Pie fillings",
            caloriesPerServing: 181.0,
            proteinPerServing: 0.4,
            carbsPerServing: 44.4,
            fatPerServing: 0.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Mollusks",
            caloriesPerServing: 111.0,
            proteinPerServing: 20.5,
            carbsPerServing: 5.4,
            fatPerServing: 0.8,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Syrup",
            caloriesPerServing: 269.0,
            proteinPerServing: 0.0,
            carbsPerServing: 73.1,
            fatPerServing: 0.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Turtle",
            caloriesPerServing: 89.0,
            proteinPerServing: 19.8,
            carbsPerServing: 0.0,
            fatPerServing: 0.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Lemons",
            caloriesPerServing: 29.0,
            proteinPerServing: 1.1,
            carbsPerServing: 9.3,
            fatPerServing: 0.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Lemon juice",
            caloriesPerServing: 22.0,
            proteinPerServing: 0.3,
            carbsPerServing: 6.9,
            fatPerServing: 0.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Lemon juice from concentrate",
            caloriesPerServing: 17.0,
            proteinPerServing: 0.5,
            carbsPerServing: 5.6,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Lemon peel",
            caloriesPerServing: 47.0,
            proteinPerServing: 1.5,
            carbsPerServing: 16.0,
            fatPerServing: 0.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Prickly pears",
            caloriesPerServing: 41.0,
            proteinPerServing: 0.7,
            carbsPerServing: 9.6,
            fatPerServing: 0.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Plums",
            caloriesPerServing: 107.0,
            proteinPerServing: 1.0,
            carbsPerServing: 28.1,
            fatPerServing: 0.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Prune juice",
            caloriesPerServing: 71.0,
            proteinPerServing: 0.6,
            carbsPerServing: 17.4,
            fatPerServing: 0.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Pummelo",
            caloriesPerServing: 38.0,
            proteinPerServing: 0.8,
            carbsPerServing: 9.6,
            fatPerServing: 0.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Raspberries",
            caloriesPerServing: 52.0,
            proteinPerServing: 1.2,
            carbsPerServing: 11.9,
            fatPerServing: 0.7,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Rhubarb",
            caloriesPerServing: 21.0,
            proteinPerServing: 0.9,
            carbsPerServing: 4.5,
            fatPerServing: 0.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Sapodilla",
            caloriesPerServing: 83.0,
            proteinPerServing: 0.4,
            carbsPerServing: 20.0,
            fatPerServing: 1.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Sapote",
            caloriesPerServing: 124.0,
            proteinPerServing: 1.4,
            carbsPerServing: 32.1,
            fatPerServing: 0.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Soursop",
            caloriesPerServing: 66.0,
            proteinPerServing: 1.0,
            carbsPerServing: 16.8,
            fatPerServing: 0.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Strawberries",
            caloriesPerServing: 32.0,
            proteinPerServing: 0.7,
            carbsPerServing: 7.7,
            fatPerServing: 0.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Tamarinds",
            caloriesPerServing: 239.0,
            proteinPerServing: 2.8,
            carbsPerServing: 62.5,
            fatPerServing: 0.6,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Fruit salad",
            caloriesPerServing: 86.0,
            proteinPerServing: 0.4,
            carbsPerServing: 22.4,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Watermelon",
            caloriesPerServing: 30.0,
            proteinPerServing: 0.6,
            carbsPerServing: 7.5,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Maraschino cherries",
            caloriesPerServing: 165.0,
            proteinPerServing: 0.2,
            carbsPerServing: 42.0,
            fatPerServing: 0.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Pineapple",
            caloriesPerServing: 60.0,
            proteinPerServing: 0.5,
            carbsPerServing: 15.6,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Apricots",
            caloriesPerServing: 83.0,
            proteinPerServing: 0.6,
            carbsPerServing: 21.3,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Cherries",
            caloriesPerServing: 42.0,
            proteinPerServing: 0.7,
            carbsPerServing: 10.4,
            fatPerServing: 0.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Apple juice",
            caloriesPerServing: 46.0,
            proteinPerServing: 0.1,
            carbsPerServing: 11.3,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Applesauce",
            caloriesPerServing: 42.0,
            proteinPerServing: 0.2,
            carbsPerServing: 11.3,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Grapefruit juice",
            caloriesPerServing: 39.0,
            proteinPerServing: 0.5,
            carbsPerServing: 9.2,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Pears",
            caloriesPerServing: 63.0,
            proteinPerServing: 0.4,
            carbsPerServing: 15.0,
            fatPerServing: 0.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Prune puree",
            caloriesPerServing: 257.0,
            proteinPerServing: 2.1,
            carbsPerServing: 65.1,
            fatPerServing: 0.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Candied fruit",
            caloriesPerServing: 322.0,
            proteinPerServing: 0.3,
            carbsPerServing: 82.7,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Abiyuch",
            caloriesPerServing: 69.0,
            proteinPerServing: 1.5,
            carbsPerServing: 17.6,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Rowal",
            caloriesPerServing: 111.0,
            proteinPerServing: 2.3,
            carbsPerServing: 23.9,
            fatPerServing: 2.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Guava nectar",
            caloriesPerServing: 63.0,
            proteinPerServing: 0.1,
            carbsPerServing: 16.2,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Mango nectar",
            caloriesPerServing: 51.0,
            proteinPerServing: 0.1,
            carbsPerServing: 13.1,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Tamarind nectar",
            caloriesPerServing: 57.0,
            proteinPerServing: 0.1,
            carbsPerServing: 14.7,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Pomegranate juice",
            caloriesPerServing: 54.0,
            proteinPerServing: 0.1,
            carbsPerServing: 13.1,
            fatPerServing: 0.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Nance",
            caloriesPerServing: 95.0,
            proteinPerServing: 0.6,
            carbsPerServing: 22.8,
            fatPerServing: 1.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Naranjilla (lulo) pulp",
            caloriesPerServing: 25.0,
            proteinPerServing: 0.4,
            carbsPerServing: 5.9,
            fatPerServing: 0.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Horned melon (kiwano)",
            caloriesPerServing: 44.0,
            proteinPerServing: 1.8,
            carbsPerServing: 7.6,
            fatPerServing: 1.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Orange pineapple juice blend",
            caloriesPerServing: 51.0,
            proteinPerServing: 0.4,
            carbsPerServing: 12.2,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Apples",
            caloriesPerServing: 63.0,
            proteinPerServing: 0.2,
            carbsPerServing: 15.2,
            fatPerServing: 0.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Orange juice",
            caloriesPerServing: 49.0,
            proteinPerServing: 0.7,
            carbsPerServing: 11.5,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Fruit juice smoothie",
            caloriesPerServing: 63.0,
            proteinPerServing: 0.4,
            carbsPerServing: 15.0,
            fatPerServing: 0.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Cranberry sauce",
            caloriesPerServing: 158.0,
            proteinPerServing: 0.8,
            carbsPerServing: 40.4,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Ruby red grapefruit juice blend (grapefruit",
            caloriesPerServing: 44.0,
            proteinPerServing: 0.5,
            carbsPerServing: 10.5,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Baobab powder",
            caloriesPerServing: 250.0,
            proteinPerServing: 3.7,
            carbsPerServing: 79.7,
            fatPerServing: 0.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Cherry juice",
            caloriesPerServing: 59.0,
            proteinPerServing: 0.3,
            carbsPerServing: 13.7,
            fatPerServing: 0.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Canadian bacon",
            caloriesPerServing: 110.0,
            proteinPerServing: 20.3,
            carbsPerServing: 1.3,
            fatPerServing: 2.6,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Hormel",
            caloriesPerServing: 106.0,
            proteinPerServing: 18.4,
            carbsPerServing: 0.2,
            fatPerServing: 3.6,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Hormel always tender",
            caloriesPerServing: 119.0,
            proteinPerServing: 18.2,
            carbsPerServing: 4.6,
            fatPerServing: 3.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Hormel canadian style bacon",
            caloriesPerServing: 122.0,
            proteinPerServing: 16.9,
            carbsPerServing: 1.9,
            fatPerServing: 4.9,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Pillsbury grands",
            caloriesPerServing: 293.0,
            proteinPerServing: 6.2,
            carbsPerServing: 42.4,
            fatPerServing: 11.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Heinz",
            caloriesPerServing: 241.0,
            proteinPerServing: 4.4,
            carbsPerServing: 40.3,
            fatPerServing: 6.9,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Interstate brands corp",
            caloriesPerServing: 273.0,
            proteinPerServing: 8.1,
            carbsPerServing: 50.8,
            fatPerServing: 4.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Nabisco",
            caloriesPerServing: 305.0,
            proteinPerServing: 5.0,
            carbsPerServing: 74.2,
            fatPerServing: 1.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Pancakes",
            caloriesPerServing: 239.0,
            proteinPerServing: 5.9,
            carbsPerServing: 43.3,
            fatPerServing: 4.7,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Toaster pastries",
            caloriesPerServing: 385.0,
            proteinPerServing: 4.0,
            carbsPerServing: 71.8,
            fatPerServing: 9.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Muffin",
            caloriesPerServing: 255.0,
            proteinPerServing: 4.2,
            carbsPerServing: 50.0,
            fatPerServing: 4.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Keikitos (muffins)",
            caloriesPerServing: 467.0,
            proteinPerServing: 6.8,
            carbsPerServing: 53.2,
            fatPerServing: 25.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Cake",
            caloriesPerServing: 418.0,
            proteinPerServing: 6.6,
            carbsPerServing: 48.9,
            fatPerServing: 21.7,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Pan dulce",
            caloriesPerServing: 445.0,
            proteinPerServing: 8.8,
            carbsPerServing: 66.3,
            fatPerServing: 16.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Garlic bread",
            caloriesPerServing: 350.0,
            proteinPerServing: 8.4,
            carbsPerServing: 41.7,
            fatPerServing: 16.6,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Cinnamon buns",
            caloriesPerServing: 452.0,
            proteinPerServing: 4.5,
            carbsPerServing: 48.6,
            fatPerServing: 26.6,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Focaccia",
            caloriesPerServing: 249.0,
            proteinPerServing: 8.8,
            carbsPerServing: 35.8,
            fatPerServing: 7.9,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Schiff",
            caloriesPerServing: 387.0,
            proteinPerServing: 16.8,
            carbsPerServing: 56.5,
            fatPerServing: 14.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Fruit syrup",
            caloriesPerServing: 341.0,
            proteinPerServing: 0.0,
            carbsPerServing: 85.1,
            fatPerServing: 0.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Topping",
            caloriesPerServing: 609.0,
            proteinPerServing: 2.9,
            carbsPerServing: 50.1,
            fatPerServing: 44.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Chocolate-flavored hazelnut spread",
            caloriesPerServing: 539.0,
            proteinPerServing: 5.4,
            carbsPerServing: 62.4,
            fatPerServing: 29.7,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Mary's gone crackers",
            caloriesPerServing: 446.0,
            proteinPerServing: 12.1,
            carbsPerServing: 64.3,
            fatPerServing: 15.6,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Sage valley",
            caloriesPerServing: 499.0,
            proteinPerServing: 3.1,
            carbsPerServing: 71.9,
            fatPerServing: 22.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Schar",
            caloriesPerServing: 239.0,
            proteinPerServing: 3.3,
            carbsPerServing: 50.5,
            fatPerServing: 2.6,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Cookies",
            caloriesPerServing: 446.0,
            proteinPerServing: 6.9,
            carbsPerServing: 74.1,
            fatPerServing: 13.8,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Sweet potato puffs",
            caloriesPerServing: 161.0,
            proteinPerServing: 1.4,
            carbsPerServing: 30.7,
            fatPerServing: 3.6,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Mouse nuts",
            caloriesPerServing: 81.0,
            proteinPerServing: 3.9,
            carbsPerServing: 16.1,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Octopus (alaska native)",
            caloriesPerServing: 56.0,
            proteinPerServing: 12.3,
            carbsPerServing: 0.0,
            fatPerServing: 0.8,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Soup",
            caloriesPerServing: 72.0,
            proteinPerServing: 7.4,
            carbsPerServing: 5.6,
            fatPerServing: 2.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Sourdock",
            caloriesPerServing: 42.0,
            proteinPerServing: 2.3,
            carbsPerServing: 6.5,
            fatPerServing: 0.7,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Willow",
            caloriesPerServing: 592.0,
            proteinPerServing: 2.6,
            carbsPerServing: 8.1,
            fatPerServing: 61.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Tortilla",
            caloriesPerServing: 237.0,
            proteinPerServing: 7.3,
            carbsPerServing: 49.9,
            fatPerServing: 0.9,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Salmonberries",
            caloriesPerServing: 47.0,
            proteinPerServing: 0.8,
            carbsPerServing: 10.1,
            fatPerServing: 0.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Chokecherries",
            caloriesPerServing: 156.0,
            proteinPerServing: 2.9,
            carbsPerServing: 33.9,
            fatPerServing: 1.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Steelhead trout",
            caloriesPerServing: 382.0,
            proteinPerServing: 77.3,
            carbsPerServing: 0.0,
            fatPerServing: 8.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Acorn stew (apache)",
            caloriesPerServing: 95.0,
            proteinPerServing: 6.8,
            carbsPerServing: 9.2,
            fatPerServing: 3.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Olive garden",
            caloriesPerServing: 121.0,
            proteinPerServing: 5.8,
            carbsPerServing: 17.2,
            fatPerServing: 3.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Carrabba's italian grill",
            caloriesPerServing: 122.0,
            proteinPerServing: 5.9,
            carbsPerServing: 15.7,
            fatPerServing: 3.9,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Imitation cheese",
            caloriesPerServing: 390.0,
            proteinPerServing: 25.0,
            carbsPerServing: 1.0,
            fatPerServing: 32.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Ham",
            caloriesPerServing: 134.0,
            proteinPerServing: 19.6,
            carbsPerServing: 0.9,
            fatPerServing: 5.8,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Granola bar",
            caloriesPerServing: 536.0,
            proteinPerServing: 9.6,
            carbsPerServing: 54.1,
            fatPerServing: 31.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Frozen yogurts",
            caloriesPerServing: 107.0,
            proteinPerServing: 4.4,
            carbsPerServing: 19.7,
            fatPerServing: 0.8,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Papad",
            caloriesPerServing: 371.0,
            proteinPerServing: 25.6,
            carbsPerServing: 59.9,
            fatPerServing: 3.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Rice cake",
            caloriesPerServing: 392.0,
            proteinPerServing: 7.1,
            carbsPerServing: 81.1,
            fatPerServing: 4.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Cranberry juice",
            caloriesPerServing: 46.0,
            proteinPerServing: 0.4,
            carbsPerServing: 12.2,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Beef",
            caloriesPerServing: 310.0,
            proteinPerServing: 11.7,
            carbsPerServing: 2.0,
            fatPerServing: 28.4,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Turnip greens",
            caloriesPerServing: 19.0,
            proteinPerServing: 1.4,
            carbsPerServing: 2.8,
            fatPerServing: 0.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Rolls",
            caloriesPerServing: 276.0,
            proteinPerServing: 10.8,
            carbsPerServing: 51.9,
            fatPerServing: 2.8,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Beans",
            caloriesPerServing: 105.0,
            proteinPerServing: 4.8,
            carbsPerServing: 20.5,
            fatPerServing: 0.4,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Jellyfish",
            caloriesPerServing: 36.0,
            proteinPerServing: 5.5,
            carbsPerServing: 0.0,
            fatPerServing: 1.4,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Popcorn",
            caloriesPerServing: 429.0,
            proteinPerServing: 12.6,
            carbsPerServing: 73.4,
            fatPerServing: 9.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Sweeteners",
            caloriesPerServing: 279.0,
            proteinPerServing: 0.0,
            carbsPerServing: 76.1,
            fatPerServing: 0.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Jellies",
            caloriesPerServing: 179.0,
            proteinPerServing: 0.3,
            carbsPerServing: 46.1,
            fatPerServing: 0.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Vital wheat gluten",
            caloriesPerServing: 370.0,
            proteinPerServing: 75.2,
            carbsPerServing: 13.8,
            fatPerServing: 1.9,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Frog legs",
            caloriesPerServing: 73.0,
            proteinPerServing: 16.4,
            carbsPerServing: 0.0,
            fatPerServing: 0.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Java-plum",
            caloriesPerServing: 60.0,
            proteinPerServing: 0.7,
            carbsPerServing: 15.6,
            fatPerServing: 0.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Jujube",
            caloriesPerServing: 79.0,
            proteinPerServing: 1.2,
            carbsPerServing: 20.2,
            fatPerServing: 0.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Kiwifruit",
            caloriesPerServing: 61.0,
            proteinPerServing: 1.1,
            carbsPerServing: 14.7,
            fatPerServing: 0.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Kumquats",
            caloriesPerServing: 71.0,
            proteinPerServing: 1.9,
            carbsPerServing: 15.9,
            fatPerServing: 0.9,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Limes",
            caloriesPerServing: 30.0,
            proteinPerServing: 0.7,
            carbsPerServing: 10.5,
            fatPerServing: 0.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Lime juice",
            caloriesPerServing: 25.0,
            proteinPerServing: 0.4,
            carbsPerServing: 8.4,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Prunes",
            caloriesPerServing: 105.0,
            proteinPerServing: 0.9,
            carbsPerServing: 27.8,
            fatPerServing: 0.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Quinces",
            caloriesPerServing: 57.0,
            proteinPerServing: 0.4,
            carbsPerServing: 15.3,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Raisins",
            caloriesPerServing: 301.0,
            proteinPerServing: 3.3,
            carbsPerServing: 80.0,
            fatPerServing: 0.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Rambutan",
            caloriesPerServing: 82.0,
            proteinPerServing: 0.7,
            carbsPerServing: 20.9,
            fatPerServing: 0.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Roselle",
            caloriesPerServing: 49.0,
            proteinPerServing: 1.0,
            carbsPerServing: 11.3,
            fatPerServing: 0.6,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Rose-apples",
            caloriesPerServing: 25.0,
            proteinPerServing: 0.6,
            carbsPerServing: 5.7,
            fatPerServing: 0.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Sugar-apples",
            caloriesPerServing: 94.0,
            proteinPerServing: 2.1,
            carbsPerServing: 23.6,
            fatPerServing: 0.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Feijoa",
            caloriesPerServing: 61.0,
            proteinPerServing: 0.7,
            carbsPerServing: 15.2,
            fatPerServing: 0.4,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Fruit cocktail",
            caloriesPerServing: 70.0,
            proteinPerServing: 0.5,
            carbsPerServing: 18.8,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Peaches",
            caloriesPerServing: 72.0,
            proteinPerServing: 0.5,
            carbsPerServing: 18.4,
            fatPerServing: 0.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Tangerines",
            caloriesPerServing: 38.0,
            proteinPerServing: 0.8,
            carbsPerServing: 9.4,
            fatPerServing: 0.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Peach nectar",
            caloriesPerServing: 50.0,
            proteinPerServing: 0.2,
            carbsPerServing: 11.9,
            fatPerServing: 0.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Pear nectar",
            caloriesPerServing: 60.0,
            proteinPerServing: 0.1,
            carbsPerServing: 15.8,
            fatPerServing: 0.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Pineapple juice",
            caloriesPerServing: 53.0,
            proteinPerServing: 0.4,
            carbsPerServing: 12.9,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Jackfruit",
            caloriesPerServing: 92.0,
            proteinPerServing: 0.4,
            carbsPerServing: 23.9,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Dates",
            caloriesPerServing: 277.0,
            proteinPerServing: 1.8,
            carbsPerServing: 75.0,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Durian",
            caloriesPerServing: 147.0,
            proteinPerServing: 1.5,
            carbsPerServing: 27.1,
            fatPerServing: 5.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Clementines",
            caloriesPerServing: 47.0,
            proteinPerServing: 0.8,
            carbsPerServing: 12.0,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Guanabana nectar",
            caloriesPerServing: 59.0,
            proteinPerServing: 0.1,
            carbsPerServing: 14.9,
            fatPerServing: 0.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Juice",
            caloriesPerServing: 50.0,
            proteinPerServing: 0.2,
            carbsPerServing: 12.5,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Plantains",
            caloriesPerServing: 309.0,
            proteinPerServing: 1.5,
            carbsPerServing: 49.2,
            fatPerServing: 11.8,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Grape juice",
            caloriesPerServing: 62.0,
            proteinPerServing: 0.4,
            carbsPerServing: 14.8,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Cranberry juice blend",
            caloriesPerServing: 45.0,
            proteinPerServing: 0.3,
            carbsPerServing: 10.9,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Raspberry juice concentrate",
            caloriesPerServing: 221.0,
            proteinPerServing: 3.0,
            carbsPerServing: 53.2,
            fatPerServing: 1.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Pork loin",
            caloriesPerServing: 172.0,
            proteinPerServing: 20.9,
            carbsPerServing: 0.0,
            fatPerServing: 9.8,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Bacon",
            caloriesPerServing: 407.0,
            proteinPerServing: 12.5,
            carbsPerServing: 0.8,
            fatPerServing: 39.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Alfalfa seeds",
            caloriesPerServing: 23.0,
            proteinPerServing: 4.0,
            carbsPerServing: 2.1,
            fatPerServing: 0.7,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Amaranth leaves",
            caloriesPerServing: 23.0,
            proteinPerServing: 2.5,
            carbsPerServing: 4.0,
            fatPerServing: 0.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Artichokes",
            caloriesPerServing: 53.0,
            proteinPerServing: 2.9,
            carbsPerServing: 11.9,
            fatPerServing: 0.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Asparagus",
            caloriesPerServing: 20.0,
            proteinPerServing: 2.2,
            carbsPerServing: 3.9,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Balsam-pear (bitter gourd)",
            caloriesPerServing: 30.0,
            proteinPerServing: 5.3,
            carbsPerServing: 3.3,
            fatPerServing: 0.7,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Lima beans",
            caloriesPerServing: 113.0,
            proteinPerServing: 6.8,
            carbsPerServing: 20.2,
            fatPerServing: 0.9,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Cowpeas (blackeyes)",
            caloriesPerServing: 97.0,
            proteinPerServing: 3.2,
            carbsPerServing: 20.3,
            fatPerServing: 0.4,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Cowpeas",
            caloriesPerServing: 44.0,
            proteinPerServing: 3.3,
            carbsPerServing: 9.5,
            fatPerServing: 0.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Cress",
            caloriesPerServing: 32.0,
            proteinPerServing: 2.6,
            carbsPerServing: 5.5,
            fatPerServing: 0.7,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Cucumber",
            caloriesPerServing: 15.0,
            proteinPerServing: 0.7,
            carbsPerServing: 3.6,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Edamame",
            caloriesPerServing: 109.0,
            proteinPerServing: 11.2,
            carbsPerServing: 7.6,
            fatPerServing: 4.7,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Endive",
            caloriesPerServing: 17.0,
            proteinPerServing: 1.2,
            carbsPerServing: 3.4,
            fatPerServing: 0.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Escarole",
            caloriesPerServing: 15.0,
            proteinPerServing: 1.1,
            carbsPerServing: 3.1,
            fatPerServing: 0.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Gourd",
            caloriesPerServing: 20.0,
            proteinPerServing: 1.2,
            carbsPerServing: 4.3,
            fatPerServing: 0.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Drumstick leaves",
            caloriesPerServing: 64.0,
            proteinPerServing: 9.4,
            carbsPerServing: 8.3,
            fatPerServing: 1.4,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Pepeao",
            caloriesPerServing: 298.0,
            proteinPerServing: 4.8,
            carbsPerServing: 81.0,
            fatPerServing: 0.4,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Jute",
            caloriesPerServing: 34.0,
            proteinPerServing: 4.7,
            carbsPerServing: 5.8,
            fatPerServing: 0.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Kale",
            caloriesPerServing: 35.0,
            proteinPerServing: 2.9,
            carbsPerServing: 4.4,
            fatPerServing: 1.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Mushrooms",
            caloriesPerServing: 32.0,
            proteinPerServing: 1.5,
            carbsPerServing: 6.9,
            fatPerServing: 0.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Kohlrabi",
            caloriesPerServing: 27.0,
            proteinPerServing: 1.7,
            carbsPerServing: 6.2,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Leeks",
            caloriesPerServing: 31.0,
            proteinPerServing: 0.8,
            carbsPerServing: 7.6,
            fatPerServing: 0.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Lentils",
            caloriesPerServing: 106.0,
            proteinPerServing: 9.0,
            carbsPerServing: 22.1,
            fatPerServing: 0.6,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Lettuce",
            caloriesPerServing: 13.0,
            proteinPerServing: 1.4,
            carbsPerServing: 2.2,
            fatPerServing: 0.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Lotus root",
            caloriesPerServing: 66.0,
            proteinPerServing: 1.6,
            carbsPerServing: 16.0,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Mountain yam",
            caloriesPerServing: 67.0,
            proteinPerServing: 1.3,
            carbsPerServing: 16.3,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Mustard spinach",
            caloriesPerServing: 22.0,
            proteinPerServing: 2.2,
            carbsPerServing: 3.9,
            fatPerServing: 0.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "New zealand spinach",
            caloriesPerServing: 14.0,
            proteinPerServing: 1.5,
            carbsPerServing: 2.5,
            fatPerServing: 0.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Potato wedges",
            caloriesPerServing: 129.0,
            proteinPerServing: 2.7,
            carbsPerServing: 25.5,
            fatPerServing: 2.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Potato flour",
            caloriesPerServing: 357.0,
            proteinPerServing: 6.9,
            carbsPerServing: 83.1,
            fatPerServing: 0.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Pumpkin leaves",
            caloriesPerServing: 21.0,
            proteinPerServing: 2.7,
            carbsPerServing: 3.4,
            fatPerServing: 0.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Pumpkin",
            caloriesPerServing: 26.0,
            proteinPerServing: 1.0,
            carbsPerServing: 6.5,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Radishes",
            caloriesPerServing: 18.0,
            proteinPerServing: 0.6,
            carbsPerServing: 4.1,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Rutabagas",
            caloriesPerServing: 37.0,
            proteinPerServing: 1.1,
            carbsPerServing: 8.6,
            fatPerServing: 0.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Sesbania flower",
            caloriesPerServing: 27.0,
            proteinPerServing: 1.3,
            carbsPerServing: 6.7,
            fatPerServing: 0.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Soybeans",
            caloriesPerServing: 81.0,
            proteinPerServing: 8.5,
            carbsPerServing: 6.5,
            fatPerServing: 4.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Spinach",
            caloriesPerServing: 23.0,
            proteinPerServing: 2.9,
            carbsPerServing: 3.6,
            fatPerServing: 0.4,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Succotash",
            caloriesPerServing: 115.0,
            proteinPerServing: 5.1,
            carbsPerServing: 24.4,
            fatPerServing: 0.8,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Sweet potato",
            caloriesPerServing: 86.0,
            proteinPerServing: 1.6,
            carbsPerServing: 20.1,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Taro",
            caloriesPerServing: 142.0,
            proteinPerServing: 0.5,
            carbsPerServing: 34.6,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Taro leaves",
            caloriesPerServing: 42.0,
            proteinPerServing: 5.0,
            carbsPerServing: 6.7,
            fatPerServing: 0.7,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Taro shoots",
            caloriesPerServing: 11.0,
            proteinPerServing: 0.9,
            carbsPerServing: 2.3,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Arrowroot",
            caloriesPerServing: 65.0,
            proteinPerServing: 4.2,
            carbsPerServing: 13.4,
            fatPerServing: 0.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Chrysanthemum leaves",
            caloriesPerServing: 24.0,
            proteinPerServing: 3.4,
            carbsPerServing: 3.0,
            fatPerServing: 0.6,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Arrowhead",
            caloriesPerServing: 78.0,
            proteinPerServing: 4.5,
            carbsPerServing: 16.1,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Bamboo shoots",
            caloriesPerServing: 11.0,
            proteinPerServing: 1.5,
            carbsPerServing: 1.5,
            fatPerServing: 0.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Mung beans",
            caloriesPerServing: 19.0,
            proteinPerServing: 2.0,
            carbsPerServing: 3.6,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Beets",
            caloriesPerServing: 44.0,
            proteinPerServing: 1.7,
            carbsPerServing: 10.0,
            fatPerServing: 0.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Beet greens",
            caloriesPerServing: 27.0,
            proteinPerServing: 2.6,
            carbsPerServing: 5.5,
            fatPerServing: 0.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Borage",
            caloriesPerServing: 25.0,
            proteinPerServing: 2.1,
            carbsPerServing: 3.5,
            fatPerServing: 0.8,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Broccoli",
            caloriesPerServing: 35.0,
            proteinPerServing: 2.4,
            carbsPerServing: 7.2,
            fatPerServing: 0.4,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Brussels sprouts",
            caloriesPerServing: 36.0,
            proteinPerServing: 2.5,
            carbsPerServing: 7.1,
            fatPerServing: 0.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Cabbage",
            caloriesPerServing: 23.0,
            proteinPerServing: 1.3,
            carbsPerServing: 5.5,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Carrots",
            caloriesPerServing: 25.0,
            proteinPerServing: 0.6,
            carbsPerServing: 5.5,
            fatPerServing: 0.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Cauliflower",
            caloriesPerServing: 23.0,
            proteinPerServing: 1.8,
            carbsPerServing: 4.1,
            fatPerServing: 0.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Chrysanthemum",
            caloriesPerServing: 20.0,
            proteinPerServing: 1.6,
            carbsPerServing: 4.3,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Collards",
            caloriesPerServing: 33.0,
            proteinPerServing: 2.7,
            carbsPerServing: 5.7,
            fatPerServing: 0.7,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Drumstick pods",
            caloriesPerServing: 36.0,
            proteinPerServing: 2.1,
            carbsPerServing: 8.2,
            fatPerServing: 0.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Hyacinth-beans",
            caloriesPerServing: 50.0,
            proteinPerServing: 3.0,
            carbsPerServing: 9.2,
            fatPerServing: 0.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Lambsquarters",
            caloriesPerServing: 32.0,
            proteinPerServing: 3.2,
            carbsPerServing: 5.0,
            fatPerServing: 0.7,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Peppers",
            caloriesPerServing: 18.0,
            proteinPerServing: 0.8,
            carbsPerServing: 3.9,
            fatPerServing: 0.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Tree fern",
            caloriesPerServing: 40.0,
            proteinPerServing: 0.3,
            carbsPerServing: 10.8,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Catsup",
            caloriesPerServing: 101.0,
            proteinPerServing: 1.0,
            carbsPerServing: 27.4,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Pickles",
            caloriesPerServing: 12.0,
            proteinPerServing: 0.5,
            carbsPerServing: 2.4,
            fatPerServing: 0.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Pimento",
            caloriesPerServing: 23.0,
            proteinPerServing: 1.1,
            carbsPerServing: 5.1,
            fatPerServing: 0.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Pickle relish",
            caloriesPerServing: 91.0,
            proteinPerServing: 1.5,
            carbsPerServing: 23.4,
            fatPerServing: 0.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Radicchio",
            caloriesPerServing: 23.0,
            proteinPerServing: 1.4,
            carbsPerServing: 4.5,
            fatPerServing: 0.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Tomatillos",
            caloriesPerServing: 32.0,
            proteinPerServing: 1.0,
            carbsPerServing: 5.8,
            fatPerServing: 1.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Tomatoes",
            caloriesPerServing: 258.0,
            proteinPerServing: 14.1,
            carbsPerServing: 55.8,
            fatPerServing: 3.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Nopales",
            caloriesPerServing: 16.0,
            proteinPerServing: 1.3,
            carbsPerServing: 3.3,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Lemon grass (citronella)",
            caloriesPerServing: 99.0,
            proteinPerServing: 1.8,
            carbsPerServing: 25.3,
            fatPerServing: 0.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Grape leaves",
            caloriesPerServing: 93.0,
            proteinPerServing: 5.6,
            carbsPerServing: 17.3,
            fatPerServing: 2.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Fungi",
            caloriesPerServing: 284.0,
            proteinPerServing: 9.2,
            carbsPerServing: 73.0,
            fatPerServing: 0.7,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Wasabi",
            caloriesPerServing: 109.0,
            proteinPerServing: 4.8,
            carbsPerServing: 23.5,
            fatPerServing: 0.6,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Fiddlehead ferns",
            caloriesPerServing: 34.0,
            proteinPerServing: 4.3,
            carbsPerServing: 5.7,
            fatPerServing: 0.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Nuts",
            caloriesPerServing: 684.0,
            proteinPerServing: 5.3,
            carbsPerServing: 21.5,
            fatPerServing: 69.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Seeds",
            caloriesPerServing: 318.0,
            proteinPerServing: 12.1,
            carbsPerServing: 58.3,
            fatPerServing: 4.6,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Toppings",
            caloriesPerServing: 254.0,
            proteinPerServing: 0.2,
            carbsPerServing: 66.3,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Chewing gum",
            caloriesPerServing: 360.0,
            proteinPerServing: 0.0,
            carbsPerServing: 96.7,
            fatPerServing: 0.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Egg custards",
            caloriesPerServing: 410.0,
            proteinPerServing: 6.9,
            carbsPerServing: 82.8,
            fatPerServing: 6.4,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Cocoa",
            caloriesPerServing: 410.0,
            proteinPerServing: 20.0,
            carbsPerServing: 60.0,
            fatPerServing: 10.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Gelatin desserts",
            caloriesPerServing: 381.0,
            proteinPerServing: 7.8,
            carbsPerServing: 90.5,
            fatPerServing: 0.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Rennin",
            caloriesPerServing: 85.0,
            proteinPerServing: 3.2,
            carbsPerServing: 13.5,
            fatPerServing: 2.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Frostings",
            caloriesPerServing: 397.0,
            proteinPerServing: 1.1,
            carbsPerServing: 63.2,
            fatPerServing: 17.6,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Flan",
            caloriesPerServing: 113.0,
            proteinPerServing: 3.0,
            carbsPerServing: 18.7,
            fatPerServing: 3.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Fruit butters",
            caloriesPerServing: 173.0,
            proteinPerServing: 0.4,
            carbsPerServing: 42.5,
            fatPerServing: 0.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Marmalade",
            caloriesPerServing: 246.0,
            proteinPerServing: 0.3,
            carbsPerServing: 66.3,
            fatPerServing: 0.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Molasses",
            caloriesPerServing: 290.0,
            proteinPerServing: 0.0,
            carbsPerServing: 74.7,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Pudding",
            caloriesPerServing: 109.0,
            proteinPerServing: 0.7,
            carbsPerServing: 24.2,
            fatPerServing: 1.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Sugars",
            caloriesPerServing: 380.0,
            proteinPerServing: 0.1,
            carbsPerServing: 98.1,
            fatPerServing: 0.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Snack",
            caloriesPerServing: 545.0,
            proteinPerServing: 4.6,
            carbsPerServing: 55.4,
            fatPerServing: 35.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Tortilla chips",
            caloriesPerServing: 448.0,
            proteinPerServing: 11.0,
            carbsPerServing: 80.2,
            fatPerServing: 5.7,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Cheese puffs and twists",
            caloriesPerServing: 432.0,
            proteinPerServing: 8.5,
            carbsPerServing: 72.3,
            fatPerServing: 12.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Oat bran",
            caloriesPerServing: 246.0,
            proteinPerServing: 17.3,
            carbsPerServing: 66.2,
            fatPerServing: 7.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Quinoa",
            caloriesPerServing: 368.0,
            proteinPerServing: 14.1,
            carbsPerServing: 64.2,
            fatPerServing: 6.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Rice",
            caloriesPerServing: 112.0,
            proteinPerServing: 2.3,
            carbsPerServing: 23.5,
            fatPerServing: 0.8,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Rye grain",
            caloriesPerServing: 338.0,
            proteinPerServing: 10.3,
            carbsPerServing: 75.9,
            fatPerServing: 1.6,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Rye flour",
            caloriesPerServing: 325.0,
            proteinPerServing: 15.9,
            carbsPerServing: 68.6,
            fatPerServing: 2.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Triticale flour",
            caloriesPerServing: 338.0,
            proteinPerServing: 13.2,
            carbsPerServing: 73.1,
            fatPerServing: 1.8,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Wheat",
            caloriesPerServing: 329.0,
            proteinPerServing: 15.4,
            carbsPerServing: 68.0,
            fatPerServing: 1.9,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Wheat germ",
            caloriesPerServing: 360.0,
            proteinPerServing: 23.1,
            carbsPerServing: 51.8,
            fatPerServing: 9.7,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Wheat flour",
            caloriesPerServing: 340.0,
            proteinPerServing: 13.2,
            carbsPerServing: 72.0,
            fatPerServing: 2.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Wild rice",
            caloriesPerServing: 101.0,
            proteinPerServing: 4.0,
            carbsPerServing: 21.3,
            fatPerServing: 0.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Rice flour",
            caloriesPerServing: 363.0,
            proteinPerServing: 7.2,
            carbsPerServing: 76.5,
            fatPerServing: 2.8,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Pasta",
            caloriesPerServing: 357.0,
            proteinPerServing: 7.5,
            carbsPerServing: 79.3,
            fatPerServing: 2.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Macaroni",
            caloriesPerServing: 367.0,
            proteinPerServing: 13.1,
            carbsPerServing: 74.9,
            fatPerServing: 1.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Noodles",
            caloriesPerServing: 471.0,
            proteinPerServing: 10.9,
            carbsPerServing: 63.6,
            fatPerServing: 21.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Spaghetti",
            caloriesPerServing: 372.0,
            proteinPerServing: 13.3,
            carbsPerServing: 74.8,
            fatPerServing: 1.6,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Wheat flours",
            caloriesPerServing: 361.0,
            proteinPerServing: 12.0,
            carbsPerServing: 72.5,
            fatPerServing: 1.7,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Rice noodles",
            caloriesPerServing: 108.0,
            proteinPerServing: 1.8,
            carbsPerServing: 24.0,
            fatPerServing: 0.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Teff",
            caloriesPerServing: 101.0,
            proteinPerServing: 3.9,
            carbsPerServing: 19.9,
            fatPerServing: 0.7,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Corn grain",
            caloriesPerServing: 365.0,
            proteinPerServing: 9.4,
            carbsPerServing: 74.3,
            fatPerServing: 4.7,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Corn flour",
            caloriesPerServing: 364.0,
            proteinPerServing: 8.8,
            carbsPerServing: 73.9,
            fatPerServing: 5.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Semolina",
            caloriesPerServing: 360.0,
            proteinPerServing: 12.7,
            carbsPerServing: 72.8,
            fatPerServing: 1.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Sorghum flour",
            caloriesPerServing: 359.0,
            proteinPerServing: 8.4,
            carbsPerServing: 76.6,
            fatPerServing: 3.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Rice and vermicelli mix",
            caloriesPerServing: 359.0,
            proteinPerServing: 10.8,
            carbsPerServing: 76.0,
            fatPerServing: 1.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Pasta mix",
            caloriesPerServing: 349.0,
            proteinPerServing: 11.6,
            carbsPerServing: 71.5,
            fatPerServing: 1.9,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Yellow rice with seasoning",
            caloriesPerServing: 343.0,
            proteinPerServing: 7.0,
            carbsPerServing: 74.7,
            fatPerServing: 1.8,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Pizza rolls",
            caloriesPerServing: 328.0,
            proteinPerServing: 8.7,
            carbsPerServing: 50.7,
            fatPerServing: 10.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Spanish rice mix",
            caloriesPerServing: 363.0,
            proteinPerServing: 10.6,
            carbsPerServing: 76.5,
            fatPerServing: 1.6,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Lasagna",
            caloriesPerServing: 145.0,
            proteinPerServing: 5.1,
            carbsPerServing: 21.6,
            fatPerServing: 4.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Turnover",
            caloriesPerServing: 215.0,
            proteinPerServing: 9.4,
            carbsPerServing: 31.9,
            fatPerServing: 5.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Rice mix",
            caloriesPerServing: 142.0,
            proteinPerServing: 3.5,
            carbsPerServing: 26.3,
            fatPerServing: 2.6,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Salisbury steak with gravy",
            caloriesPerServing: 149.0,
            proteinPerServing: 7.0,
            carbsPerServing: 6.8,
            fatPerServing: 10.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Infant formula",
            caloriesPerServing: 516.0,
            proteinPerServing: 10.7,
            carbsPerServing: 57.6,
            fatPerServing: 27.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Agutuk",
            caloriesPerServing: 353.0,
            proteinPerServing: 3.4,
            carbsPerServing: 13.4,
            fatPerServing: 31.8,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Ascidians (tunughnak) (alaska native)",
            caloriesPerServing: 20.0,
            proteinPerServing: 3.8,
            carbsPerServing: 0.0,
            fatPerServing: 0.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Blackberries",
            caloriesPerServing: 52.0,
            proteinPerServing: 0.8,
            carbsPerServing: 9.8,
            fatPerServing: 1.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Stew/soup",
            caloriesPerServing: 41.0,
            proteinPerServing: 3.8,
            carbsPerServing: 4.8,
            fatPerServing: 0.7,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Chiton",
            caloriesPerServing: 83.0,
            proteinPerServing: 17.1,
            carbsPerServing: 0.0,
            fatPerServing: 1.6,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Fireweed",
            caloriesPerServing: 44.0,
            proteinPerServing: 3.0,
            carbsPerServing: 6.3,
            fatPerServing: 0.8,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Agave",
            caloriesPerServing: 135.0,
            proteinPerServing: 1.0,
            carbsPerServing: 32.0,
            fatPerServing: 0.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Cattail",
            caloriesPerServing: 25.0,
            proteinPerServing: 1.2,
            carbsPerServing: 5.1,
            fatPerServing: 0.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Prairie turnips",
            caloriesPerServing: 129.0,
            proteinPerServing: 1.6,
            carbsPerServing: 30.0,
            fatPerServing: 0.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Rose hips",
            caloriesPerServing: 162.0,
            proteinPerServing: 1.6,
            carbsPerServing: 38.2,
            fatPerServing: 0.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Sea lion",
            caloriesPerServing: 137.0,
            proteinPerServing: 22.9,
            carbsPerServing: 0.0,
            fatPerServing: 5.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Piki bread",
            caloriesPerServing: 390.0,
            proteinPerServing: 9.1,
            carbsPerServing: 72.2,
            fatPerServing: 7.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Wocas",
            caloriesPerServing: 34.0,
            proteinPerServing: 0.7,
            carbsPerServing: 7.1,
            fatPerServing: 0.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Tamales",
            caloriesPerServing: 168.0,
            proteinPerServing: 13.2,
            carbsPerServing: 18.3,
            fatPerServing: 4.7,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Applebee's",
            caloriesPerServing: 323.0,
            proteinPerServing: 12.3,
            carbsPerServing: 26.0,
            fatPerServing: 18.9,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "T.g.i. friday's",
            caloriesPerServing: 330.0,
            proteinPerServing: 18.1,
            carbsPerServing: 17.7,
            fatPerServing: 20.8,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Gums",
            caloriesPerServing: 332.0,
            proteinPerServing: 4.6,
            carbsPerServing: 77.3,
            fatPerServing: 0.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Margarine-like",
            caloriesPerServing: 718.0,
            proteinPerServing: 0.9,
            carbsPerServing: 0.6,
            fatPerServing: 80.7,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Jams and preserves",
            caloriesPerServing: 132.0,
            proteinPerServing: 0.3,
            carbsPerServing: 53.4,
            fatPerServing: 0.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Breakfast bars",
            caloriesPerServing: 464.0,
            proteinPerServing: 9.8,
            carbsPerServing: 66.7,
            fatPerServing: 17.6,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Pretzels",
            caloriesPerServing: 338.0,
            proteinPerServing: 8.2,
            carbsPerServing: 69.4,
            fatPerServing: 3.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Luncheon slices",
            caloriesPerServing: 189.0,
            proteinPerServing: 17.8,
            carbsPerServing: 4.4,
            fatPerServing: 11.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Meatballs",
            caloriesPerServing: 197.0,
            proteinPerServing: 21.0,
            carbsPerServing: 8.0,
            fatPerServing: 9.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Vegetarian fillets",
            caloriesPerServing: 290.0,
            proteinPerServing: 23.0,
            carbsPerServing: 9.0,
            fatPerServing: 18.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Sandwich spread",
            caloriesPerServing: 149.0,
            proteinPerServing: 8.0,
            carbsPerServing: 9.0,
            fatPerServing: 9.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Beverage",
            caloriesPerServing: 353.0,
            proteinPerServing: 19.9,
            carbsPerServing: 66.2,
            fatPerServing: 1.4,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Tomato sauce",
            caloriesPerServing: 24.0,
            proteinPerServing: 1.2,
            carbsPerServing: 5.3,
            fatPerServing: 0.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Cheese spread",
            caloriesPerServing: 295.0,
            proteinPerServing: 7.1,
            carbsPerServing: 3.5,
            fatPerServing: 28.6,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Soybean",
            caloriesPerServing: 151.0,
            proteinPerServing: 12.5,
            carbsPerServing: 6.9,
            fatPerServing: 8.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Vegetables",
            caloriesPerServing: 37.0,
            proteinPerServing: 1.4,
            carbsPerServing: 7.3,
            fatPerServing: 0.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Litchis",
            caloriesPerServing: 66.0,
            proteinPerServing: 0.8,
            carbsPerServing: 16.5,
            fatPerServing: 0.4,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Loganberries",
            caloriesPerServing: 55.0,
            proteinPerServing: 1.5,
            carbsPerServing: 13.0,
            fatPerServing: 0.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Longans",
            caloriesPerServing: 60.0,
            proteinPerServing: 1.3,
            carbsPerServing: 15.1,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Mangosteen",
            caloriesPerServing: 73.0,
            proteinPerServing: 0.4,
            carbsPerServing: 17.9,
            fatPerServing: 0.6,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Mango",
            caloriesPerServing: 319.0,
            proteinPerServing: 2.5,
            carbsPerServing: 78.6,
            fatPerServing: 1.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Melons",
            caloriesPerServing: 34.0,
            proteinPerServing: 0.8,
            carbsPerServing: 8.2,
            fatPerServing: 0.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Olives",
            caloriesPerServing: 116.0,
            proteinPerServing: 0.8,
            carbsPerServing: 6.0,
            fatPerServing: 10.9,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Oranges",
            caloriesPerServing: 47.0,
            proteinPerServing: 0.9,
            carbsPerServing: 11.8,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Orange peel",
            caloriesPerServing: 97.0,
            proteinPerServing: 1.5,
            carbsPerServing: 25.0,
            fatPerServing: 0.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Orange-grapefruit juice",
            caloriesPerServing: 43.0,
            proteinPerServing: 0.6,
            carbsPerServing: 10.3,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Papaya nectar",
            caloriesPerServing: 57.0,
            proteinPerServing: 0.2,
            carbsPerServing: 14.5,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Passion-fruit",
            caloriesPerServing: 97.0,
            proteinPerServing: 2.2,
            carbsPerServing: 23.4,
            fatPerServing: 0.7,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Passion-fruit juice",
            caloriesPerServing: 51.0,
            proteinPerServing: 0.4,
            carbsPerServing: 13.6,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Pitanga",
            caloriesPerServing: 33.0,
            proteinPerServing: 0.8,
            carbsPerServing: 7.5,
            fatPerServing: 0.4,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Pomegranates",
            caloriesPerServing: 83.0,
            proteinPerServing: 1.7,
            carbsPerServing: 18.7,
            fatPerServing: 1.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Corn with red and green peppers",
            caloriesPerServing: 75.0,
            proteinPerServing: 2.3,
            carbsPerServing: 18.2,
            fatPerServing: 0.6,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Cornsalad",
            caloriesPerServing: 21.0,
            proteinPerServing: 2.0,
            carbsPerServing: 3.6,
            fatPerServing: 0.4,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Yardlong bean",
            caloriesPerServing: 47.0,
            proteinPerServing: 2.8,
            carbsPerServing: 8.3,
            fatPerServing: 0.4,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Dandelion greens",
            caloriesPerServing: 45.0,
            proteinPerServing: 2.7,
            carbsPerServing: 9.2,
            fatPerServing: 0.7,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Eggplant",
            caloriesPerServing: 25.0,
            proteinPerServing: 1.0,
            carbsPerServing: 5.9,
            fatPerServing: 0.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Garlic",
            caloriesPerServing: 149.0,
            proteinPerServing: 6.4,
            carbsPerServing: 33.1,
            fatPerServing: 0.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Ginger root",
            caloriesPerServing: 80.0,
            proteinPerServing: 1.8,
            carbsPerServing: 17.8,
            fatPerServing: 0.8,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Jerusalem-artichokes",
            caloriesPerServing: 73.0,
            proteinPerServing: 2.0,
            carbsPerServing: 17.4,
            fatPerServing: 0.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Jew's ear",
            caloriesPerServing: 25.0,
            proteinPerServing: 0.5,
            carbsPerServing: 6.8,
            fatPerServing: 0.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Kanpyo",
            caloriesPerServing: 258.0,
            proteinPerServing: 8.6,
            carbsPerServing: 65.0,
            fatPerServing: 0.6,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Mustard greens",
            caloriesPerServing: 27.0,
            proteinPerServing: 2.9,
            carbsPerServing: 4.7,
            fatPerServing: 0.4,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Okra",
            caloriesPerServing: 33.0,
            proteinPerServing: 1.9,
            carbsPerServing: 7.5,
            fatPerServing: 0.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Potato salad",
            caloriesPerServing: 143.0,
            proteinPerServing: 2.7,
            carbsPerServing: 11.2,
            fatPerServing: 8.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Pumpkin flowers",
            caloriesPerServing: 15.0,
            proteinPerServing: 1.0,
            carbsPerServing: 3.3,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Pumpkin pie mix",
            caloriesPerServing: 104.0,
            proteinPerServing: 1.1,
            carbsPerServing: 26.4,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Purslane",
            caloriesPerServing: 20.0,
            proteinPerServing: 2.0,
            carbsPerServing: 3.4,
            fatPerServing: 0.4,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Salsify",
            caloriesPerServing: 82.0,
            proteinPerServing: 3.3,
            carbsPerServing: 18.6,
            fatPerServing: 0.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Sauerkraut",
            caloriesPerServing: 19.0,
            proteinPerServing: 0.9,
            carbsPerServing: 4.3,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Water convolvulus",
            caloriesPerServing: 19.0,
            proteinPerServing: 2.6,
            carbsPerServing: 3.1,
            fatPerServing: 0.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Sweet potato leaves",
            caloriesPerServing: 42.0,
            proteinPerServing: 2.5,
            carbsPerServing: 8.8,
            fatPerServing: 0.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Broadbeans",
            caloriesPerServing: 62.0,
            proteinPerServing: 4.8,
            carbsPerServing: 10.1,
            fatPerServing: 0.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Burdock root",
            caloriesPerServing: 88.0,
            proteinPerServing: 2.1,
            carbsPerServing: 21.1,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Butterbur",
            caloriesPerServing: 8.0,
            proteinPerServing: 0.2,
            carbsPerServing: 2.2,
            fatPerServing: 0.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Cardoon",
            caloriesPerServing: 20.0,
            proteinPerServing: 0.8,
            carbsPerServing: 4.7,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Celeriac",
            caloriesPerServing: 27.0,
            proteinPerServing: 1.0,
            carbsPerServing: 5.9,
            fatPerServing: 0.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Celery",
            caloriesPerServing: 18.0,
            proteinPerServing: 0.8,
            carbsPerServing: 4.0,
            fatPerServing: 0.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Chard",
            caloriesPerServing: 20.0,
            proteinPerServing: 1.9,
            carbsPerServing: 4.1,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Chayote",
            caloriesPerServing: 22.0,
            proteinPerServing: 0.6,
            carbsPerServing: 4.5,
            fatPerServing: 0.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Yambean (jicama)",
            caloriesPerServing: 36.0,
            proteinPerServing: 0.7,
            carbsPerServing: 8.2,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Dock",
            caloriesPerServing: 20.0,
            proteinPerServing: 1.8,
            carbsPerServing: 2.9,
            fatPerServing: 0.6,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Mushroom",
            caloriesPerServing: 22.0,
            proteinPerServing: 3.1,
            carbsPerServing: 3.3,
            fatPerServing: 0.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Fennel",
            caloriesPerServing: 31.0,
            proteinPerServing: 1.2,
            carbsPerServing: 7.3,
            fatPerServing: 0.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Arugula",
            caloriesPerServing: 25.0,
            proteinPerServing: 2.6,
            carbsPerServing: 3.6,
            fatPerServing: 0.7,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Pepper",
            caloriesPerServing: 27.0,
            proteinPerServing: 1.7,
            carbsPerServing: 5.3,
            fatPerServing: 0.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Epazote",
            caloriesPerServing: 32.0,
            proteinPerServing: 0.3,
            carbsPerServing: 7.4,
            fatPerServing: 0.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Malabar spinach",
            caloriesPerServing: 23.0,
            proteinPerServing: 3.0,
            carbsPerServing: 2.7,
            fatPerServing: 0.8,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Yautia (tannier)",
            caloriesPerServing: 98.0,
            proteinPerServing: 1.5,
            carbsPerServing: 23.6,
            fatPerServing: 0.4,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Gelatins",
            caloriesPerServing: 335.0,
            proteinPerServing: 85.6,
            carbsPerServing: 0.0,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Honey",
            caloriesPerServing: 304.0,
            proteinPerServing: 0.3,
            carbsPerServing: 82.4,
            fatPerServing: 0.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Cornstarch",
            caloriesPerServing: 381.0,
            proteinPerServing: 0.3,
            carbsPerServing: 91.3,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Couscous",
            caloriesPerServing: 376.0,
            proteinPerServing: 12.8,
            carbsPerServing: 77.4,
            fatPerServing: 0.6,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Hominy",
            caloriesPerServing: 72.0,
            proteinPerServing: 1.5,
            carbsPerServing: 14.3,
            fatPerServing: 0.9,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Oats (includes foods for usda's food distribution program)",
            caloriesPerServing: 389.0,
            proteinPerServing: 16.9,
            carbsPerServing: 66.3,
            fatPerServing: 6.9,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Rice bran",
            caloriesPerServing: 316.0,
            proteinPerServing: 13.3,
            carbsPerServing: 49.7,
            fatPerServing: 20.9,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Sorghum grain",
            caloriesPerServing: 329.0,
            proteinPerServing: 10.6,
            carbsPerServing: 72.1,
            fatPerServing: 3.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Tapioca",
            caloriesPerServing: 358.0,
            proteinPerServing: 0.2,
            carbsPerServing: 88.7,
            fatPerServing: 0.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Triticale",
            caloriesPerServing: 336.0,
            proteinPerServing: 13.1,
            carbsPerServing: 72.1,
            fatPerServing: 2.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Wheat bran",
            caloriesPerServing: 216.0,
            proteinPerServing: 15.6,
            carbsPerServing: 64.5,
            fatPerServing: 4.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Barley flour or meal",
            caloriesPerServing: 345.0,
            proteinPerServing: 10.5,
            carbsPerServing: 74.5,
            fatPerServing: 1.6,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Barley malt flour",
            caloriesPerServing: 361.0,
            proteinPerServing: 10.3,
            carbsPerServing: 78.3,
            fatPerServing: 1.8,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Oat flour",
            caloriesPerServing: 404.0,
            proteinPerServing: 14.7,
            carbsPerServing: 65.7,
            fatPerServing: 9.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Spelt",
            caloriesPerServing: 338.0,
            proteinPerServing: 14.6,
            carbsPerServing: 70.2,
            fatPerServing: 2.4,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Vegetable juice",
            caloriesPerServing: 31.0,
            proteinPerServing: 0.5,
            carbsPerServing: 8.1,
            fatPerServing: 0.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Macaroni and cheese",
            caloriesPerServing: 334.0,
            proteinPerServing: 12.7,
            carbsPerServing: 46.7,
            fatPerServing: 10.7,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Taquitos",
            caloriesPerServing: 284.0,
            proteinPerServing: 9.2,
            carbsPerServing: 33.6,
            fatPerServing: 12.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Potsticker or wonton",
            caloriesPerServing: 136.0,
            proteinPerServing: 8.3,
            carbsPerServing: 13.3,
            fatPerServing: 5.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Macaroni or noodles with cheese",
            caloriesPerServing: 297.0,
            proteinPerServing: 13.1,
            carbsPerServing: 52.1,
            fatPerServing: 4.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Dumpling",
            caloriesPerServing: 195.0,
            proteinPerServing: 5.3,
            carbsPerServing: 29.6,
            fatPerServing: 6.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Hungry man",
            caloriesPerServing: 136.0,
            proteinPerServing: 8.0,
            carbsPerServing: 7.0,
            fatPerServing: 8.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Banquet",
            caloriesPerServing: 155.0,
            proteinPerServing: 6.9,
            carbsPerServing: 7.0,
            fatPerServing: 11.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Jimmy dean",
            caloriesPerServing: 328.0,
            proteinPerServing: 9.3,
            carbsPerServing: 21.1,
            fatPerServing: 22.9,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Bear",
            caloriesPerServing: 155.0,
            proteinPerServing: 20.1,
            carbsPerServing: 0.0,
            fatPerServing: 8.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Cloudberries",
            caloriesPerServing: 51.0,
            proteinPerServing: 2.4,
            carbsPerServing: 8.6,
            fatPerServing: 0.8,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Cockles",
            caloriesPerServing: 79.0,
            proteinPerServing: 13.5,
            carbsPerServing: 4.7,
            fatPerServing: 0.7,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Cranberries",
            caloriesPerServing: 55.0,
            proteinPerServing: 1.1,
            carbsPerServing: 12.3,
            fatPerServing: 0.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Cranberry",
            caloriesPerServing: 55.0,
            proteinPerServing: 0.4,
            carbsPerServing: 12.2,
            fatPerServing: 0.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Huckleberries",
            caloriesPerServing: 37.0,
            proteinPerServing: 0.4,
            carbsPerServing: 8.7,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Tennis bread",
            caloriesPerServing: 258.0,
            proteinPerServing: 9.0,
            carbsPerServing: 53.3,
            fatPerServing: 1.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Salmon",
            caloriesPerServing: 345.0,
            proteinPerServing: 60.6,
            carbsPerServing: 0.0,
            fatPerServing: 11.4,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Stinging nettles",
            caloriesPerServing: 42.0,
            proteinPerServing: 2.7,
            carbsPerServing: 7.5,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Pinon nuts",
            caloriesPerServing: 541.0,
            proteinPerServing: 7.4,
            carbsPerServing: 51.1,
            fatPerServing: 34.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Hazelnuts",
            caloriesPerServing: 628.0,
            proteinPerServing: 14.9,
            carbsPerServing: 23.0,
            fatPerServing: 53.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Peanut butter",
            caloriesPerServing: 590.0,
            proteinPerServing: 24.0,
            carbsPerServing: 21.8,
            fatPerServing: 49.9,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Fluid replacement",
            caloriesPerServing: 10.0,
            proteinPerServing: 0.0,
            carbsPerServing: 2.5,
            fatPerServing: 0.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Vermicelli",
            caloriesPerServing: 331.0,
            proteinPerServing: 0.1,
            carbsPerServing: 82.3,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Vegetarian meatloaf or patties",
            caloriesPerServing: 197.0,
            proteinPerServing: 21.0,
            carbsPerServing: 8.0,
            fatPerServing: 9.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Bacon bits",
            caloriesPerServing: 476.0,
            proteinPerServing: 32.0,
            carbsPerServing: 28.6,
            fatPerServing: 25.9,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Butter replacement",
            caloriesPerServing: 373.0,
            proteinPerServing: 2.0,
            carbsPerServing: 89.0,
            fatPerServing: 1.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Yogurt",
            caloriesPerServing: 95.0,
            proteinPerServing: 4.4,
            carbsPerServing: 19.0,
            fatPerServing: 0.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Whipped cream substitute",
            caloriesPerServing: 100.0,
            proteinPerServing: 0.9,
            carbsPerServing: 10.6,
            fatPerServing: 6.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Quail",
            caloriesPerServing: 227.0,
            proteinPerServing: 25.1,
            carbsPerServing: 0.0,
            fatPerServing: 14.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Pheasant",
            caloriesPerServing: 239.0,
            proteinPerServing: 32.4,
            carbsPerServing: 0.0,
            fatPerServing: 12.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Eggs",
            caloriesPerServing: 131.0,
            proteinPerServing: 13.1,
            carbsPerServing: 7.5,
            fatPerServing: 5.6,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Dove",
            caloriesPerServing: 213.0,
            proteinPerServing: 23.9,
            carbsPerServing: 0.0,
            fatPerServing: 13.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Loquats",
            caloriesPerServing: 47.0,
            proteinPerServing: 0.4,
            carbsPerServing: 12.1,
            fatPerServing: 0.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Mammy-apple",
            caloriesPerServing: 51.0,
            proteinPerServing: 0.5,
            carbsPerServing: 12.5,
            fatPerServing: 0.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Mangos",
            caloriesPerServing: 60.0,
            proteinPerServing: 0.8,
            carbsPerServing: 15.0,
            fatPerServing: 0.4,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Melon balls",
            caloriesPerServing: 33.0,
            proteinPerServing: 0.8,
            carbsPerServing: 7.9,
            fatPerServing: 0.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Mulberries",
            caloriesPerServing: 43.0,
            proteinPerServing: 1.4,
            carbsPerServing: 9.8,
            fatPerServing: 0.4,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Nectarines",
            caloriesPerServing: 44.0,
            proteinPerServing: 1.1,
            carbsPerServing: 10.6,
            fatPerServing: 0.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Oheloberries",
            caloriesPerServing: 28.0,
            proteinPerServing: 0.4,
            carbsPerServing: 6.8,
            fatPerServing: 0.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Tangerine juice",
            caloriesPerServing: 43.0,
            proteinPerServing: 0.5,
            carbsPerServing: 10.1,
            fatPerServing: 0.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Papayas",
            caloriesPerServing: 43.0,
            proteinPerServing: 0.5,
            carbsPerServing: 10.8,
            fatPerServing: 0.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Papaya",
            caloriesPerServing: 206.0,
            proteinPerServing: 0.1,
            carbsPerServing: 55.8,
            fatPerServing: 0.6,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Persimmons",
            caloriesPerServing: 70.0,
            proteinPerServing: 0.6,
            carbsPerServing: 18.6,
            fatPerServing: 0.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Cassava",
            caloriesPerServing: 160.0,
            proteinPerServing: 1.4,
            carbsPerServing: 38.1,
            fatPerServing: 0.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Celtuce",
            caloriesPerServing: 18.0,
            proteinPerServing: 0.8,
            carbsPerServing: 3.6,
            fatPerServing: 0.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Chicory greens",
            caloriesPerServing: 23.0,
            proteinPerServing: 1.7,
            carbsPerServing: 4.7,
            fatPerServing: 0.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Chicory roots",
            caloriesPerServing: 72.0,
            proteinPerServing: 1.4,
            carbsPerServing: 17.5,
            fatPerServing: 0.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Chives",
            caloriesPerServing: 30.0,
            proteinPerServing: 3.3,
            carbsPerServing: 4.3,
            fatPerServing: 0.7,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Coriander (cilantro) leaves",
            caloriesPerServing: 23.0,
            proteinPerServing: 2.1,
            carbsPerServing: 3.7,
            fatPerServing: 0.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Onions",
            caloriesPerServing: 40.0,
            proteinPerServing: 1.1,
            carbsPerServing: 9.3,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Parsnips",
            caloriesPerServing: 71.0,
            proteinPerServing: 1.3,
            carbsPerServing: 17.0,
            fatPerServing: 0.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Peas",
            caloriesPerServing: 42.0,
            proteinPerServing: 2.8,
            carbsPerServing: 7.5,
            fatPerServing: 0.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Peas and carrots",
            caloriesPerServing: 48.0,
            proteinPerServing: 3.1,
            carbsPerServing: 10.1,
            fatPerServing: 0.4,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Peas and onions",
            caloriesPerServing: 51.0,
            proteinPerServing: 3.3,
            carbsPerServing: 8.6,
            fatPerServing: 0.4,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Pigeonpeas",
            caloriesPerServing: 136.0,
            proteinPerServing: 7.2,
            carbsPerServing: 23.9,
            fatPerServing: 1.6,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Potato puffs",
            caloriesPerServing: 178.0,
            proteinPerServing: 1.9,
            carbsPerServing: 24.8,
            fatPerServing: 8.7,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Tomato products",
            caloriesPerServing: 24.0,
            proteinPerServing: 1.2,
            carbsPerServing: 5.3,
            fatPerServing: 0.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Turnips",
            caloriesPerServing: 22.0,
            proteinPerServing: 0.7,
            carbsPerServing: 5.1,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Turnip greens and turnips",
            caloriesPerServing: 35.0,
            proteinPerServing: 3.0,
            carbsPerServing: 4.8,
            fatPerServing: 0.4,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Vegetable juice cocktail",
            caloriesPerServing: 22.0,
            proteinPerServing: 0.9,
            carbsPerServing: 3.9,
            fatPerServing: 0.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Waterchestnuts",
            caloriesPerServing: 97.0,
            proteinPerServing: 1.4,
            carbsPerServing: 23.9,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Watercress",
            caloriesPerServing: 11.0,
            proteinPerServing: 2.3,
            carbsPerServing: 1.3,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Waxgourd",
            caloriesPerServing: 13.0,
            proteinPerServing: 0.4,
            carbsPerServing: 3.0,
            fatPerServing: 0.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Winged bean tuber",
            caloriesPerServing: 148.0,
            proteinPerServing: 11.6,
            carbsPerServing: 28.1,
            fatPerServing: 0.9,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Yam",
            caloriesPerServing: 118.0,
            proteinPerServing: 1.5,
            carbsPerServing: 27.9,
            fatPerServing: 0.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Eppaw",
            caloriesPerServing: 150.0,
            proteinPerServing: 4.6,
            carbsPerServing: 31.7,
            fatPerServing: 1.8,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Shallots",
            caloriesPerServing: 348.0,
            proteinPerServing: 12.3,
            carbsPerServing: 80.7,
            fatPerServing: 0.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Potato pancakes",
            caloriesPerServing: 268.0,
            proteinPerServing: 6.1,
            carbsPerServing: 27.8,
            fatPerServing: 14.8,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Radish seeds",
            caloriesPerServing: 43.0,
            proteinPerServing: 3.8,
            carbsPerServing: 3.6,
            fatPerServing: 2.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Potato chips",
            caloriesPerServing: 487.0,
            proteinPerServing: 7.1,
            carbsPerServing: 67.8,
            fatPerServing: 20.8,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Chocolate",
            caloriesPerServing: 546.0,
            proteinPerServing: 4.9,
            carbsPerServing: 61.2,
            fatPerServing: 31.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Sweetener",
            caloriesPerServing: 310.0,
            proteinPerServing: 0.1,
            carbsPerServing: 76.4,
            fatPerServing: 0.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Barley",
            caloriesPerServing: 354.0,
            proteinPerServing: 12.5,
            carbsPerServing: 73.5,
            fatPerServing: 2.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Buckwheat",
            caloriesPerServing: 343.0,
            proteinPerServing: 13.2,
            carbsPerServing: 71.5,
            fatPerServing: 3.4,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Bulgur",
            caloriesPerServing: 83.0,
            proteinPerServing: 3.1,
            carbsPerServing: 18.6,
            fatPerServing: 0.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Corn bran",
            caloriesPerServing: 224.0,
            proteinPerServing: 8.4,
            carbsPerServing: 85.6,
            fatPerServing: 0.9,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Fast food",
            caloriesPerServing: 370.0,
            proteinPerServing: 7.1,
            carbsPerServing: 42.8,
            fatPerServing: 18.9,
            servingSizeDescription: "100g"
        ),
    
        CommonFood(
            name: "Pizza hut 14\" pepperoni pizza",
            caloriesPerServing: 333.0,
            proteinPerServing: 14.1,
            carbsPerServing: 32.7,
            fatPerServing: 16.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Domino's 14\" pepperoni pizza",
            caloriesPerServing: 328.0,
            proteinPerServing: 13.9,
            carbsPerServing: 25.4,
            fatPerServing: 19.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Domino's 14\" sausage pizza",
            caloriesPerServing: 319.0,
            proteinPerServing: 12.8,
            carbsPerServing: 25.3,
            fatPerServing: 18.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Pizza hut 14\" sausage pizza",
            caloriesPerServing: 287.0,
            proteinPerServing: 11.1,
            carbsPerServing: 29.6,
            fatPerServing: 13.8,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Broccoli raab",
            caloriesPerServing: 22.0,
            proteinPerServing: 3.2,
            carbsPerServing: 2.9,
            fatPerServing: 0.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Chicory",
            caloriesPerServing: 17.0,
            proteinPerServing: 0.9,
            carbsPerServing: 4.0,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Onion rings",
            caloriesPerServing: 258.0,
            proteinPerServing: 3.1,
            carbsPerServing: 30.5,
            fatPerServing: 14.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Parsley",
            caloriesPerServing: 36.0,
            proteinPerServing: 3.0,
            carbsPerServing: 6.3,
            fatPerServing: 0.8,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Poi",
            caloriesPerServing: 112.0,
            proteinPerServing: 0.4,
            carbsPerServing: 27.2,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Pokeberry shoots",
            caloriesPerServing: 23.0,
            proteinPerServing: 2.6,
            carbsPerServing: 3.7,
            fatPerServing: 0.4,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Tomato juice",
            caloriesPerServing: 17.0,
            proteinPerServing: 0.8,
            carbsPerServing: 3.5,
            fatPerServing: 0.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Tomato powder",
            caloriesPerServing: 302.0,
            proteinPerServing: 12.9,
            carbsPerServing: 74.7,
            fatPerServing: 0.4,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Vinespinach",
            caloriesPerServing: 19.0,
            proteinPerServing: 1.8,
            carbsPerServing: 3.4,
            fatPerServing: 0.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Winged beans",
            caloriesPerServing: 49.0,
            proteinPerServing: 7.0,
            carbsPerServing: 4.3,
            fatPerServing: 0.9,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Winged bean leaves",
            caloriesPerServing: 74.0,
            proteinPerServing: 5.8,
            carbsPerServing: 14.1,
            fatPerServing: 1.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Carrot juice",
            caloriesPerServing: 40.0,
            proteinPerServing: 0.9,
            carbsPerServing: 9.3,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Corn pudding",
            caloriesPerServing: 131.0,
            proteinPerServing: 4.4,
            carbsPerServing: 17.0,
            fatPerServing: 5.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Spinach souffle",
            caloriesPerServing: 172.0,
            proteinPerServing: 7.9,
            carbsPerServing: 5.9,
            fatPerServing: 12.9,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Carrot",
            caloriesPerServing: 341.0,
            proteinPerServing: 8.1,
            carbsPerServing: 79.6,
            fatPerServing: 1.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Winged bean",
            caloriesPerServing: 37.0,
            proteinPerServing: 5.3,
            carbsPerServing: 3.2,
            fatPerServing: 0.7,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Sugar",
            caloriesPerServing: 399.0,
            proteinPerServing: 0.0,
            carbsPerServing: 99.8,
            fatPerServing: 0.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Amaranth grain",
            caloriesPerServing: 371.0,
            proteinPerServing: 13.6,
            carbsPerServing: 65.2,
            fatPerServing: 7.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Arrowroot flour",
            caloriesPerServing: 357.0,
            proteinPerServing: 0.3,
            carbsPerServing: 88.2,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Buckwheat groats",
            caloriesPerServing: 346.0,
            proteinPerServing: 11.7,
            carbsPerServing: 75.0,
            fatPerServing: 2.7,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Buckwheat flour",
            caloriesPerServing: 335.0,
            proteinPerServing: 12.6,
            carbsPerServing: 70.6,
            fatPerServing: 3.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Wend'ys",
            caloriesPerServing: 278.0,
            proteinPerServing: 11.7,
            carbsPerServing: 26.4,
            fatPerServing: 13.9,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Pizza hut 14\" cheese pizza",
            caloriesPerServing: 274.0,
            proteinPerServing: 12.2,
            carbsPerServing: 30.0,
            fatPerServing: 11.6,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Pizza hut",
            caloriesPerServing: 343.0,
            proteinPerServing: 12.2,
            carbsPerServing: 44.5,
            fatPerServing: 12.9,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Arby's",
            caloriesPerServing: 242.0,
            proteinPerServing: 15.2,
            carbsPerServing: 22.2,
            fatPerServing: 10.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Cheese food",
            caloriesPerServing: 331.0,
            proteinPerServing: 19.7,
            carbsPerServing: 8.3,
            fatPerServing: 24.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Cream",
            caloriesPerServing: 195.0,
            proteinPerServing: 3.0,
            carbsPerServing: 3.7,
            fatPerServing: 19.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Dessert topping",
            caloriesPerServing: 577.0,
            proteinPerServing: 4.9,
            carbsPerServing: 52.5,
            fatPerServing: 39.9,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Sour cream",
            caloriesPerServing: 208.0,
            proteinPerServing: 2.4,
            carbsPerServing: 6.6,
            fatPerServing: 19.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Milk shakes",
            caloriesPerServing: 119.0,
            proteinPerServing: 3.0,
            carbsPerServing: 21.1,
            fatPerServing: 2.7,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Whey",
            caloriesPerServing: 24.0,
            proteinPerServing: 0.8,
            carbsPerServing: 5.1,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Milk dessert bar",
            caloriesPerServing: 147.0,
            proteinPerServing: 4.4,
            carbsPerServing: 32.0,
            fatPerServing: 1.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Nutritional supplement for people with diabetes",
            caloriesPerServing: 88.0,
            proteinPerServing: 4.4,
            carbsPerServing: 11.9,
            fatPerServing: 3.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Egg",
            caloriesPerServing: 138.0,
            proteinPerServing: 11.0,
            carbsPerServing: 0.8,
            fatPerServing: 10.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Kefir",
            caloriesPerServing: 43.0,
            proteinPerServing: 3.8,
            carbsPerServing: 4.8,
            fatPerServing: 1.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Ice cream",
            caloriesPerServing: 265.0,
            proteinPerServing: 5.3,
            carbsPerServing: 40.0,
            fatPerServing: 9.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Spices",
            caloriesPerServing: 313.0,
            proteinPerServing: 7.6,
            carbsPerServing: 75.0,
            fatPerServing: 8.4,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Toddler formula",
            caloriesPerServing: 505.0,
            proteinPerServing: 12.9,
            carbsPerServing: 52.8,
            fatPerServing: 26.9,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Shortening",
            caloriesPerServing: 884.0,
            proteinPerServing: 0.0,
            carbsPerServing: 0.0,
            fatPerServing: 100.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Margarine",
            caloriesPerServing: 719.0,
            proteinPerServing: 0.9,
            carbsPerServing: 0.9,
            fatPerServing: 80.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Margarine-like spread",
            caloriesPerServing: 357.0,
            proteinPerServing: 0.0,
            carbsPerServing: 5.7,
            fatPerServing: 38.7,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Margarine-like vegetable-oil spread",
            caloriesPerServing: 535.0,
            proteinPerServing: 0.6,
            carbsPerServing: 0.0,
            fatPerServing: 59.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Dressing",
            caloriesPerServing: 169.0,
            proteinPerServing: 1.1,
            carbsPerServing: 38.4,
            fatPerServing: 1.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Squab",
            caloriesPerServing: 142.0,
            proteinPerServing: 17.5,
            carbsPerServing: 0.0,
            fatPerServing: 7.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Pate de foie gras",
            caloriesPerServing: 462.0,
            proteinPerServing: 11.4,
            carbsPerServing: 4.7,
            fatPerServing: 43.8,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Turkey sticks",
            caloriesPerServing: 279.0,
            proteinPerServing: 14.2,
            carbsPerServing: 17.0,
            fatPerServing: 16.9,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Poultry",
            caloriesPerServing: 272.0,
            proteinPerServing: 11.4,
            carbsPerServing: 0.0,
            fatPerServing: 24.7,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Sauce",
            caloriesPerServing: 89.0,
            proteinPerServing: 5.9,
            carbsPerServing: 15.6,
            fatPerServing: 0.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Gravy",
            caloriesPerServing: 16.0,
            proteinPerServing: 1.2,
            carbsPerServing: 2.5,
            fatPerServing: 0.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Smart soup",
            caloriesPerServing: 57.0,
            proteinPerServing: 3.3,
            carbsPerServing: 10.5,
            fatPerServing: 0.9,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Eggnog",
            caloriesPerServing: 88.0,
            proteinPerServing: 4.5,
            carbsPerServing: 8.1,
            fatPerServing: 4.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Sour dressing",
            caloriesPerServing: 178.0,
            proteinPerServing: 3.2,
            carbsPerServing: 4.7,
            fatPerServing: 16.6,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Milk substitutes",
            caloriesPerServing: 61.0,
            proteinPerServing: 1.8,
            carbsPerServing: 6.2,
            fatPerServing: 3.4,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Cheese product",
            caloriesPerServing: 307.0,
            proteinPerServing: 16.1,
            carbsPerServing: 8.8,
            fatPerServing: 23.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Ice cream bar",
            caloriesPerServing: 358.0,
            proteinPerServing: 2.1,
            carbsPerServing: 37.1,
            fatPerServing: 25.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Ice cream sundae cone",
            caloriesPerServing: 254.0,
            proteinPerServing: 3.0,
            carbsPerServing: 28.9,
            fatPerServing: 14.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Light ice cream",
            caloriesPerServing: 165.0,
            proteinPerServing: 1.5,
            carbsPerServing: 32.8,
            fatPerServing: 3.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Butter",
            caloriesPerServing: 900.0,
            proteinPerServing: 0.0,
            carbsPerServing: 0.0,
            fatPerServing: 100.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Zwieback",
            caloriesPerServing: 426.0,
            proteinPerServing: 10.1,
            carbsPerServing: 74.2,
            fatPerServing: 9.7,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Fat",
            caloriesPerServing: 902.0,
            proteinPerServing: 0.0,
            carbsPerServing: 0.0,
            fatPerServing: 100.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Lard",
            caloriesPerServing: 902.0,
            proteinPerServing: 0.0,
            carbsPerServing: 0.0,
            fatPerServing: 100.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Vegetable oil",
            caloriesPerServing: 862.0,
            proteinPerServing: 0.0,
            carbsPerServing: 0.0,
            fatPerServing: 100.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Turkey and gravy",
            caloriesPerServing: 67.0,
            proteinPerServing: 5.9,
            carbsPerServing: 4.6,
            fatPerServing: 2.6,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Turkey breast",
            caloriesPerServing: 126.0,
            proteinPerServing: 22.2,
            carbsPerServing: 0.0,
            fatPerServing: 3.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Turkey thigh",
            caloriesPerServing: 157.0,
            proteinPerServing: 18.8,
            carbsPerServing: 0.0,
            fatPerServing: 8.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Turkey roast",
            caloriesPerServing: 120.0,
            proteinPerServing: 17.6,
            carbsPerServing: 6.4,
            fatPerServing: 2.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Chicken patty",
            caloriesPerServing: 292.0,
            proteinPerServing: 14.3,
            carbsPerServing: 13.6,
            fatPerServing: 20.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Chicken breast tenders",
            caloriesPerServing: 252.0,
            proteinPerServing: 16.4,
            carbsPerServing: 17.6,
            fatPerServing: 12.9,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Campbell's",
            caloriesPerServing: 47.0,
            proteinPerServing: 2.4,
            carbsPerServing: 6.0,
            fatPerServing: 1.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Barbecue loaf",
            caloriesPerServing: 173.0,
            proteinPerServing: 15.8,
            carbsPerServing: 6.4,
            fatPerServing: 8.9,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Fish broth",
            caloriesPerServing: 16.0,
            proteinPerServing: 2.0,
            carbsPerServing: 0.4,
            fatPerServing: 0.6,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Potato soup",
            caloriesPerServing: 343.0,
            proteinPerServing: 9.2,
            carbsPerServing: 76.1,
            fatPerServing: 3.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Beerwurst",
            caloriesPerServing: 238.0,
            proteinPerServing: 14.2,
            carbsPerServing: 2.1,
            fatPerServing: 18.8,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Blood sausage",
            caloriesPerServing: 379.0,
            proteinPerServing: 14.6,
            carbsPerServing: 1.3,
            fatPerServing: 34.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Bockwurst",
            caloriesPerServing: 301.0,
            proteinPerServing: 14.0,
            carbsPerServing: 3.0,
            fatPerServing: 25.9,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Bratwurst",
            caloriesPerServing: 333.0,
            proteinPerServing: 13.7,
            carbsPerServing: 2.9,
            fatPerServing: 29.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Braunschweiger (a liver sausage)",
            caloriesPerServing: 327.0,
            proteinPerServing: 14.5,
            carbsPerServing: 3.1,
            fatPerServing: 28.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Cheesefurter",
            caloriesPerServing: 328.0,
            proteinPerServing: 14.1,
            carbsPerServing: 1.5,
            fatPerServing: 29.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Ham and cheese loaf or roll",
            caloriesPerServing: 241.0,
            proteinPerServing: 13.6,
            carbsPerServing: 4.0,
            fatPerServing: 18.7,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Ham and cheese spread",
            caloriesPerServing: 245.0,
            proteinPerServing: 16.2,
            carbsPerServing: 2.3,
            fatPerServing: 18.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Headcheese",
            caloriesPerServing: 157.0,
            proteinPerServing: 13.8,
            carbsPerServing: 0.0,
            fatPerServing: 10.9,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Pork sausage",
            caloriesPerServing: 217.0,
            proteinPerServing: 16.8,
            carbsPerServing: 0.2,
            fatPerServing: 16.6,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Cereals",
            caloriesPerServing: 370.0,
            proteinPerServing: 7.7,
            carbsPerServing: 79.1,
            fatPerServing: 1.8,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Acerola",
            caloriesPerServing: 32.0,
            proteinPerServing: 0.4,
            carbsPerServing: 7.7,
            fatPerServing: 0.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Acerola juice",
            caloriesPerServing: 23.0,
            proteinPerServing: 0.4,
            carbsPerServing: 4.8,
            fatPerServing: 0.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Apricot nectar",
            caloriesPerServing: 56.0,
            proteinPerServing: 0.2,
            carbsPerServing: 13.6,
            fatPerServing: 0.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Avocados",
            caloriesPerServing: 160.0,
            proteinPerServing: 2.0,
            carbsPerServing: 8.5,
            fatPerServing: 14.7,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Boysenberries",
            caloriesPerServing: 88.0,
            proteinPerServing: 1.0,
            carbsPerServing: 22.3,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Breadfruit",
            caloriesPerServing: 103.0,
            proteinPerServing: 1.1,
            carbsPerServing: 27.1,
            fatPerServing: 0.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Carambola",
            caloriesPerServing: 31.0,
            proteinPerServing: 1.0,
            carbsPerServing: 6.7,
            fatPerServing: 0.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Crabapples",
            caloriesPerServing: 76.0,
            proteinPerServing: 0.4,
            carbsPerServing: 19.9,
            fatPerServing: 0.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Currants",
            caloriesPerServing: 290.0,
            proteinPerServing: 3.4,
            carbsPerServing: 77.0,
            fatPerServing: 0.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Custard-apple",
            caloriesPerServing: 101.0,
            proteinPerServing: 1.7,
            carbsPerServing: 25.2,
            fatPerServing: 0.6,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Elderberries",
            caloriesPerServing: 73.0,
            proteinPerServing: 0.7,
            carbsPerServing: 18.4,
            fatPerServing: 0.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Dip",
            caloriesPerServing: 119.0,
            proteinPerServing: 5.4,
            carbsPerServing: 15.9,
            fatPerServing: 3.7,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Cookie",
            caloriesPerServing: 489.0,
            proteinPerServing: 3.5,
            carbsPerServing: 64.1,
            fatPerServing: 25.8,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Cocoa mix",
            caloriesPerServing: 400.0,
            proteinPerServing: 3.0,
            carbsPerServing: 75.0,
            fatPerServing: 15.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Cranberry juice cocktail",
            caloriesPerServing: 54.0,
            proteinPerServing: 0.0,
            carbsPerServing: 13.5,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Alcoholic beverages",
            caloriesPerServing: 58.0,
            proteinPerServing: 0.9,
            carbsPerServing: 0.3,
            fatPerServing: 0.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Carbonated beverage",
            caloriesPerServing: 42.0,
            proteinPerServing: 0.0,
            carbsPerServing: 10.7,
            fatPerServing: 0.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Water",
            caloriesPerServing: 1.0,
            proteinPerServing: 0.0,
            carbsPerServing: 0.1,
            fatPerServing: 0.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Crustaceans",
            caloriesPerServing: 83.0,
            proteinPerServing: 17.9,
            carbsPerServing: 0.0,
            fatPerServing: 0.7,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Millet flour",
            caloriesPerServing: 382.0,
            proteinPerServing: 10.8,
            carbsPerServing: 75.1,
            fatPerServing: 4.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Pizza hut 12\" cheese pizza",
            caloriesPerServing: 271.0,
            proteinPerServing: 11.9,
            carbsPerServing: 31.2,
            fatPerServing: 10.9,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Domino's 14\" cheese pizza",
            caloriesPerServing: 298.0,
            proteinPerServing: 12.3,
            carbsPerServing: 28.2,
            fatPerServing: 15.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Domino's 14\" extravaganzza feast pizza",
            caloriesPerServing: 244.0,
            proteinPerServing: 10.3,
            carbsPerServing: 25.7,
            fatPerServing: 11.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Little caesars 14\" original round cheese pizza",
            caloriesPerServing: 265.0,
            proteinPerServing: 13.4,
            carbsPerServing: 31.5,
            fatPerServing: 9.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Little caesars 14\" original round pepperoni pizza",
            caloriesPerServing: 273.0,
            proteinPerServing: 13.6,
            carbsPerServing: 31.0,
            fatPerServing: 10.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Little caesars 14\" original round meat and vegetable pizza",
            caloriesPerServing: 243.0,
            proteinPerServing: 12.1,
            carbsPerServing: 23.1,
            fatPerServing: 11.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Little caesars 14\" cheese pizza",
            caloriesPerServing: 263.0,
            proteinPerServing: 12.6,
            carbsPerServing: 30.1,
            fatPerServing: 10.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Pizza hut 14\" super supreme pizza",
            caloriesPerServing: 248.0,
            proteinPerServing: 11.3,
            carbsPerServing: 26.0,
            fatPerServing: 10.9,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Spaghetti with meat sauce",
            caloriesPerServing: 90.0,
            proteinPerServing: 5.0,
            carbsPerServing: 15.2,
            fatPerServing: 1.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Beef macaroni with tomato sauce",
            caloriesPerServing: 113.0,
            proteinPerServing: 5.9,
            carbsPerServing: 18.0,
            fatPerServing: 2.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Pasta with sliced franks in tomato sauce",
            caloriesPerServing: 90.0,
            proteinPerServing: 4.4,
            carbsPerServing: 12.7,
            fatPerServing: 2.4,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Turkey pot pie",
            caloriesPerServing: 176.0,
            proteinPerServing: 6.5,
            carbsPerServing: 17.7,
            fatPerServing: 8.8,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Beef pot pie",
            caloriesPerServing: 220.0,
            proteinPerServing: 7.2,
            carbsPerServing: 22.1,
            fatPerServing: 11.4,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Tortellini",
            caloriesPerServing: 307.0,
            proteinPerServing: 13.5,
            carbsPerServing: 47.0,
            fatPerServing: 7.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Chili con carne with beans",
            caloriesPerServing: 107.0,
            proteinPerServing: 5.8,
            carbsPerServing: 13.1,
            fatPerServing: 3.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Chili",
            caloriesPerServing: 118.0,
            proteinPerServing: 7.5,
            carbsPerServing: 6.1,
            fatPerServing: 7.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Pasta with tomato sauce",
            caloriesPerServing: 71.0,
            proteinPerServing: 2.2,
            carbsPerServing: 13.9,
            fatPerServing: 0.7,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Lasagna with meat & sauce",
            caloriesPerServing: 101.0,
            proteinPerServing: 6.8,
            carbsPerServing: 13.5,
            fatPerServing: 2.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Burrito",
            caloriesPerServing: 298.0,
            proteinPerServing: 8.7,
            carbsPerServing: 39.0,
            fatPerServing: 11.9,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Egg rolls",
            caloriesPerServing: 227.0,
            proteinPerServing: 9.9,
            carbsPerServing: 28.5,
            fatPerServing: 8.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Hot pockets",
            caloriesPerServing: 252.0,
            proteinPerServing: 9.3,
            carbsPerServing: 30.7,
            fatPerServing: 10.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Lean pockets",
            caloriesPerServing: 230.0,
            proteinPerServing: 10.3,
            carbsPerServing: 32.5,
            fatPerServing: 6.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Chili with beans",
            caloriesPerServing: 100.0,
            proteinPerServing: 5.8,
            carbsPerServing: 10.9,
            fatPerServing: 3.7,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Ravioli",
            caloriesPerServing: 111.0,
            proteinPerServing: 4.5,
            carbsPerServing: 17.3,
            fatPerServing: 2.6,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Lasagna with meat sauce",
            caloriesPerServing: 135.0,
            proteinPerServing: 7.3,
            carbsPerServing: 15.4,
            fatPerServing: 4.9,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Cheese substitute",
            caloriesPerServing: 248.0,
            proteinPerServing: 11.5,
            carbsPerServing: 23.7,
            fatPerServing: 12.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Cheese sauce",
            caloriesPerServing: 197.0,
            proteinPerServing: 10.3,
            carbsPerServing: 5.5,
            fatPerServing: 14.9,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Parmesan cheese topping",
            caloriesPerServing: 370.0,
            proteinPerServing: 40.0,
            carbsPerServing: 40.0,
            fatPerServing: 5.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Kraft cheez whiz pasteurized process cheese sauce",
            caloriesPerServing: 276.0,
            proteinPerServing: 12.0,
            carbsPerServing: 9.2,
            fatPerServing: 21.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Kraft breakstone's reduced fat sour cream",
            caloriesPerServing: 152.0,
            proteinPerServing: 4.5,
            carbsPerServing: 6.5,
            fatPerServing: 12.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Kraft breakstone's free fat free sour cream",
            caloriesPerServing: 91.0,
            proteinPerServing: 4.7,
            carbsPerServing: 15.1,
            fatPerServing: 1.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Reddi wip fat free whipped topping",
            caloriesPerServing: 149.0,
            proteinPerServing: 3.0,
            carbsPerServing: 25.0,
            fatPerServing: 5.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Ice cream sandwich",
            caloriesPerServing: 237.0,
            proteinPerServing: 4.3,
            carbsPerServing: 37.1,
            fatPerServing: 8.6,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Ice cream cookie sandwich",
            caloriesPerServing: 240.0,
            proteinPerServing: 3.7,
            carbsPerServing: 39.6,
            fatPerServing: 7.4,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Ice cream cone",
            caloriesPerServing: 354.0,
            proteinPerServing: 5.2,
            carbsPerServing: 34.4,
            fatPerServing: 21.9,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Basil",
            caloriesPerServing: 23.0,
            proteinPerServing: 3.1,
            carbsPerServing: 2.6,
            fatPerServing: 0.6,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Dill weed",
            caloriesPerServing: 43.0,
            proteinPerServing: 3.5,
            carbsPerServing: 7.0,
            fatPerServing: 1.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Mustard",
            caloriesPerServing: 60.0,
            proteinPerServing: 3.7,
            carbsPerServing: 5.8,
            fatPerServing: 3.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Vanilla extract",
            caloriesPerServing: 237.0,
            proteinPerServing: 0.1,
            carbsPerServing: 2.4,
            fatPerServing: 0.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Vinegar",
            caloriesPerServing: 18.0,
            proteinPerServing: 0.0,
            carbsPerServing: 0.0,
            fatPerServing: 0.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Capers",
            caloriesPerServing: 23.0,
            proteinPerServing: 2.4,
            carbsPerServing: 4.9,
            fatPerServing: 0.9,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Spearmint",
            caloriesPerServing: 285.0,
            proteinPerServing: 19.9,
            carbsPerServing: 52.0,
            fatPerServing: 6.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Seasoning mix",
            caloriesPerServing: 0.0,
            proteinPerServing: 0.0,
            carbsPerServing: 0.0,
            fatPerServing: 0.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Toddler drink",
            caloriesPerServing: 512.0,
            proteinPerServing: 13.9,
            carbsPerServing: 55.7,
            fatPerServing: 26.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Child formula",
            caloriesPerServing: 99.0,
            proteinPerServing: 2.9,
            carbsPerServing: 11.2,
            fatPerServing: 4.8,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Shortening bread",
            caloriesPerServing: 884.0,
            proteinPerServing: 0.0,
            carbsPerServing: 0.0,
            fatPerServing: 100.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Shortening cake mix",
            caloriesPerServing: 884.0,
            proteinPerServing: 0.0,
            carbsPerServing: 0.0,
            fatPerServing: 100.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Shortening frying (heavy duty)",
            caloriesPerServing: 884.0,
            proteinPerServing: 0.0,
            carbsPerServing: 0.0,
            fatPerServing: 100.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Shortening household soybean (hydrogenated) and palm",
            caloriesPerServing: 884.0,
            proteinPerServing: 0.0,
            carbsPerServing: 0.0,
            fatPerServing: 100.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Fish oil",
            caloriesPerServing: 902.0,
            proteinPerServing: 0.0,
            carbsPerServing: 0.0,
            fatPerServing: 100.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Animal fat",
            caloriesPerServing: 897.0,
            proteinPerServing: 0.0,
            carbsPerServing: 0.0,
            fatPerServing: 99.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Margarine-like spread with yogurt",
            caloriesPerServing: 630.0,
            proteinPerServing: 0.3,
            carbsPerServing: 0.5,
            fatPerServing: 70.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Goose",
            caloriesPerServing: 305.0,
            proteinPerServing: 25.2,
            carbsPerServing: 0.0,
            fatPerServing: 21.9,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Guinea hen",
            caloriesPerServing: 158.0,
            proteinPerServing: 23.4,
            carbsPerServing: 0.0,
            fatPerServing: 6.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Lupins",
            caloriesPerServing: 371.0,
            proteinPerServing: 36.2,
            carbsPerServing: 40.4,
            fatPerServing: 9.7,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Mothbeans",
            caloriesPerServing: 343.0,
            proteinPerServing: 22.9,
            carbsPerServing: 61.5,
            fatPerServing: 1.6,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Mungo beans",
            caloriesPerServing: 105.0,
            proteinPerServing: 7.5,
            carbsPerServing: 18.3,
            fatPerServing: 0.6,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Peanuts",
            caloriesPerServing: 567.0,
            proteinPerServing: 25.8,
            carbsPerServing: 16.1,
            fatPerServing: 49.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Peanut flour",
            caloriesPerServing: 428.0,
            proteinPerServing: 33.8,
            carbsPerServing: 31.3,
            fatPerServing: 21.9,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Pigeon peas (red gram)",
            caloriesPerServing: 343.0,
            proteinPerServing: 21.7,
            carbsPerServing: 62.8,
            fatPerServing: 1.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Refried beans",
            caloriesPerServing: 90.0,
            proteinPerServing: 5.0,
            carbsPerServing: 13.6,
            fatPerServing: 2.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Miso",
            caloriesPerServing: 198.0,
            proteinPerServing: 12.8,
            carbsPerServing: 25.4,
            fatPerServing: 6.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Natto",
            caloriesPerServing: 211.0,
            proteinPerServing: 19.4,
            carbsPerServing: 12.7,
            fatPerServing: 11.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Soy flour",
            caloriesPerServing: 372.0,
            proteinPerServing: 49.8,
            carbsPerServing: 30.6,
            fatPerServing: 8.9,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Soy meal",
            caloriesPerServing: 337.0,
            proteinPerServing: 49.2,
            carbsPerServing: 35.9,
            fatPerServing: 2.4,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Soymilk",
            caloriesPerServing: 54.0,
            proteinPerServing: 3.3,
            carbsPerServing: 6.3,
            fatPerServing: 1.8,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Soy protein concentrate",
            caloriesPerServing: 328.0,
            proteinPerServing: 63.6,
            carbsPerServing: 25.4,
            fatPerServing: 0.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Tofu",
            caloriesPerServing: 78.0,
            proteinPerServing: 9.0,
            carbsPerServing: 2.9,
            fatPerServing: 4.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Okara",
            caloriesPerServing: 76.0,
            proteinPerServing: 3.5,
            carbsPerServing: 12.2,
            fatPerServing: 1.7,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Hummus",
            caloriesPerServing: 177.0,
            proteinPerServing: 4.9,
            carbsPerServing: 20.1,
            fatPerServing: 8.6,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Falafel",
            caloriesPerServing: 333.0,
            proteinPerServing: 13.3,
            carbsPerServing: 31.8,
            fatPerServing: 17.8,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Peanut spread",
            caloriesPerServing: 650.0,
            proteinPerServing: 24.8,
            carbsPerServing: 14.2,
            fatPerServing: 54.9,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Mori-nu",
            caloriesPerServing: 62.0,
            proteinPerServing: 6.9,
            carbsPerServing: 2.4,
            fatPerServing: 2.7,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Frijoles rojos volteados (refried beans",
            caloriesPerServing: 144.0,
            proteinPerServing: 5.0,
            carbsPerServing: 15.5,
            fatPerServing: 6.9,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Tempeh",
            caloriesPerServing: 195.0,
            proteinPerServing: 19.9,
            carbsPerServing: 7.6,
            fatPerServing: 11.4,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Vitasoy usa",
            caloriesPerServing: 54.0,
            proteinPerServing: 8.3,
            carbsPerServing: 1.3,
            fatPerServing: 1.7,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Peanut butter with omega-3",
            caloriesPerServing: 608.0,
            proteinPerServing: 24.5,
            carbsPerServing: 17.0,
            fatPerServing: 54.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Soy sauce made from soy and wheat (shoyu)",
            caloriesPerServing: 57.0,
            proteinPerServing: 9.1,
            carbsPerServing: 5.6,
            fatPerServing: 0.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Soy sauce",
            caloriesPerServing: 90.0,
            proteinPerServing: 8.2,
            carbsPerServing: 14.4,
            fatPerServing: 0.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Veal",
            caloriesPerServing: 134.0,
            proteinPerServing: 21.7,
            carbsPerServing: 1.4,
            fatPerServing: 4.6,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Lamb",
            caloriesPerServing: 267.0,
            proteinPerServing: 16.9,
            carbsPerServing: 0.0,
            fatPerServing: 21.6,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Game meat",
            caloriesPerServing: 162.0,
            proteinPerServing: 20.8,
            carbsPerServing: 0.0,
            fatPerServing: 8.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Biscuits",
            caloriesPerServing: 338.0,
            proteinPerServing: 6.2,
            carbsPerServing: 53.9,
            fatPerServing: 11.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Puff pastry",
            caloriesPerServing: 558.0,
            proteinPerServing: 7.4,
            carbsPerServing: 45.7,
            fatPerServing: 38.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Cracker",
            caloriesPerServing: 383.0,
            proteinPerServing: 9.3,
            carbsPerServing: 80.9,
            fatPerServing: 1.7,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Croutons",
            caloriesPerServing: 407.0,
            proteinPerServing: 11.9,
            carbsPerServing: 73.5,
            fatPerServing: 6.6,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Danish pastry",
            caloriesPerServing: 403.0,
            proteinPerServing: 7.0,
            carbsPerServing: 44.6,
            fatPerServing: 22.4,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Doughnuts",
            caloriesPerServing: 412.0,
            proteinPerServing: 3.1,
            carbsPerServing: 59.5,
            fatPerServing: 18.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Muffins",
            caloriesPerServing: 276.0,
            proteinPerServing: 8.9,
            carbsPerServing: 55.0,
            fatPerServing: 2.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "French toast",
            caloriesPerServing: 213.0,
            proteinPerServing: 7.4,
            carbsPerServing: 32.1,
            fatPerServing: 6.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Pancakes plain",
            caloriesPerServing: 233.0,
            proteinPerServing: 5.2,
            carbsPerServing: 37.8,
            fatPerServing: 6.8,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Phyllo dough",
            caloriesPerServing: 299.0,
            proteinPerServing: 7.1,
            carbsPerServing: 52.6,
            fatPerServing: 6.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Popovers",
            caloriesPerServing: 371.0,
            proteinPerServing: 10.4,
            carbsPerServing: 71.0,
            fatPerServing: 4.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Sweet rolls",
            caloriesPerServing: 333.0,
            proteinPerServing: 5.0,
            carbsPerServing: 51.6,
            fatPerServing: 12.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Taco shells",
            caloriesPerServing: 476.0,
            proteinPerServing: 6.4,
            carbsPerServing: 63.5,
            fatPerServing: 21.8,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Wonton wrappers (includes egg roll wrappers)",
            caloriesPerServing: 291.0,
            proteinPerServing: 9.8,
            carbsPerServing: 57.9,
            fatPerServing: 1.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Leavening agents",
            caloriesPerServing: 53.0,
            proteinPerServing: 0.0,
            carbsPerServing: 27.7,
            fatPerServing: 0.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "English muffins",
            caloriesPerServing: 235.0,
            proteinPerServing: 7.7,
            carbsPerServing: 46.0,
            fatPerServing: 1.8,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Ruffed grouse",
            caloriesPerServing: 112.0,
            proteinPerServing: 25.9,
            carbsPerServing: 0.0,
            fatPerServing: 0.9,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Emu",
            caloriesPerServing: 134.0,
            proteinPerServing: 22.8,
            carbsPerServing: 0.0,
            fatPerServing: 4.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Ostrich",
            caloriesPerServing: 111.0,
            proteinPerServing: 22.4,
            carbsPerServing: 0.0,
            fatPerServing: 1.7,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Turkey from whole",
            caloriesPerServing: 101.0,
            proteinPerServing: 21.5,
            carbsPerServing: 0.0,
            fatPerServing: 1.7,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Campbell's chunky",
            caloriesPerServing: 49.0,
            proteinPerServing: 3.2,
            carbsPerServing: 6.2,
            fatPerServing: 1.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Olive loaf",
            caloriesPerServing: 235.0,
            proteinPerServing: 11.8,
            carbsPerServing: 9.2,
            fatPerServing: 16.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Pastrami",
            caloriesPerServing: 139.0,
            proteinPerServing: 16.3,
            carbsPerServing: 3.3,
            fatPerServing: 6.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Pate",
            caloriesPerServing: 201.0,
            proteinPerServing: 13.4,
            carbsPerServing: 6.5,
            fatPerServing: 13.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Luxury loaf",
            caloriesPerServing: 141.0,
            proteinPerServing: 18.4,
            carbsPerServing: 4.9,
            fatPerServing: 4.8,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Mother's loaf",
            caloriesPerServing: 282.0,
            proteinPerServing: 12.1,
            carbsPerServing: 7.5,
            fatPerServing: 22.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Picnic loaf",
            caloriesPerServing: 232.0,
            proteinPerServing: 14.9,
            carbsPerServing: 4.8,
            fatPerServing: 16.6,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Salami",
            caloriesPerServing: 261.0,
            proteinPerServing: 12.6,
            carbsPerServing: 1.9,
            fatPerServing: 22.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Thuringer",
            caloriesPerServing: 362.0,
            proteinPerServing: 17.4,
            carbsPerServing: 3.3,
            fatPerServing: 30.4,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Honey roll sausage",
            caloriesPerServing: 182.0,
            proteinPerServing: 18.6,
            carbsPerServing: 2.2,
            fatPerServing: 10.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Oscar mayer",
            caloriesPerServing: 331.0,
            proteinPerServing: 14.2,
            carbsPerServing: 2.6,
            fatPerServing: 29.4,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Luncheon meat",
            caloriesPerServing: 293.0,
            proteinPerServing: 12.5,
            carbsPerServing: 3.4,
            fatPerServing: 25.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Yachtwurst",
            caloriesPerServing: 268.0,
            proteinPerServing: 14.8,
            carbsPerServing: 1.4,
            fatPerServing: 22.6,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Chicken breast",
            caloriesPerServing: 80.0,
            proteinPerServing: 16.8,
            carbsPerServing: 2.2,
            fatPerServing: 0.4,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Macaroni and cheese loaf",
            caloriesPerServing: 228.0,
            proteinPerServing: 11.8,
            carbsPerServing: 11.6,
            fatPerServing: 15.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Scrapple",
            caloriesPerServing: 213.0,
            proteinPerServing: 8.1,
            carbsPerServing: 14.1,
            fatPerServing: 13.9,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Rice and wheat cereal bar",
            caloriesPerServing: 409.0,
            proteinPerServing: 9.1,
            carbsPerServing: 72.7,
            fatPerServing: 9.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Figs",
            caloriesPerServing: 74.0,
            proteinPerServing: 0.8,
            carbsPerServing: 19.2,
            fatPerServing: 0.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Gooseberries",
            caloriesPerServing: 44.0,
            proteinPerServing: 0.9,
            carbsPerServing: 10.2,
            fatPerServing: 0.6,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Goji berries",
            caloriesPerServing: 349.0,
            proteinPerServing: 14.3,
            carbsPerServing: 77.1,
            fatPerServing: 0.4,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Grapefruit",
            caloriesPerServing: 32.0,
            proteinPerServing: 0.6,
            carbsPerServing: 8.1,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Grapes",
            caloriesPerServing: 57.0,
            proteinPerServing: 0.8,
            carbsPerServing: 13.9,
            fatPerServing: 0.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Groundcherries",
            caloriesPerServing: 53.0,
            proteinPerServing: 1.9,
            carbsPerServing: 11.2,
            fatPerServing: 0.7,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Guavas",
            caloriesPerServing: 68.0,
            proteinPerServing: 2.5,
            carbsPerServing: 14.3,
            fatPerServing: 0.9,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Formulated bar",
            caloriesPerServing: 377.0,
            proteinPerServing: 22.4,
            carbsPerServing: 51.7,
            fatPerServing: 9.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Rice crackers",
            caloriesPerServing: 416.0,
            proteinPerServing: 10.0,
            carbsPerServing: 82.6,
            fatPerServing: 5.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Lemonade",
            caloriesPerServing: 196.0,
            proteinPerServing: 0.2,
            carbsPerServing: 49.9,
            fatPerServing: 0.7,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Shake",
            caloriesPerServing: 148.0,
            proteinPerServing: 3.4,
            carbsPerServing: 19.6,
            fatPerServing: 6.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Archway home style cookies",
            caloriesPerServing: 460.0,
            proteinPerServing: 3.0,
            carbsPerServing: 61.2,
            fatPerServing: 22.6,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Keebler",
            caloriesPerServing: 465.0,
            proteinPerServing: 7.1,
            carbsPerServing: 71.8,
            fatPerServing: 16.6,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Continental mills",
            caloriesPerServing: 418.0,
            proteinPerServing: 5.6,
            carbsPerServing: 75.6,
            fatPerServing: 10.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Mckee baking",
            caloriesPerServing: 548.0,
            proteinPerServing: 8.0,
            carbsPerServing: 55.2,
            fatPerServing: 32.8,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Pizza hut 12\" pepperoni pizza",
            caloriesPerServing: 280.0,
            proteinPerServing: 12.9,
            carbsPerServing: 31.6,
            fatPerServing: 11.4,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Pizza hut 12\" super supreme pizza",
            caloriesPerServing: 243.0,
            proteinPerServing: 10.9,
            carbsPerServing: 25.6,
            fatPerServing: 10.7,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Papa john's 14\" cheese pizza",
            caloriesPerServing: 260.0,
            proteinPerServing: 11.5,
            carbsPerServing: 32.7,
            fatPerServing: 9.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Papa john's 14\" pepperoni pizza",
            caloriesPerServing: 275.0,
            proteinPerServing: 12.0,
            carbsPerServing: 30.0,
            fatPerServing: 11.9,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Papa john's 14\" the works pizza",
            caloriesPerServing: 240.0,
            proteinPerServing: 10.3,
            carbsPerServing: 26.7,
            fatPerServing: 10.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Little caesars 14\" pepperoni pizza",
            caloriesPerServing: 265.0,
            proteinPerServing: 12.9,
            carbsPerServing: 29.0,
            fatPerServing: 10.8,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Hot pockets ham 'n cheese stuffed sandwich",
            caloriesPerServing: 270.0,
            proteinPerServing: 9.2,
            carbsPerServing: 24.7,
            fatPerServing: 15.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Beef stew",
            caloriesPerServing: 99.0,
            proteinPerServing: 4.4,
            carbsPerServing: 7.8,
            fatPerServing: 5.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Chicken pot pie",
            caloriesPerServing: 204.0,
            proteinPerServing: 5.1,
            carbsPerServing: 19.2,
            fatPerServing: 11.8,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Rice bowl with chicken",
            caloriesPerServing: 126.0,
            proteinPerServing: 5.7,
            carbsPerServing: 22.5,
            fatPerServing: 1.6,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Macaroni and cheese dinner with dry sauce mix",
            caloriesPerServing: 379.0,
            proteinPerServing: 13.9,
            carbsPerServing: 70.1,
            fatPerServing: 4.8,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Potato salad with egg",
            caloriesPerServing: 157.0,
            proteinPerServing: 2.0,
            carbsPerServing: 16.2,
            fatPerServing: 9.4,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Pulled pork in barbecue sauce",
            caloriesPerServing: 168.0,
            proteinPerServing: 13.2,
            carbsPerServing: 18.7,
            fatPerServing: 4.4,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Corn dogs",
            caloriesPerServing: 250.0,
            proteinPerServing: 8.6,
            carbsPerServing: 27.0,
            fatPerServing: 12.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Chicken tenders",
            caloriesPerServing: 240.0,
            proteinPerServing: 14.6,
            carbsPerServing: 14.9,
            fatPerServing: 13.6,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Rice-a-roni",
            caloriesPerServing: 356.0,
            proteinPerServing: 10.6,
            carbsPerServing: 76.1,
            fatPerServing: 1.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Butter oil",
            caloriesPerServing: 876.0,
            proteinPerServing: 0.3,
            carbsPerServing: 0.0,
            fatPerServing: 99.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Egg substitute",
            caloriesPerServing: 444.0,
            proteinPerServing: 55.5,
            carbsPerServing: 21.8,
            fatPerServing: 13.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Kraft cheez whiz light pasteurized process cheese product",
            caloriesPerServing: 215.0,
            proteinPerServing: 16.3,
            carbsPerServing: 16.2,
            fatPerServing: 9.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Kraft free singles american nonfat pasteurized process cheese product",
            caloriesPerServing: 148.0,
            proteinPerServing: 22.7,
            carbsPerServing: 11.7,
            fatPerServing: 1.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Kraft velveeta pasteurized process cheese spread",
            caloriesPerServing: 303.0,
            proteinPerServing: 16.3,
            carbsPerServing: 9.8,
            fatPerServing: 22.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Kraft velveeta light reduced fat pasteurized process cheese product",
            caloriesPerServing: 222.0,
            proteinPerServing: 19.6,
            carbsPerServing: 11.8,
            fatPerServing: 10.6,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Protein supplement",
            caloriesPerServing: 411.0,
            proteinPerServing: 45.7,
            carbsPerServing: 18.5,
            fatPerServing: 17.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Dulce de leche",
            caloriesPerServing: 315.0,
            proteinPerServing: 6.8,
            carbsPerServing: 55.4,
            fatPerServing: 7.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Fat free ice cream",
            caloriesPerServing: 133.0,
            proteinPerServing: 4.4,
            carbsPerServing: 28.9,
            fatPerServing: 0.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Salt",
            caloriesPerServing: 0.0,
            proteinPerServing: 0.0,
            carbsPerServing: 0.0,
            fatPerServing: 0.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Thyme",
            caloriesPerServing: 101.0,
            proteinPerServing: 5.6,
            carbsPerServing: 24.4,
            fatPerServing: 1.7,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Horseradish",
            caloriesPerServing: 48.0,
            proteinPerServing: 1.2,
            carbsPerServing: 11.3,
            fatPerServing: 0.7,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Rosemary",
            caloriesPerServing: 131.0,
            proteinPerServing: 3.3,
            carbsPerServing: 20.7,
            fatPerServing: 5.9,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Peppermint",
            caloriesPerServing: 70.0,
            proteinPerServing: 3.8,
            carbsPerServing: 14.9,
            fatPerServing: 0.9,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Clif z bar",
            caloriesPerServing: 416.0,
            proteinPerServing: 5.5,
            carbsPerServing: 74.7,
            fatPerServing: 9.7,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Shortening industrial",
            caloriesPerServing: 900.0,
            proteinPerServing: 0.0,
            carbsPerServing: 0.0,
            fatPerServing: 100.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Shortening confectionery",
            caloriesPerServing: 884.0,
            proteinPerServing: 0.0,
            carbsPerServing: 0.0,
            fatPerServing: 100.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Margarine spread",
            caloriesPerServing: 401.0,
            proteinPerServing: 0.3,
            carbsPerServing: 0.0,
            fatPerServing: 44.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Margarine-like shortening",
            caloriesPerServing: 628.0,
            proteinPerServing: 0.0,
            carbsPerServing: 0.0,
            fatPerServing: 71.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Canada goose",
            caloriesPerServing: 133.0,
            proteinPerServing: 24.3,
            carbsPerServing: 0.0,
            fatPerServing: 4.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Whiskey sour mix",
            caloriesPerServing: 84.0,
            proteinPerServing: 0.1,
            carbsPerServing: 21.4,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Salmon nuggets",
            caloriesPerServing: 212.0,
            proteinPerServing: 12.7,
            carbsPerServing: 14.0,
            fatPerServing: 11.7,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Yokan",
            caloriesPerServing: 260.0,
            proteinPerServing: 3.3,
            carbsPerServing: 60.7,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Broadbeans (fava beans)",
            caloriesPerServing: 110.0,
            proteinPerServing: 7.6,
            carbsPerServing: 19.6,
            fatPerServing: 0.4,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Carob flour",
            caloriesPerServing: 222.0,
            proteinPerServing: 4.6,
            carbsPerServing: 88.9,
            fatPerServing: 0.7,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Chickpeas (garbanzo beans",
            caloriesPerServing: 378.0,
            proteinPerServing: 20.5,
            carbsPerServing: 63.0,
            fatPerServing: 6.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Soymilk (all flavors)",
            caloriesPerServing: 45.0,
            proteinPerServing: 2.9,
            carbsPerServing: 3.5,
            fatPerServing: 2.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Silk chocolate",
            caloriesPerServing: 58.0,
            proteinPerServing: 2.1,
            carbsPerServing: 9.5,
            fatPerServing: 1.4,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Silk light plain",
            caloriesPerServing: 29.0,
            proteinPerServing: 2.5,
            carbsPerServing: 3.3,
            fatPerServing: 0.8,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Silk light vanilla",
            caloriesPerServing: 33.0,
            proteinPerServing: 2.5,
            carbsPerServing: 4.1,
            fatPerServing: 0.8,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Silk light chocolate",
            caloriesPerServing: 49.0,
            proteinPerServing: 2.1,
            carbsPerServing: 9.1,
            fatPerServing: 0.6,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Silk very vanilla",
            caloriesPerServing: 53.0,
            proteinPerServing: 2.5,
            carbsPerServing: 7.8,
            fatPerServing: 1.6,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Silk nog",
            caloriesPerServing: 74.0,
            proteinPerServing: 2.5,
            carbsPerServing: 12.3,
            fatPerServing: 1.6,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Silk chai",
            caloriesPerServing: 53.0,
            proteinPerServing: 2.5,
            carbsPerServing: 7.8,
            fatPerServing: 1.4,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Silk mocha",
            caloriesPerServing: 58.0,
            proteinPerServing: 2.1,
            carbsPerServing: 9.1,
            fatPerServing: 1.4,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Silk raspberry soy yogurt",
            caloriesPerServing: 88.0,
            proteinPerServing: 2.4,
            carbsPerServing: 17.6,
            fatPerServing: 1.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Silk peach soy yogurt",
            caloriesPerServing: 94.0,
            proteinPerServing: 2.4,
            carbsPerServing: 18.8,
            fatPerServing: 1.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Silk black cherry soy yogurt",
            caloriesPerServing: 88.0,
            proteinPerServing: 2.4,
            carbsPerServing: 17.1,
            fatPerServing: 1.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Silk blueberry soy yogurt",
            caloriesPerServing: 88.0,
            proteinPerServing: 2.4,
            carbsPerServing: 17.1,
            fatPerServing: 1.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Silk hazelnut creamer",
            caloriesPerServing: 133.0,
            proteinPerServing: 0.0,
            carbsPerServing: 20.0,
            fatPerServing: 6.7,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Vitasoy usa organic nasoya",
            caloriesPerServing: 70.0,
            proteinPerServing: 8.8,
            carbsPerServing: 0.7,
            fatPerServing: 3.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Vitasoy usa nasoya",
            caloriesPerServing: 43.0,
            proteinPerServing: 8.2,
            carbsPerServing: 0.0,
            fatPerServing: 1.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Vitasoy usa azumaya",
            caloriesPerServing: 43.0,
            proteinPerServing: 4.8,
            carbsPerServing: 0.6,
            fatPerServing: 2.4,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "House foods premium soft tofu",
            caloriesPerServing: 59.0,
            proteinPerServing: 6.4,
            carbsPerServing: 2.2,
            fatPerServing: 2.7,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "House foods premium firm tofu",
            caloriesPerServing: 85.0,
            proteinPerServing: 10.9,
            carbsPerServing: 1.0,
            fatPerServing: 4.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Bison",
            caloriesPerServing: 179.0,
            proteinPerServing: 25.4,
            carbsPerServing: 0.0,
            fatPerServing: 8.6,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Chicken spread",
            caloriesPerServing: 158.0,
            proteinPerServing: 18.0,
            carbsPerServing: 4.0,
            fatPerServing: 17.6,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Corned beef loaf",
            caloriesPerServing: 153.0,
            proteinPerServing: 22.9,
            carbsPerServing: 0.0,
            fatPerServing: 6.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Dutch brand loaf",
            caloriesPerServing: 273.0,
            proteinPerServing: 12.0,
            carbsPerServing: 3.9,
            fatPerServing: 22.9,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Ham salad spread",
            caloriesPerServing: 216.0,
            proteinPerServing: 8.7,
            carbsPerServing: 10.6,
            fatPerServing: 15.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Knackwurst",
            caloriesPerServing: 307.0,
            proteinPerServing: 11.1,
            carbsPerServing: 3.2,
            fatPerServing: 27.7,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Lebanon bologna",
            caloriesPerServing: 172.0,
            proteinPerServing: 19.0,
            carbsPerServing: 0.4,
            fatPerServing: 10.4,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Liver cheese",
            caloriesPerServing: 304.0,
            proteinPerServing: 15.2,
            carbsPerServing: 2.1,
            fatPerServing: 25.6,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Liver sausage",
            caloriesPerServing: 326.0,
            proteinPerServing: 14.1,
            carbsPerServing: 2.2,
            fatPerServing: 28.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Kielbasa",
            caloriesPerServing: 337.0,
            proteinPerServing: 12.4,
            carbsPerServing: 5.0,
            fatPerServing: 29.7,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Bananas",
            caloriesPerServing: 89.0,
            proteinPerServing: 1.1,
            carbsPerServing: 22.8,
            fatPerServing: 0.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Blackberry juice",
            caloriesPerServing: 38.0,
            proteinPerServing: 0.3,
            carbsPerServing: 7.8,
            fatPerServing: 0.6,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Carissa",
            caloriesPerServing: 62.0,
            proteinPerServing: 0.5,
            carbsPerServing: 13.6,
            fatPerServing: 1.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Cherimoya",
            caloriesPerServing: 75.0,
            proteinPerServing: 1.6,
            carbsPerServing: 17.7,
            fatPerServing: 0.7,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Cranberry-orange relish",
            caloriesPerServing: 178.0,
            proteinPerServing: 0.3,
            carbsPerServing: 46.2,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Beef composite",
            caloriesPerServing: 203.0,
            proteinPerServing: 28.7,
            carbsPerServing: 0.0,
            fatPerServing: 9.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Meat extender",
            caloriesPerServing: 311.0,
            proteinPerServing: 41.7,
            carbsPerServing: 34.7,
            fatPerServing: 3.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Soy protein isolate",
            caloriesPerServing: 335.0,
            proteinPerServing: 88.3,
            carbsPerServing: 0.0,
            fatPerServing: 3.4,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Soy sauce made from soy (tamari)",
            caloriesPerServing: 60.0,
            proteinPerServing: 10.5,
            carbsPerServing: 5.6,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Soy sauce made from hydrolyzed vegetable protein",
            caloriesPerServing: 60.0,
            proteinPerServing: 7.0,
            carbsPerServing: 7.8,
            fatPerServing: 0.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Yardlong beans",
            caloriesPerServing: 347.0,
            proteinPerServing: 24.3,
            carbsPerServing: 61.9,
            fatPerServing: 1.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Veggie burgers or soyburgers",
            caloriesPerServing: 177.0,
            proteinPerServing: 15.7,
            carbsPerServing: 14.3,
            fatPerServing: 6.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Chickpea flour (besan)",
            caloriesPerServing: 387.0,
            proteinPerServing: 22.4,
            carbsPerServing: 57.8,
            fatPerServing: 6.7,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Split pea soup",
            caloriesPerServing: 71.0,
            proteinPerServing: 3.9,
            carbsPerServing: 11.8,
            fatPerServing: 0.9,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Split pea with ham soup",
            caloriesPerServing: 68.0,
            proteinPerServing: 4.0,
            carbsPerServing: 11.4,
            fatPerServing: 0.7,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Roast beef",
            caloriesPerServing: 115.0,
            proteinPerServing: 18.6,
            carbsPerServing: 0.6,
            fatPerServing: 3.7,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Mortadella",
            caloriesPerServing: 311.0,
            proteinPerServing: 16.4,
            carbsPerServing: 3.0,
            fatPerServing: 25.4,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Peppered loaf",
            caloriesPerServing: 149.0,
            proteinPerServing: 17.3,
            carbsPerServing: 4.5,
            fatPerServing: 6.4,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Pepperoni",
            caloriesPerServing: 504.0,
            proteinPerServing: 19.2,
            carbsPerServing: 1.2,
            fatPerServing: 46.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Pickle and pimiento loaf",
            caloriesPerServing: 225.0,
            proteinPerServing: 11.2,
            carbsPerServing: 8.5,
            fatPerServing: 15.9,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Polish sausage",
            caloriesPerServing: 326.0,
            proteinPerServing: 14.1,
            carbsPerServing: 1.6,
            fatPerServing: 28.7,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Poultry salad sandwich spread",
            caloriesPerServing: 200.0,
            proteinPerServing: 11.6,
            carbsPerServing: 7.4,
            fatPerServing: 13.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Luncheon sausage",
            caloriesPerServing: 260.0,
            proteinPerServing: 15.4,
            carbsPerServing: 1.6,
            fatPerServing: 20.9,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Hormel pillow pak sliced turkey pepperoni",
            caloriesPerServing: 243.0,
            proteinPerServing: 31.0,
            carbsPerServing: 3.8,
            fatPerServing: 11.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Liverwurst spread",
            caloriesPerServing: 305.0,
            proteinPerServing: 12.4,
            carbsPerServing: 5.9,
            fatPerServing: 25.4,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Roast beef spread",
            caloriesPerServing: 223.0,
            proteinPerServing: 15.3,
            carbsPerServing: 3.7,
            fatPerServing: 16.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Swisswurst",
            caloriesPerServing: 307.0,
            proteinPerServing: 12.7,
            carbsPerServing: 1.6,
            fatPerServing: 27.4,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Bacon and beef sticks",
            caloriesPerServing: 517.0,
            proteinPerServing: 29.1,
            carbsPerServing: 0.8,
            fatPerServing: 44.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Milk and cereal bar",
            caloriesPerServing: 413.0,
            proteinPerServing: 6.5,
            carbsPerServing: 72.0,
            fatPerServing: 11.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Incaparina",
            caloriesPerServing: 379.0,
            proteinPerServing: 21.8,
            carbsPerServing: 60.5,
            fatPerServing: 5.6,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Guava sauce",
            caloriesPerServing: 36.0,
            proteinPerServing: 0.3,
            carbsPerServing: 9.5,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Limeade",
            caloriesPerServing: 52.0,
            proteinPerServing: 0.0,
            carbsPerServing: 13.8,
            fatPerServing: 0.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Malt beverage",
            caloriesPerServing: 37.0,
            proteinPerServing: 0.2,
            carbsPerServing: 8.1,
            fatPerServing: 0.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Strawberry-flavor beverage mix",
            caloriesPerServing: 389.0,
            proteinPerServing: 0.1,
            carbsPerServing: 99.1,
            fatPerServing: 0.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Cream puff shell",
            caloriesPerServing: 360.0,
            proteinPerServing: 9.0,
            carbsPerServing: 22.8,
            fatPerServing: 25.9,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Croissants",
            caloriesPerServing: 406.0,
            proteinPerServing: 8.2,
            carbsPerServing: 45.8,
            fatPerServing: 21.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Hush puppies",
            caloriesPerServing: 337.0,
            proteinPerServing: 7.7,
            carbsPerServing: 46.0,
            fatPerServing: 13.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Ice cream cones",
            caloriesPerServing: 417.0,
            proteinPerServing: 8.1,
            carbsPerServing: 79.0,
            fatPerServing: 6.9,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Strudel",
            caloriesPerServing: 274.0,
            proteinPerServing: 3.3,
            carbsPerServing: 41.1,
            fatPerServing: 11.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Tart",
            caloriesPerServing: 372.0,
            proteinPerServing: 4.0,
            carbsPerServing: 76.8,
            fatPerServing: 6.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Artificial blueberry muffin mix",
            caloriesPerServing: 407.0,
            proteinPerServing: 4.7,
            carbsPerServing: 77.5,
            fatPerServing: 8.7,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Kraft",
            caloriesPerServing: 381.0,
            proteinPerServing: 12.6,
            carbsPerServing: 73.1,
            fatPerServing: 4.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Martha white foods",
            caloriesPerServing: 407.0,
            proteinPerServing: 4.4,
            carbsPerServing: 83.6,
            fatPerServing: 6.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Mission foods",
            caloriesPerServing: 287.0,
            proteinPerServing: 8.7,
            carbsPerServing: 49.6,
            fatPerServing: 6.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Hyacinth beans",
            caloriesPerServing: 344.0,
            proteinPerServing: 23.9,
            carbsPerServing: 60.7,
            fatPerServing: 1.7,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Silk plain",
            caloriesPerServing: 41.0,
            proteinPerServing: 2.9,
            carbsPerServing: 3.3,
            fatPerServing: 1.6,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Silk vanilla",
            caloriesPerServing: 41.0,
            proteinPerServing: 2.5,
            carbsPerServing: 4.1,
            fatPerServing: 1.4,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Silk plus omega-3 dha",
            caloriesPerServing: 45.0,
            proteinPerServing: 2.9,
            carbsPerServing: 3.3,
            fatPerServing: 2.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Silk plus for bone health",
            caloriesPerServing: 41.0,
            proteinPerServing: 2.5,
            carbsPerServing: 4.5,
            fatPerServing: 1.4,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Silk plus fiber",
            caloriesPerServing: 41.0,
            proteinPerServing: 2.5,
            carbsPerServing: 5.8,
            fatPerServing: 1.4,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Silk unsweetened",
            caloriesPerServing: 33.0,
            proteinPerServing: 2.9,
            carbsPerServing: 1.6,
            fatPerServing: 1.6,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Silk coffee",
            caloriesPerServing: 62.0,
            proteinPerServing: 2.1,
            carbsPerServing: 10.3,
            fatPerServing: 1.4,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Silk vanilla soy yogurt (family size)",
            caloriesPerServing: 79.0,
            proteinPerServing: 2.6,
            carbsPerServing: 13.7,
            fatPerServing: 1.8,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Silk vanilla soy yogurt (single serving size)",
            caloriesPerServing: 88.0,
            proteinPerServing: 2.9,
            carbsPerServing: 14.7,
            fatPerServing: 1.8,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Silk plain soy yogurt",
            caloriesPerServing: 66.0,
            proteinPerServing: 2.6,
            carbsPerServing: 9.7,
            fatPerServing: 1.8,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Silk strawberry soy yogurt",
            caloriesPerServing: 94.0,
            proteinPerServing: 2.4,
            carbsPerServing: 18.2,
            fatPerServing: 1.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Silk key lime soy yogurt",
            caloriesPerServing: 88.0,
            proteinPerServing: 2.4,
            carbsPerServing: 17.6,
            fatPerServing: 1.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Silk banana-strawberry soy yogurt",
            caloriesPerServing: 88.0,
            proteinPerServing: 2.4,
            carbsPerServing: 17.1,
            fatPerServing: 1.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Silk original creamer",
            caloriesPerServing: 100.0,
            proteinPerServing: 0.0,
            carbsPerServing: 6.7,
            fatPerServing: 6.7,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Silk french vanilla creamer",
            caloriesPerServing: 133.0,
            proteinPerServing: 0.0,
            carbsPerServing: 20.0,
            fatPerServing: 6.7,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "Vitasoy usa organic nasoya sprouted",
            caloriesPerServing: 115.0,
            proteinPerServing: 13.2,
            carbsPerServing: 2.2,
            fatPerServing: 5.9,
            servingSizeDescription: "100g"
        ),
        // MARK: - Fast Food: Hungry Jack's (Nov 2025)

        CommonFood(
            name: "Hungry Jack's Whopper",
            caloriesPerServing: 563.6, // 2358 kJ
            proteinPerServing: 29.2,
            carbsPerServing: 47.0,
            fatPerServing: 42.3,
            servingSizeDescription: "1 Burger (280g)"
        ),
        CommonFood(
            name: "Hungry Jack's Double Whopper",
            caloriesPerServing: 808.8, // 3385 kJ
            proteinPerServing: 49.6,
            carbsPerServing: 47.4,
            fatPerServing: 60.0,
            servingSizeDescription: "1 Burger (359g)"
        ),
        CommonFood(
            name: "Hungry Jack's Bacon Deluxe",
            caloriesPerServing: 489.2, // 2047 kJ
            proteinPerServing: 29.3,
            carbsPerServing: 27.4,
            fatPerServing: 36.2,
            servingSizeDescription: "1 Burger (202g)"
        ),
        CommonFood(
            name: "Hungry Jack's Cheeseburger",
            caloriesPerServing: 310.7, // 1300 kJ
            proteinPerServing: 15.5,
            carbsPerServing: 28.5,
            fatPerServing: 14.8,
            servingSizeDescription: "1 Burger (119g)"
        ),
        CommonFood(
            name: "Hungry Jack's Double Cheeseburger",
            caloriesPerServing: 425.4, // 1780 kJ
            proteinPerServing: 26.0,
            carbsPerServing: 29.3,
            fatPerServing: 25.6,
            servingSizeDescription: "1 Burger (165g)"
        ),
        CommonFood(
            name: "Hungry Jack's Hamburger",
            caloriesPerServing: 273.6, // 1145 kJ
            proteinPerServing: 12.3,
            carbsPerServing: 28.0,
            fatPerServing: 11.9,
            servingSizeDescription: "1 Burger (106g)"
        ),
        CommonFood(
            name: "Hungry Jack's Chicken Royale",
            caloriesPerServing: 335.6, // 1404 kJ
            proteinPerServing: 11.5,
            carbsPerServing: 41.7,
            fatPerServing: 27.2,
            servingSizeDescription: "1 Burger (148g)"
        ),
        CommonFood(
            name: "Hungry Jack's Jack's Fried Chicken Classic",
            caloriesPerServing: 679.5, // 2843 kJ
            proteinPerServing: 36.1,
            carbsPerServing: 55.2,
            fatPerServing: 48.3,
            servingSizeDescription: "1 Burger (264g)"
        ),
        CommonFood(
            name: "Hungry Jack's Jack's Fried Chicken Spicy",
            caloriesPerServing: 770.8, // 3225 kJ
            proteinPerServing: 36.1,
            carbsPerServing: 56.7,
            fatPerServing: 49.0,
            servingSizeDescription: "1 Burger (264g)"
        ),
        CommonFood(
            name: "Hungry Jack's Chips (Medium)",
            caloriesPerServing: 308.1, // 1289 kJ
            proteinPerServing: 3.8,
            carbsPerServing: 41.3,
            fatPerServing: 14.3,
            servingSizeDescription: "1 Serve (108g)"
        ),
        CommonFood(
            name: "Hungry Jack's Onion Rings (Medium)",
            caloriesPerServing: 286.3, // 1198 kJ
            proteinPerServing: 2.6,
            carbsPerServing: 23.6,
            fatPerServing: 20.4,
            servingSizeDescription: "1 Serve (77g)"
        ),
        CommonFood(
            name: "Hungry Jack's Nuggets (6 Pack)",
            caloriesPerServing: 260.9, // 1092 kJ
            proteinPerServing: 14.8,
            carbsPerServing: 21.1,
            fatPerServing: 12.7,
            servingSizeDescription: "1 Serve (102g)"
        ),
        CommonFood(
            name: "Hungry Jack's Hash Brown",
            caloriesPerServing: 139.8, // 585 kJ
            proteinPerServing: 1.4,
            carbsPerServing: 15.2,
            fatPerServing: 11.0,
            servingSizeDescription: "1 Serve (58g)"
        ),
        CommonFood(
            name: "Hungry Jack's Pancakes (with Syrup & Butter)",
            caloriesPerServing: 387.9, // 1623 kJ
            proteinPerServing: 7.0,
            carbsPerServing: 64.5,
            fatPerServing: 11.7,
            servingSizeDescription: "1 Serve (147g)"
        ),
        CommonFood(
            name: "Hungry Jack's Sausage Brekky Wrap",
            caloriesPerServing: 578.6, // 2421 kJ
            proteinPerServing: 37.0,
            carbsPerServing: 36.0,
            fatPerServing: 31.9,
            servingSizeDescription: "1 Wrap (243g)"
        ),
        // MARK: - Fast Food: McDonald's Drinks (Oct 2025)

        CommonFood(
            name: "McDonald's Coca-Cola",
            caloriesPerServing: 41,
            proteinPerServing: 0.0,
            carbsPerServing: 10.6,
            fatPerServing: 0.0,
            servingSizeDescription: "100mL"
        ),
        CommonFood(
            name: "McDonald's Coke Zero Sugar",
            caloriesPerServing: 0.6,
            proteinPerServing: 0.1,
            carbsPerServing: 0.1,
            fatPerServing: 0.0,
            servingSizeDescription: "100mL"
        ),
        CommonFood(
            name: "McDonald's Coke Vanilla",
            caloriesPerServing: 44,
            proteinPerServing: 0.1,
            carbsPerServing: 10.8,
            fatPerServing: 0.0,
            servingSizeDescription: "100mL"
        ),
        CommonFood(
            name: "McDonald's Fanta Orange",
            caloriesPerServing: 52,
            proteinPerServing: 0.0,
            carbsPerServing: 13.5,
            fatPerServing: 0.0,
            servingSizeDescription: "100mL"
        ),
        CommonFood(
            name: "McDonald's Sprite",
            caloriesPerServing: 40,
            proteinPerServing: 0.0,
            carbsPerServing: 10.3,
            fatPerServing: 0.0,
            servingSizeDescription: "100mL"
        ),
        CommonFood(
            name: "McDonald's Frozen Coke",
            caloriesPerServing: 27,
            proteinPerServing: 0.0,
            carbsPerServing: 6.9,
            fatPerServing: 0.0,
            servingSizeDescription: "100mL"
        ),
        CommonFood(
            name: "McDonald's Chocolate Thickshake",
            caloriesPerServing: 125,
            proteinPerServing: 3.8,
            carbsPerServing: 21.8,
            fatPerServing: 3.4,
            servingSizeDescription: "100mL"
        ),
        CommonFood(
            name: "McDonald's Strawberry Thickshake",
            caloriesPerServing: 125,
            proteinPerServing: 2.2,
            carbsPerServing: 13.7,
            fatPerServing: 2.0,
            servingSizeDescription: "100mL"
        ),
        CommonFood(
            name: "McDonald's Vanilla Thickshake",
            caloriesPerServing: 123,
            proteinPerServing: 2.1,
            carbsPerServing: 12.5,
            fatPerServing: 1.9,
            servingSizeDescription: "100mL"
        ),
        CommonFood(
            name: "McDonald's Chocolate Frappé",
            caloriesPerServing: 113,
            proteinPerServing: 1.9,
            carbsPerServing: 16.4,
            fatPerServing: 4.7,
            servingSizeDescription: "100mL"
        ),
        CommonFood(
            name: "McDonald's Coffee Frappé",
            caloriesPerServing: 110,
            proteinPerServing: 2.1,
            carbsPerServing: 12.9,
            fatPerServing: 5.0,
            servingSizeDescription: "100mL"
        ),
        CommonFood(
            name: "McDonald's Salted Caramel Frappé",
            caloriesPerServing: 102,
            proteinPerServing: 2.2,
            carbsPerServing: 11.1,
            fatPerServing: 5.4,
            servingSizeDescription: "100mL"
        ),
        // MARK: - Fast Food: Guzman y Gomez (GYG) (Sept 2025)

        CommonFood(
            name: "GYG Burrito - Mild Grilled Chicken",
            caloriesPerServing: 773,
            proteinPerServing: 48.3,
            carbsPerServing: 91.0,
            fatPerServing: 23.5,
            servingSizeDescription: "1 Burrito (480g)"
        ),
        CommonFood(
            name: "GYG Burrito - Mild Ground Beef",
            caloriesPerServing: 828,
            proteinPerServing: 36.7,
            carbsPerServing: 93.9,
            fatPerServing: 33.5,
            servingSizeDescription: "1 Burrito (480g)"
        ),
        CommonFood(
            name: "GYG Burrito - Mild Pulled Pork",
            caloriesPerServing: 759,
            proteinPerServing: 42.1,
            carbsPerServing: 90.4,
            fatPerServing: 24.9,
            servingSizeDescription: "1 Burrito (480g)"
        ),
        CommonFood(
            name: "GYG Cali Burrito - Mild Grilled Chicken",
            caloriesPerServing: 966,
            proteinPerServing: 47.5,
            carbsPerServing: 77.8,
            fatPerServing: 50.4,
            servingSizeDescription: "1 Cali Burrito (470g)"
        ),
        CommonFood(
            name: "GYG Cali Burrito - Mild Ground Beef",
            caloriesPerServing: 1020,
            proteinPerServing: 35.9,
            carbsPerServing: 80.7,
            fatPerServing: 60.4,
            servingSizeDescription: "1 Cali Burrito (470g)"
        ),
        CommonFood(
            name: "GYG Burrito Bowl - Mild Grilled Chicken",
            caloriesPerServing: 659,
            proteinPerServing: 43.8,
            carbsPerServing: 74.1,
            fatPerServing: 20.5,
            servingSizeDescription: "1 Bowl (455g)"
        ),
        CommonFood(
            name: "GYG Burrito Bowl - Mild Ground Beef",
            caloriesPerServing: 714,
            proteinPerServing: 32.2,
            carbsPerServing: 77.0,
            fatPerServing: 30.5,
            servingSizeDescription: "1 Bowl (455g)"
        ),
        CommonFood(
            name: "GYG Nachos - Mild Grilled Chicken",
            caloriesPerServing: 1110,
            proteinPerServing: 52.3,
            carbsPerServing: 77.7,
            fatPerServing: 64.3,
            servingSizeDescription: "1 Nachos (500g)"
        ),
        CommonFood(
            name: "GYG Nachos - Mild Ground Beef",
            caloriesPerServing: 1160,
            proteinPerServing: 40.7,
            carbsPerServing: 80.6,
            fatPerServing: 74.3,
            servingSizeDescription: "1 Nachos (500g)"
        ),
        CommonFood(
            name: "GYG Soft Taco - Mild Grilled Chicken",
            caloriesPerServing: 192,
            proteinPerServing: 15.8,
            carbsPerServing: 15.6,
            fatPerServing: 7.1,
            servingSizeDescription: "1 Taco (118g)"
        ),
        CommonFood(
            name: "GYG Hard Taco - Mild Ground Beef",
            caloriesPerServing: 208,
            proteinPerServing: 10.2,
            carbsPerServing: 14.4,
            fatPerServing: 11.7,
            servingSizeDescription: "1 Taco (109g)"
        ),
        CommonFood(
            name: "GYG $3 Taco - Mild Ground Beef",
            caloriesPerServing: 161,
            proteinPerServing: 7.3,
            carbsPerServing: 12.6,
            fatPerServing: 8.7,
            servingSizeDescription: "1 Taco (74g)"
        ),
        CommonFood(
            name: "GYG Fries (Medium, Chipotle Seasoning)",
            caloriesPerServing: 358,
            proteinPerServing: 5.3,
            carbsPerServing: 40.7,
            fatPerServing: 18.5,
            servingSizeDescription: "1 Serve (120g)"
        ),
        CommonFood(
            name: "GYG Churros with Chocolate Sauce",
            caloriesPerServing: 400,
            proteinPerServing: 5.8,
            carbsPerServing: 45.4,
            fatPerServing: 21.3,
            servingSizeDescription: "1 Serve (108g)"
        ),
        CommonFood(
            name: "GYG Churros with Dulce de Leche",
            caloriesPerServing: 366,
            proteinPerServing: 6.7,
            carbsPerServing: 42.7,
            fatPerServing: 17.0,
            servingSizeDescription: "1 Serve (106g)"
        ),
        CommonFood(
            name: "GYG Kids Burrito - Mild Grilled Chicken",
            caloriesPerServing: 414,
            proteinPerServing: 24.8,
            carbsPerServing: 46.1,
            fatPerServing: 14.1,
            servingSizeDescription: "1 Kids Burrito (175g)"
        ),
        CommonFood(
            name: "GYG Kids Bowl - Mild Grilled Chicken",
            caloriesPerServing: 433,
            proteinPerServing: 23.1,
            carbsPerServing: 41.9,
            fatPerServing: 18.9,
            servingSizeDescription: "1 Kids Bowl (214g)"
        ),
        CommonFood(
            name: "GYG Guacamole (Small Side)",
            caloriesPerServing: 165,
            proteinPerServing: 1.6,
            carbsPerServing: 0.6,
            fatPerServing: 17.3,
            servingSizeDescription: "1 Side (92g)"
        ),
        // MARK: - Fast Food: Subway Australia (Oct 2025)

        CommonFood(
            name: "Subway 6-Inch Chicken & Bacon Ranch",
            caloriesPerServing: 466,
            proteinPerServing: 28.9,
            carbsPerServing: 39.1,
            fatPerServing: 21.0,
            servingSizeDescription: "1 6-Inch Sub (256g)"
        ),
        CommonFood(
            name: "Subway 6-Inch Chicken Classic",
            caloriesPerServing: 492,
            proteinPerServing: 22.3,
            carbsPerServing: 47.5,
            fatPerServing: 22.8,
            servingSizeDescription: "1 6-Inch Sub (248g)"
        ),
        CommonFood(
            name: "Subway 6-Inch Chicken Schnitzel",
            caloriesPerServing: 538,
            proteinPerServing: 23.6,
            carbsPerServing: 49.5,
            fatPerServing: 29.9,
            servingSizeDescription: "1 6-Inch Sub (268g)"
        ),
        CommonFood(
            name: "Subway 6-Inch Italian B.M.T.",
            caloriesPerServing: 506,
            proteinPerServing: 24.6,
            carbsPerServing: 42.5,
            fatPerServing: 25.8,
            servingSizeDescription: "1 6-Inch Sub (238g)"
        ),
        CommonFood(
            name: "Subway 6-Inch Meatball",
            caloriesPerServing: 561,
            proteinPerServing: 24.0,
            carbsPerServing: 51.8,
            fatPerServing: 28.4,
            servingSizeDescription: "1 6-Inch Sub (290g)"
        ),
        CommonFood(
            name: "Subway 6-Inch Pizza Melt",
            caloriesPerServing: 450,
            proteinPerServing: 21.4,
            carbsPerServing: 42.6,
            fatPerServing: 20.8,
            servingSizeDescription: "1 6-Inch Sub (201g)"
        ),
        CommonFood(
            name: "Subway 6-Inch Sweet Onion Chicken Teriyaki",
            caloriesPerServing: 396,
            proteinPerServing: 25.3,
            carbsPerServing: 54.5,
            fatPerServing: 8.0,
            servingSizeDescription: "1 6-Inch Sub (257g)"
        ),
        CommonFood(
            name: "Subway 6-Inch Tuna Mayo",
            caloriesPerServing: 377,
            proteinPerServing: 21.8,
            carbsPerServing: 38.2,
            fatPerServing: 14.5,
            servingSizeDescription: "1 6-Inch Sub (220g)"
        ),
        CommonFood(
            name: "Subway 6-Inch Veggie Delite with Avo",
            caloriesPerServing: 377,
            proteinPerServing: 14.7,
            carbsPerServing: 44.5,
            fatPerServing: 16.1,
            servingSizeDescription: "1 6-Inch Sub (219g)"
        ),
        CommonFood(
            name: "Subway Wrap - Chicken & Bacon Ranch",
            caloriesPerServing: 499,
            proteinPerServing: 27.8,
            carbsPerServing: 40.4,
            fatPerServing: 24.7,
            servingSizeDescription: "1 Wrap (264g)"
        ),
        CommonFood(
            name: "Subway Wrap - Chicken Schnitzel",
            caloriesPerServing: 532,
            proteinPerServing: 24.9,
            carbsPerServing: 48.6,
            fatPerServing: 26.8,
            servingSizeDescription: "1 Wrap (264g)"
        ),
        CommonFood(
            name: "Subway Wrap - Sweet Onion Chicken Teriyaki",
            caloriesPerServing: 429,
            proteinPerServing: 24.2,
            carbsPerServing: 55.8,
            fatPerServing: 11.6,
            servingSizeDescription: "1 Wrap (265g)"
        ),
        CommonFood(
            name: "Subway Salad - Chicken & Bacon Ranch",
            caloriesPerServing: 291,
            proteinPerServing: 22.6,
            carbsPerServing: 6.3,
            fatPerServing: 19.4,
            servingSizeDescription: "1 Salad (299g)"
        ),
        CommonFood(
            name: "Subway Cookie - Chocolate Chip",
            caloriesPerServing: 223,
            proteinPerServing: 2.3,
            carbsPerServing: 29.4,
            fatPerServing: 10.7,
            servingSizeDescription: "1 Cookie (45g)"
        ),
        CommonFood(
            name: "Subway Cookie - White Chip Macadamia",
            caloriesPerServing: 223,
            proteinPerServing: 2.2,
            carbsPerServing: 28.3,
            fatPerServing: 11.2,
            servingSizeDescription: "1 Cookie (45g)"
        ),
        // MARK: - Fast Food: Zambrero (Oct 2025)

        CommonFood(
            name: "Zambrero Classic Burrito - Grilled Chicken",
            caloriesPerServing: 752,
            proteinPerServing: 34.8,
            carbsPerServing: 85.6,
            fatPerServing: 29.2,
            servingSizeDescription: "1 Burrito (~492g)"
        ),
        CommonFood(
            name: "Zambrero Classic Burrito - Barbacoa Beef",
            caloriesPerServing: 750,
            proteinPerServing: 37.4,
            carbsPerServing: 83.7,
            fatPerServing: 29.8,
            servingSizeDescription: "1 Burrito (~472g)"
        ),
        CommonFood(
            name: "Zambrero Classic Burrito - Pulled Pork",
            caloriesPerServing: 752,
            proteinPerServing: 32.1,
            carbsPerServing: 84.8,
            fatPerServing: 31.0,
            servingSizeDescription: "1 Burrito (~491g)"
        ),
        CommonFood(
            name: "Zambrero Classic Bowl - Grilled Chicken",
            caloriesPerServing: 468,
            proteinPerServing: 28.2,
            carbsPerServing: 40.0,
            fatPerServing: 21.2,
            servingSizeDescription: "1 Bowl (~400g)"
        ),
        CommonFood(
            name: "Zambrero Classic Bowl - Barbacoa Beef",
            caloriesPerServing: 499,
            proteinPerServing: 29.4,
            carbsPerServing: 43.3,
            fatPerServing: 22.7,
            servingSizeDescription: "1 Bowl (~400g)"
        ),
        CommonFood(
            name: "Zambrero Nachos - Grilled Chicken",
            caloriesPerServing: 799,
            proteinPerServing: 37.3,
            carbsPerServing: 49.9,
            fatPerServing: 49.8,
            servingSizeDescription: "1 Serve (~367g)"
        ),
        CommonFood(
            name: "Zambrero Nachos - Barbacoa Beef",
            caloriesPerServing: 831,
            proteinPerServing: 39.2,
            carbsPerServing: 52.6,
            fatPerServing: 51.3,
            servingSizeDescription: "1 Serve (~366g)"
        ),
        CommonFood(
            name: "Zambrero Soft Taco - Grilled Chicken",
            caloriesPerServing: 223,
            proteinPerServing: 12.4,
            carbsPerServing: 18.0,
            fatPerServing: 11.0,
            servingSizeDescription: "1 Taco (~144g)"
        ),
        CommonFood(
            name: "Zambrero Hard Taco - Grilled Chicken",
            caloriesPerServing: 204,
            proteinPerServing: 10.9,
            carbsPerServing: 12.6,
            fatPerServing: 11.9,
            servingSizeDescription: "1 Taco (~129g)"
        ),
        CommonFood(
            name: "Zambrero Churros with Chocolate Sauce",
            caloriesPerServing: 400,
            proteinPerServing: 5.8,
            carbsPerServing: 45.4,
            fatPerServing: 21.3,
            servingSizeDescription: "1 Serve (108g)"
        ),
        // MARK: - Fast Food: KFC Australia

        CommonFood(
            name: "KFC Zinger Burger",
            caloriesPerServing: 237, // 991 kJ
            proteinPerServing: 13.1,
            carbsPerServing: 23.3,
            fatPerServing: 9.8,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "KFC Zinger Stacker Burger",
            caloriesPerServing: 263, // 1100 kJ
            proteinPerServing: 13.5,
            carbsPerServing: 21.9,
            fatPerServing: 13.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "KFC Original Recipe Burger",
            caloriesPerServing: 206, // 860 kJ
            proteinPerServing: 11.4,
            carbsPerServing: 23.3,
            fatPerServing: 7.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "KFC Original Bacon & Cheese Burger",
            caloriesPerServing: 241, // 1010 kJ
            proteinPerServing: 12.9,
            carbsPerServing: 23.2,
            fatPerServing: 10.7,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "KFC Original Twister",
            caloriesPerServing: 220, // 920 kJ
            proteinPerServing: 10.9,
            carbsPerServing: 22.9,
            fatPerServing: 9.0,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "KFC Zinger Twister",
            caloriesPerServing: 226, // 948 kJ
            proteinPerServing: 11.0,
            carbsPerServing: 22.9,
            fatPerServing: 10.2,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "KFC Original Recipe Chicken",
            caloriesPerServing: 248, // 1036 kJ
            proteinPerServing: 20.6,
            carbsPerServing: 11.2,
            fatPerServing: 13.5,
            servingSizeDescription: "100g (Avg piece)"
        ),
        CommonFood(
            name: "KFC Hot & Crispy Chicken",
            caloriesPerServing: 291, // 1216 kJ
            proteinPerServing: 19.3,
            carbsPerServing: 18.0,
            fatPerServing: 15.6,
            servingSizeDescription: "100g (Avg piece)"
        ),
        CommonFood(
            name: "KFC Wicked Wings",
            caloriesPerServing: 301, // 1260 kJ
            proteinPerServing: 17.5,
            carbsPerServing: 15.3,
            fatPerServing: 18.6,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "KFC Popcorn Chicken (Regular)",
            caloriesPerServing: 311, // 1300 kJ
            proteinPerServing: 15.1,
            carbsPerServing: 19.4,
            fatPerServing: 19.1,
            servingSizeDescription: "1 Serve (95g)"
        ),
        CommonFood(
            name: "KFC Chips (Regular)",
            caloriesPerServing: 284, // 1190 kJ
            proteinPerServing: 3.5,
            carbsPerServing: 34.0,
            fatPerServing: 14.3,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "KFC Potato & Gravy (Regular)",
            caloriesPerServing: 68, // 285 kJ
            proteinPerServing: 1.5,
            carbsPerServing: 9.8,
            fatPerServing: 2.5,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "KFC Coleslaw (Regular)",
            caloriesPerServing: 143, // 600 kJ
            proteinPerServing: 1.0,
            carbsPerServing: 12.0,
            fatPerServing: 10.1,
            servingSizeDescription: "100g"
        ),
        CommonFood(
            name: "KFC Chocolate Mousse",
            caloriesPerServing: 206, // 864 kJ
            proteinPerServing: 3.9,
            carbsPerServing: 24.3,
            fatPerServing: 10.3,
            servingSizeDescription: "1 Serve (95g)"
        ),
        CommonFood(
            name: "KFC Pepsi (Medium)",
            caloriesPerServing: 43, // 180 kJ
            proteinPerServing: 0.0,
            carbsPerServing: 11.7,
            fatPerServing: 0.0,
            servingSizeDescription: "100mL"
        ),
        CommonFood(
            name: "KFC Popcorn Chicken Go Bucket",
            caloriesPerServing: 517,
            proteinPerServing: 18.8,
            carbsPerServing: 51.4,
            fatPerServing: 26.4,
            servingSizeDescription: "1 Bucket (194g)"
        ),
        // MARK: - Fast Food: KFC Australia

        CommonFood(
            name: "KFC Zinger Burger",
            caloriesPerServing: 434,
            proteinPerServing: 28.9,
            carbsPerServing: 43.2,
            fatPerServing: 18.3,
            servingSizeDescription: "1 Burger (199g)"
        ),
        CommonFood(
            name: "KFC Original Recipe Burger",
            caloriesPerServing: 435,
            proteinPerServing: 26.4,
            carbsPerServing: 40.1,
            fatPerServing: 16.7,
            servingSizeDescription: "1 Burger (183g)"
        ),
        CommonFood(
            name: "KFC Original Crunch Twister",
            caloriesPerServing: 584,
            proteinPerServing: 24.5,
            carbsPerServing: 51.0,
            fatPerServing: 30.3,
            servingSizeDescription: "1 Twister (250g)"
        ),
        CommonFood(
            name: "KFC Zinger Crunch Twister",
            caloriesPerServing: 574,
            proteinPerServing: 29.6,
            carbsPerServing: 56.3,
            fatPerServing: 27.7,
            servingSizeDescription: "1 Twister"
        ),
        CommonFood(
            name: "KFC Original Recipe Chicken Breast",
            caloriesPerServing: 459,
            proteinPerServing: 35.8,
            carbsPerServing: 15.4,
            fatPerServing: 28.4,
            servingSizeDescription: "1 Piece (164g)"
        ),
        CommonFood(
            name: "KFC Original Recipe Chicken Thigh",
            caloriesPerServing: 263,
            proteinPerServing: 20.5,
            carbsPerServing: 8.8,
            fatPerServing: 16.3,
            servingSizeDescription: "1 Piece (94g)"
        ),
        CommonFood(
            name: "KFC Original Recipe Chicken Drumstick",
            caloriesPerServing: 216,
            proteinPerServing: 16.8,
            carbsPerServing: 7.2,
            fatPerServing: 13.3,
            servingSizeDescription: "1 Piece (77g)"
        ),
        CommonFood(
            name: "KFC Original Recipe Tender",
            caloriesPerServing: 186,
            proteinPerServing: 19.1,
            carbsPerServing: 5.3,
            fatPerServing: 9.2,
            servingSizeDescription: "1 Tender (79g)"
        ),
        CommonFood(
            name: "KFC Wicked Wing",
            caloriesPerServing: 131,
            proteinPerServing: 7.0,
            carbsPerServing: 5.1,
            fatPerServing: 7.8,
            servingSizeDescription: "1 Wing (38g)"
        ),
        CommonFood(
            name: "KFC Popcorn Chicken (Regular)",
            caloriesPerServing: 412,
            proteinPerServing: 24.3,
            carbsPerServing: 20.4,
            fatPerServing: 26.1,
            servingSizeDescription: "1 Serve (128g)"
        ),
        CommonFood(
            name: "KFC Go Bucket (Popcorn Chicken)",
            caloriesPerServing: 517, // 2165 kJ
            proteinPerServing: 18.8,
            carbsPerServing: 51.4,
            fatPerServing: 26.4,
            servingSizeDescription: "1 Bucket (194g)"
        ),
        CommonFood(
            name: "KFC Nuggets (6 Pack)",
            caloriesPerServing: 319,
            proteinPerServing: 16.3,
            carbsPerServing: 28.6,
            fatPerServing: 15.5,
            servingSizeDescription: "1 Serve (127g)"
        ),
        CommonFood(
            name: "KFC Chips (Regular)",
            caloriesPerServing: 279,
            proteinPerServing: 4.7,
            carbsPerServing: 39.6,
            fatPerServing: 11.3,
            servingSizeDescription: "1 Serve (120g)"
        ),
        CommonFood(
            name: "KFC Potato & Gravy (Regular)",
            caloriesPerServing: 71,
            proteinPerServing: 1.9,
            carbsPerServing: 13.8,
            fatPerServing: 0.9,
            servingSizeDescription: "1 Serve (110g)"
        ),
        CommonFood(
            name: "KFC Coleslaw (Regular)",
            caloriesPerServing: 98,
            proteinPerServing: 1.0,
            carbsPerServing: 14.2,
            fatPerServing: 4.0,
            servingSizeDescription: "1 Serve (110g)"
        ),
        CommonFood(
                        name: "Chicken Breast Fillet (Raw)",
                        caloriesPerServing: 120,
                        proteinPerServing: 22.5,
                        carbsPerServing: 0,
                        fatPerServing: 2.6,
                        fiberPerServing: 0,
                        sugarPerServing: 0,
                        saltPerServing: 0.1,
                        potassiumPerServing: 334,
                        servingSizeDescription: "100g",
                        isHalal: false // Often Halal in Aus, but check specific pack logo
                    ),
                    CommonFood(
                        name: "Chicken Thigh Fillet (Skinless, Raw)",
                        caloriesPerServing: 177,
                        proteinPerServing: 23.2,
                        carbsPerServing: 0,
                        fatPerServing: 8.1,
                        fiberPerServing: 0,
                        sugarPerServing: 0,
                        saltPerServing: 0.2,
                        potassiumPerServing: 240,
                        servingSizeDescription: "100g",
                        isHalal: false
                    ),
                    CommonFood(
                        name: "Chicken Drumstick (Skin On, Raw)",
                        caloriesPerServing: 161,
                        proteinPerServing: 18.0,
                        carbsPerServing: 0,
                        fatPerServing: 9.0,
                        fiberPerServing: 0,
                        sugarPerServing: 0,
                        saltPerServing: 0.2,
                        potassiumPerServing: 211,
                        servingSizeDescription: "100g",
                        isHalal: false
                    ),
                    CommonFood(
                        name: "Chicken Mince (Raw)",
                        caloriesPerServing: 143,
                        proteinPerServing: 17.0,
                        carbsPerServing: 0,
                        fatPerServing: 8.0,
                        fiberPerServing: 0,
                        sugarPerServing: 0,
                        saltPerServing: 0.1,
                        potassiumPerServing: 300,
                        servingSizeDescription: "100g"
                    ),

                    // --- Beef ---
                    CommonFood(
                        name: "Beef Rump Steak (Raw, Trimmed)",
                        caloriesPerServing: 147,
                        proteinPerServing: 23.0,
                        carbsPerServing: 0,
                        fatPerServing: 6.3,
                        fiberPerServing: 0,
                        sugarPerServing: 0,
                        saltPerServing: 0.1,
                        potassiumPerServing: 332,
                        servingSizeDescription: "100g",
                        isHalal: false // Look for 'Signature Beef' Halal range at Woolies
                    ),
                    CommonFood(
                        name: "Beef Mince (Lean, Raw)",
                        caloriesPerServing: 124,
                        proteinPerServing: 21.0,
                        carbsPerServing: 0,
                        fatPerServing: 4.8,
                        fiberPerServing: 0,
                        sugarPerServing: 0,
                        saltPerServing: 0.15,
                        potassiumPerServing: 348,
                        servingSizeDescription: "100g"
                    ),
                    CommonFood(
                        name: "Beef Scotch Fillet (Raw)",
                        caloriesPerServing: 210,
                        proteinPerServing: 19.0,
                        carbsPerServing: 0,
                        fatPerServing: 15.0,
                        fiberPerServing: 0,
                        sugarPerServing: 0,
                        saltPerServing: 0.1,
                        potassiumPerServing: 290,
                        servingSizeDescription: "100g"
                    ),

                    // --- Lamb ---
                    CommonFood(
                        name: "Lamb Leg Roast (Raw)",
                        caloriesPerServing: 143,
                        proteinPerServing: 21.0,
                        carbsPerServing: 0,
                        fatPerServing: 6.0,
                        fiberPerServing: 0,
                        sugarPerServing: 0,
                        saltPerServing: 0.15,
                        potassiumPerServing: 342,
                        servingSizeDescription: "100g"
                    ),
                    CommonFood(
                        name: "Lamb Loin Chop (Raw)",
                        caloriesPerServing: 215,
                        proteinPerServing: 32.0,
                        carbsPerServing: 0,
                        fatPerServing: 9.6,
                        fiberPerServing: 0,
                        sugarPerServing: 0,
                        saltPerServing: 0.17,
                        potassiumPerServing: 330,
                        servingSizeDescription: "100g"
                    ),
                    CommonFood(
                        name: "Lamb Cutlet (Trimmed, Raw)",
                        caloriesPerServing: 170,
                        proteinPerServing: 20.0,
                        carbsPerServing: 0,
                        fatPerServing: 10.0,
                        fiberPerServing: 0,
                        sugarPerServing: 0,
                        saltPerServing: 0.2,
                        potassiumPerServing: 280,
                        servingSizeDescription: "100g"
                    ),

                    // --- Pork ---
                    CommonFood(
                        name: "Pork Loin Steak (Lean, Raw)",
                        caloriesPerServing: 130,
                        proteinPerServing: 22.0,
                        carbsPerServing: 0,
                        fatPerServing: 4.5,
                        fiberPerServing: 0,
                        sugarPerServing: 0,
                        saltPerServing: 0.1,
                        potassiumPerServing: 360,
                        servingSizeDescription: "100g"
                    ),
                    CommonFood(
                        name: "Pork Belly (Raw)",
                        caloriesPerServing: 518,
                        proteinPerServing: 9.3,
                        carbsPerServing: 0,
                        fatPerServing: 53.0,
                        fiberPerServing: 0,
                        sugarPerServing: 0,
                        saltPerServing: 0.1,
                        potassiumPerServing: 185,
                        servingSizeDescription: "100g"
                    ),
        CommonFood(
                        name: "Carrot (Raw)",
                        caloriesPerServing: 40,
                        proteinPerServing: 0.8,
                        carbsPerServing: 7.6,
                        fatPerServing: 0.2,
                        fiberPerServing: 2.8,
                        sugarPerServing: 4.7,
                        saltPerServing: 0.1,
                        potassiumPerServing: 320,
                        servingSizeDescription: "100g",
                        isHalal: true
                    ),
                    CommonFood(
                        name: "Potato - Washed/White (Raw)",
                        caloriesPerServing: 63,
                        proteinPerServing: 2.3,
                        carbsPerServing: 12.8,
                        fatPerServing: 0.1,
                        fiberPerServing: 1.1,
                        sugarPerServing: 0.6,
                        saltPerServing: 0.01,
                        potassiumPerServing: 513,
                        servingSizeDescription: "100g",
                        isHalal: true
                    ),
                    CommonFood(
                        name: "Sweet Potato - Gold (Raw)",
                        caloriesPerServing: 86,
                        proteinPerServing: 1.6,
                        carbsPerServing: 20.1,
                        fatPerServing: 0.1,
                        fiberPerServing: 3.0,
                        sugarPerServing: 4.2,
                        saltPerServing: 0.14,
                        potassiumPerServing: 337,
                        servingSizeDescription: "100g",
                        isHalal: true
                    ),
                    CommonFood(
                        name: "Onion - Brown (Raw)",
                        caloriesPerServing: 40,
                        proteinPerServing: 1.1,
                        carbsPerServing: 9.3,
                        fatPerServing: 0.1,
                        fiberPerServing: 1.7,
                        sugarPerServing: 4.2,
                        saltPerServing: 0.01,
                        potassiumPerServing: 146,
                        servingSizeDescription: "100g",
                        isHalal: true
                    ),

                    // --- Greens & Cruciferous ---
                    CommonFood(
                        name: "Broccoli (Raw)",
                        caloriesPerServing: 34,
                        proteinPerServing: 2.8,
                        carbsPerServing: 6.6,
                        fatPerServing: 0.4,
                        fiberPerServing: 2.6,
                        sugarPerServing: 1.7,
                        saltPerServing: 0.06,
                        potassiumPerServing: 316,
                        servingSizeDescription: "100g",
                        isHalal: true
                    ),
                    CommonFood(
                        name: "Baby Spinach (Raw)",
                        caloriesPerServing: 23,
                        proteinPerServing: 2.9,
                        carbsPerServing: 3.6,
                        fatPerServing: 0.4,
                        fiberPerServing: 2.2,
                        sugarPerServing: 0.4,
                        saltPerServing: 0.2,
                        potassiumPerServing: 558,
                        servingSizeDescription: "100g",
                        isHalal: true
                    ),
                    CommonFood(
                        name: "Zucchini (Raw)",
                        caloriesPerServing: 17,
                        proteinPerServing: 1.2,
                        carbsPerServing: 3.1,
                        fatPerServing: 0.3,
                        fiberPerServing: 1.0,
                        sugarPerServing: 2.5,
                        saltPerServing: 0.02,
                        potassiumPerServing: 261,
                        servingSizeDescription: "100g",
                        isHalal: true
                    ),

                    // --- Salad & Others ---
                    CommonFood(
                        name: "Tomato (Raw)",
                        caloriesPerServing: 18,
                        proteinPerServing: 0.9,
                        carbsPerServing: 3.9,
                        fatPerServing: 0.2,
                        fiberPerServing: 1.2,
                        sugarPerServing: 2.6,
                        saltPerServing: 0.01,
                        potassiumPerServing: 237,
                        servingSizeDescription: "100g",
                        isHalal: true
                    ),
                    CommonFood(
                        name: "Cucumber - Lebanese (Raw)",
                        caloriesPerServing: 15,
                        proteinPerServing: 0.7,
                        carbsPerServing: 3.6,
                        fatPerServing: 0.1,
                        fiberPerServing: 0.5,
                        sugarPerServing: 1.7,
                        saltPerServing: 0.01,
                        potassiumPerServing: 147,
                        servingSizeDescription: "100g",
                        isHalal: true
                    ),
                    CommonFood(
                        name: "Capsicum - Red (Raw)",
                        caloriesPerServing: 31,
                        proteinPerServing: 1.0,
                        carbsPerServing: 6.0,
                        fatPerServing: 0.3,
                        fiberPerServing: 2.1,
                        sugarPerServing: 4.2,
                        saltPerServing: 0.01,
                        potassiumPerServing: 211,
                        servingSizeDescription: "100g",
                        isHalal: true
                    ),
                    CommonFood(
                        name: "Mushroom - Cup (Raw)",
                        caloriesPerServing: 22,
                        proteinPerServing: 3.1,
                        carbsPerServing: 3.3,
                        fatPerServing: 0.3,
                        fiberPerServing: 1.0,
                        sugarPerServing: 2.0,
                        saltPerServing: 0.01,
                        potassiumPerServing: 318,
                        servingSizeDescription: "100g",
                        isHalal: true
                    ),
                    CommonFood(
                        name: "Pumpkin - Butternut (Raw)",
                        caloriesPerServing: 45,
                        proteinPerServing: 1.0,
                        carbsPerServing: 11.7,
                        fatPerServing: 0.1,
                        fiberPerServing: 2.0,
                        sugarPerServing: 2.2,
                        saltPerServing: 0.01,
                        potassiumPerServing: 352,
                        servingSizeDescription: "100g",
                        isHalal: true
                    ),
                    CommonFood(
                        name: "Sweet Corn (Raw)",
                        caloriesPerServing: 86,
                        proteinPerServing: 3.2,
                        carbsPerServing: 19.0,
                        fatPerServing: 1.2,
                        fiberPerServing: 2.7,
                        sugarPerServing: 3.2,
                        saltPerServing: 0.04,
                        potassiumPerServing: 270,
                        servingSizeDescription: "100g",
                        isHalal: true
                    ),
    ]
}
