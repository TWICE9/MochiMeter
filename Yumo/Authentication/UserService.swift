//
//  UserService.swift
//  Yumo
//

import Foundation
import Supabase
import Auth

// MARK: - RPC Params for create_user_if_missing
struct CreateUserParams: Encodable, Sendable {
    let p_user_id: UUID
    let p_name: String

    enum CodingKeys: String, CodingKey {
        case p_user_id
        case p_name
    }

    // Must be nonisolated to avoid MainActor inference
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(p_user_id, forKey: .p_user_id)
        try container.encode(p_name, forKey: .p_name)
    }
}

// MARK: - Struct for onboarding sync (Encodable + Sendable)
struct UpsertProfileParams: Encodable, Sendable {
    let user_id: UUID
    let name: String
    let birthdate: String
    let gender: String
    let height_cm: Int
    let weight_kg: Double
    let activity_level: String
    let weight_goal: Int
    let target_weight: Double

    let daily_calories: Int
    let daily_protein: Int
    let daily_carbs: Int
    let daily_fat: Int

    // New onboarding fields
    let blockers: [String]?
    let diet_type: String?
    let goals_to_accomplish: [String]?
    let referral_code: String?
    let healthkit_enabled: Bool

    enum CodingKeys: CodingKey {
        case user_id, name, birthdate, gender, height_cm, weight_kg
        case activity_level, weight_goal, target_weight
        case daily_calories, daily_protein, daily_carbs, daily_fat
        case blockers, diet_type, goals_to_accomplish, referral_code, healthkit_enabled
    }

    // Avoids isolated context issues
    nonisolated func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(user_id, forKey: .user_id)
        try c.encode(name, forKey: .name)
        try c.encode(birthdate, forKey: .birthdate)
        try c.encode(gender, forKey: .gender)
        try c.encode(height_cm, forKey: .height_cm)
        try c.encode(weight_kg, forKey: .weight_kg)
        try c.encode(activity_level, forKey: .activity_level)
        try c.encode(weight_goal, forKey: .weight_goal)
        try c.encode(target_weight, forKey: .target_weight)
        try c.encode(daily_calories, forKey: .daily_calories)
        try c.encode(daily_protein, forKey: .daily_protein)
        try c.encode(daily_carbs, forKey: .daily_carbs)
        try c.encode(daily_fat, forKey: .daily_fat)
        try c.encodeIfPresent(blockers, forKey: .blockers)
        try c.encodeIfPresent(diet_type, forKey: .diet_type)
        try c.encodeIfPresent(goals_to_accomplish, forKey: .goals_to_accomplish)
        try c.encodeIfPresent(referral_code, forKey: .referral_code)
        try c.encode(healthkit_enabled, forKey: .healthkit_enabled)
    }
}



// MARK: - Profile Response
struct ProfileResponse: Decodable, Sendable {
    let user_id: UUID
    let name: String
    let birthdate: String
    let gender: String
    let height_cm: Int
    let weight_kg: Double
    let activity_level: String
    let weight_goal: Int
    let target_weight: Double
    let daily_calories: Int
    let daily_protein: Int
    let daily_carbs: Int
    let daily_fat: Int

    // New onboarding fields
    let blockers: [String]?
    let diet_type: String?
    let goals_to_accomplish: [String]?
    let referral_code: String?
    let healthkit_enabled: Bool?

    // Premium override from Supabase (for family/manual grants)
    let is_premium: Bool?

    enum CodingKeys: CodingKey {
        case user_id, name, birthdate, gender, height_cm, weight_kg
        case activity_level, weight_goal, target_weight
        case daily_calories, daily_protein, daily_carbs, daily_fat
        case blockers, diet_type, goals_to_accomplish, referral_code, healthkit_enabled
        case is_premium
    }

    nonisolated init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        user_id = try c.decode(UUID.self, forKey: .user_id)
        name = try c.decode(String.self, forKey: .name)
        birthdate = try c.decode(String.self, forKey: .birthdate)
        gender = try c.decode(String.self, forKey: .gender)
        height_cm = try c.decode(Int.self, forKey: .height_cm)
        weight_kg = try c.decode(Double.self, forKey: .weight_kg)
        activity_level = try c.decode(String.self, forKey: .activity_level)
        weight_goal = try c.decode(Int.self, forKey: .weight_goal)
        target_weight = try c.decode(Double.self, forKey: .target_weight)
        daily_calories = try c.decode(Int.self, forKey: .daily_calories)
        daily_protein = try c.decode(Int.self, forKey: .daily_protein)
        daily_carbs = try c.decode(Int.self, forKey: .daily_carbs)
        daily_fat = try c.decode(Int.self, forKey: .daily_fat)
        blockers = try c.decodeIfPresent([String].self, forKey: .blockers)
        diet_type = try c.decodeIfPresent(String.self, forKey: .diet_type)
        goals_to_accomplish = try c.decodeIfPresent([String].self, forKey: .goals_to_accomplish)
        referral_code = try c.decodeIfPresent(String.self, forKey: .referral_code)
        healthkit_enabled = try c.decodeIfPresent(Bool.self, forKey: .healthkit_enabled)
        is_premium = try c.decodeIfPresent(Bool.self, forKey: .is_premium)
    }
}

