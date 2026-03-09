//
//  UserProfile.swift
//  Yard2Yum
//
//  Created by Eric Liu on 09/03/2026.
//

import Foundation
import FirebaseFirestore
import Combine

struct UserProfile: Codable {
    var userID: String
    var username: String
    var email: String
    var userType: String // "Restaurant", "Farm", or "Composting Facility"
    
    // Restaurant specific
    var restaurantName: String?
    var restaurantType: String?
    
    // Farm specific
    var farmName: String?
    var farmLocation: String?
    
    // Facility specific
    var facilityName: String?
    
    // Progress tracking
    var totalDonatedLbs: Double?
    var totalPoints: Int?
    
    var createdAt: Date
    var updatedAt: Date
    
    init(userID: String, username: String, email: String, userType: String) {
        self.userID = userID
        self.username = username
        self.email = email
        self.userType = userType
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

class FirestoreManager: ObservableObject {
    private let db = Firestore.firestore()
    
    // MARK: - Create User Profile
    func createUserProfile(_ profile: UserProfile) async throws {
        let data: [String: Any] = [
            "userID": profile.userID,
            "username": profile.username,
            "email": profile.email,
            "userType": profile.userType,
            "restaurantName": profile.restaurantName ?? "",
            "restaurantType": profile.restaurantType ?? "",
            "farmName": profile.farmName ?? "",
            "farmLocation": profile.farmLocation ?? "",
            "facilityName": profile.facilityName ?? "",
            "totalDonatedLbs": profile.totalDonatedLbs ?? 0,
            "totalPoints": profile.totalPoints ?? 0,
            "createdAt": Timestamp(date: profile.createdAt),
            "updatedAt": Timestamp(date: profile.updatedAt)
        ]
        
        try await db.collection("users").document(profile.userID).setData(data)
    }
    
    // MARK: - Get User Profile
    func getUserProfile(userID: String) async throws -> UserProfile? {
        let document = try await db.collection("users").document(userID).getDocument()
        
        guard document.exists,
              let data = document.data(),
              let username = data["username"] as? String,
              let email = data["email"] as? String,
              let userType = data["userType"] as? String else {
            return nil
        }
        
        var profile = UserProfile(userID: userID, username: username, email: email, userType: userType)
        
        // Load optional fields
        profile.restaurantName = data["restaurantName"] as? String
        profile.restaurantType = data["restaurantType"] as? String
        profile.farmName = data["farmName"] as? String
        profile.farmLocation = data["farmLocation"] as? String
        profile.facilityName = data["facilityName"] as? String
        profile.totalDonatedLbs = data["totalDonatedLbs"] as? Double ?? 0
        profile.totalPoints = data["totalPoints"] as? Int ?? 0
        
        if let createdAt = data["createdAt"] as? Timestamp {
            profile.createdAt = createdAt.dateValue()
        }
        if let updatedAt = data["updatedAt"] as? Timestamp {
            profile.updatedAt = updatedAt.dateValue()
        }
        
        return profile
    }
    
    // MARK: - Update User Profile
    func updateUserProfile(_ profile: UserProfile) async throws {
        let data: [String: Any] = [
            "username": profile.username,
            "userType": profile.userType,
            "restaurantName": profile.restaurantName ?? "",
            "restaurantType": profile.restaurantType ?? "",
            "farmName": profile.farmName ?? "",
            "farmLocation": profile.farmLocation ?? "",
            "facilityName": profile.facilityName ?? "",
            "totalDonatedLbs": profile.totalDonatedLbs ?? 0,
            "totalPoints": profile.totalPoints ?? 0,
            "updatedAt": Timestamp(date: Date())
        ]
        
        try await db.collection("users").document(profile.userID).updateData(data)
    }
    
    // MARK: - Update Restaurant Info
    func updateRestaurantInfo(userID: String, name: String, type: String) async throws {
        try await db.collection("users").document(userID).updateData([
            "restaurantName": name,
            "restaurantType": type,
            "updatedAt": Timestamp(date: Date())
        ])
    }
    
    // MARK: - Update Farm Info
    func updateFarmInfo(userID: String, name: String, location: String) async throws {
        try await db.collection("users").document(userID).updateData([
            "farmName": name,
            "farmLocation": location,
            "updatedAt": Timestamp(date: Date())
        ])
    }
    
    // MARK: - Update Facility Info
    func updateFacilityInfo(userID: String, name: String) async throws {
        try await db.collection("users").document(userID).updateData([
            "facilityName": name,
            "updatedAt": Timestamp(date: Date())
        ])
    }
    
    // MARK: - Update Progress
    func updateProgress(userID: String, totalDonatedLbs: Double, totalPoints: Int) async throws {
        try await db.collection("users").document(userID).updateData([
            "totalDonatedLbs": totalDonatedLbs,
            "totalPoints": totalPoints,
            "updatedAt": Timestamp(date: Date())
        ])
    }
}