// MARK: - Protocol
protocol UserService: Sendable {
    func ensureUserProfile(for user: User, fullName: String?) async throws
    @MainActor func uploadOnboardingData(for user: User, goals: UserGoals) async throws
    func downloadUserProfile(for user: User) async throws -> ProfileResponse?
    @MainActor func updateUserGoals(for user: User, goals: UserGoals) async throws
}



// MARK: - Implementation
actor SupabaseUserService: UserService {

    private let client: SupabaseClient

    init(client: SupabaseClient = supabase) {
        self.client = client
    }

    // ---------------------------------------------------------
    // 1️⃣ Ensure basic profile exists (your existing working code)
    // ---------------------------------------------------------
    func ensureUserProfile(for user: User, fullName: String?) async throws {
        let safeName = fullName ?? user.email ?? "Unknown User"

        let params = CreateUserParams(
            p_user_id: user.id,
            p_name: safeName
        )

        try await client.database
            .rpc("create_user_if_missing", params: params)
            .execute()

        print("🗄️ Ensured profile for user: \(safeName)")
    }



    // ---------------------------------------------------------
    // 2️⃣ Upload onboarding data → Supabase "profiles" table
    // ---------------------------------------------------------
    @MainActor func uploadOnboardingData(for user: User, goals: UserGoals) async throws {

        let birthString = ISO8601DateFormatter().string(from: goals.birthDate)

        let params = UpsertProfileParams(
            user_id: user.id,
            name: goals.name,
            birthdate: birthString,
            gender: goals.gender.rawValue,
            height_cm: Int(goals.height),
            weight_kg: goals.weight,
            activity_level: goals.activityLevel.rawValue,
            weight_goal: goals.weightGoal.rawValueAsInt,
            target_weight: goals.targetWeight,
            daily_calories: Int(goals.dailyCalories),
            daily_protein: Int(goals.dailyProtein),
            daily_carbs: Int(goals.dailyCarbs),
            daily_fat: Int(goals.dailyFat),
            blockers: goals.blockersRaw,
            diet_type: goals.dietTypeRaw,
            goals_to_accomplish: goals.goalsToAccomplishRaw,
            referral_code: goals.referralCode,
            healthkit_enabled: goals.healthKitEnabled
        )

        // Debug logging
        print("🐛 Uploading to Supabase profiles table:")
        print("   user_id: \(params.user_id)")
        print("   name: \(params.name)")
        print("   gender: \(params.gender)")
        print("   height_cm: \(params.height_cm)")
        print("   weight_kg: \(params.weight_kg)")
        print("   daily_calories: \(params.daily_calories)")
        print("   blockers: \(params.blockers ?? [])")
        print("   diet_type: \(params.diet_type ?? "nil")")
        print("   goals_to_accomplish: \(params.goals_to_accomplish ?? [])")

        do {
            try await client.database
                .from("profiles")
                .upsert(params)
                .execute()

            print("✅ Upserted onboarding → profiles table successfully")
        } catch {
            print("❌ Failed to upsert to profiles table:")
            print("   Error: \(error)")
            print("   Localized: \(error.localizedDescription)")
            throw error
        }
    }

    // ---------------------------------------------------------
    // 3️⃣ Download user profile from Supabase
    // ---------------------------------------------------------
    func downloadUserProfile(for user: User) async throws -> ProfileResponse? {
        let response = try await client.database
            .from("profiles")
            .select()
            .eq("user_id", value: user.id.uuidString)
            .single()
            .execute()

        let profile = try JSONDecoder().decode(ProfileResponse.self, from: response.data)
        print("📥 Downloaded profile for user: \(user.email ?? "Unknown")")
        return profile
    }

    // ---------------------------------------------------------
    // 4️⃣ Update user goals in Supabase (for ongoing changes)
    // ---------------------------------------------------------
    @MainActor func updateUserGoals(for user: User, goals: UserGoals) async throws {
        let birthString = ISO8601DateFormatter().string(from: goals.birthDate)

        let params = UpsertProfileParams(
            user_id: user.id,
            name: goals.name,
            birthdate: birthString,
            gender: goals.gender.rawValue,
            height_cm: Int(goals.height),
            weight_kg: goals.weight,
            activity_level: goals.activityLevel.rawValue,
            weight_goal: goals.weightGoal.rawValueAsInt,
            target_weight: goals.targetWeight,
            daily_calories: Int(goals.dailyCalories),
            daily_protein: Int(goals.dailyProtein),
            daily_carbs: Int(goals.dailyCarbs),
            daily_fat: Int(goals.dailyFat),
            blockers: goals.blockersRaw,
            diet_type: goals.dietTypeRaw,
            goals_to_accomplish: goals.goalsToAccomplishRaw,
            referral_code: goals.referralCode,
            healthkit_enabled: goals.healthKitEnabled
        )

        try await client.database
            .from("profiles")
            .upsert(params)
            .execute()

        print("📤 Updated user goals → Supabase")
    }
}



// MARK: - Small Helper Extensions

extension GoalType {
    /// Convert the enum to Int to match the SQL schema
    nonisolated var rawValueAsInt: Int {
        switch self {
        case .lose: return 0
        case .maintain: return 1
        case .gain: return 2
        }
    }
}
