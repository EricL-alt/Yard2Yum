// TypesenseManager.swift
// Yard2Yum — Local search for organization search (Prototype version)

import Foundation
import Combine
import CoreLocation

/// Manager for local organization search operations
class TypesenseManager: ObservableObject {
    @Published var isConfigured = false
    private var organizations: [OrganizationDocument] = []
    private var firestoreManager: FirestoreManager?
    
    // MARK: - Configuration
    
    /// Configure with FirestoreManager to load organizations
    /// Call this once in your app initialization
    func configure(firestoreManager: FirestoreManager) {
        self.firestoreManager = firestoreManager
        isConfigured = true
        print("TypesenseManager: Configured for local search")
    }
    
    /// Legacy configure method for compatibility (does nothing in local mode)
    func configure(apiKey: String, host: String, port: String = "443", protocol: String = "https") {
        isConfigured = true
        print("TypesenseManager: Running in local mode (Typesense Cloud not needed)")
    }
    
    // MARK: - Load Data
    
    /// Load all organizations from Firestore into local array
    func loadOrganizations() async throws {
        guard let firestoreManager = firestoreManager else {
            print("TypesenseManager: FirestoreManager not set, using empty array")
            return
        }
        
        let profiles = try await firestoreManager.getAllOrganizations()
        
        organizations = profiles.map { profile in
            // Use switch statement to determine organization name based on type
            let name: String
            switch profile.userType {
            case "Restaurant":
                if let restaurantName = profile.restaurantName, !restaurantName.isEmpty {
                    name = restaurantName
                } else {
                    name = "Unknown Restaurant"
                    print("⚠️ TypesenseManager: Restaurant with ID \(profile.userID) has no restaurantName set!")
                }
            case "Farm":
                if let farmName = profile.farmName, !farmName.isEmpty {
                    name = farmName
                } else {
                    name = "Unknown Farm"
                    print("⚠️ TypesenseManager: Farm with ID \(profile.userID) has no farmName set!")
                }
            case "Composting Facility":
                if let facilityName = profile.facilityName, !facilityName.isEmpty {
                    name = facilityName
                } else {
                    name = "Unknown Facility"
                    print("⚠️ TypesenseManager: Composting Facility with ID \(profile.userID) has no facilityName set!")
                }
            default:
                name = "Unknown Organization"
                print("⚠️ TypesenseManager: Organization with ID \(profile.userID) has unknown userType: \(profile.userType)")
            }
            
            return OrganizationDocument(
                id: profile.userID,
                name: name,
                type: profile.userType,
                address: profile.address ?? "",
                latitude: profile.latitude,
                longitude: profile.longitude
            )
        }
        
        print("TypesenseManager: Loaded \(organizations.count) organizations from Firestore")
    }
    
    // MARK: - Search
    
    /// Search for organizations by name (local search)
    /// - Parameters:
    ///   - query: Search query string
    ///   - userLocation: User's current location for distance calculation
    /// - Returns: Array of SearchResult objects
    func searchOrganizations(query: String, userLocation: CLLocationCoordinate2D? = nil) async throws -> [SearchResult] {
        // Load data if not already loaded
        if organizations.isEmpty {
            try await loadOrganizations()
        }
        
        let searchQuery = query.lowercased().trimmingCharacters(in: .whitespaces)
        
        // Filter organizations by search query
        let filtered: [OrganizationDocument]
        if searchQuery.isEmpty {
            filtered = organizations
        } else {
            filtered = organizations.filter { org in
                org.name.lowercased().contains(searchQuery) ||
                org.type.lowercased().contains(searchQuery) ||
                org.address.lowercased().contains(searchQuery)
            }
        }
        
        // Convert to SearchResult objects with distance calculation
        let results = filtered.map { doc in
            var distance: Double? = nil
            if let userLoc = userLocation,
               let orgLat = doc.latitude,
               let orgLon = doc.longitude {
                distance = calculateDistance(
                    from: userLoc,
                    to: CLLocationCoordinate2D(latitude: orgLat, longitude: orgLon)
                )
            }
            
            // Debug logging for each result
            print("✓ Result: \(doc.name) (\(doc.type)) - \(doc.address)")
            
            return SearchResult(
                id: doc.id,
                name: doc.name,
                type: doc.type,
                address: doc.address,
                latitude: doc.latitude,
                longitude: doc.longitude,
                distance: distance
            )
        }
        
        print("TypesenseManager: Local search for '\(query)' returned \(results.count) results")
        return results
    }
    
    /// Index an organization (local version - just reloads data)
    /// Call this when a new organization is created or updated
    func indexOrganization(
        id: String,
        name: String,
        type: String,
        address: String,
        latitude: Double?,
        longitude: Double?
    ) async throws {
        // In local mode, just reload all organizations
        try await loadOrganizations()
        print("TypesenseManager: Reloaded organizations after update")
    }
    
    /// Remove an organization (local version - just reloads data)
    func removeOrganization(id: String) async throws {
        // In local mode, just reload all organizations
        try await loadOrganizations()
        print("TypesenseManager: Reloaded organizations after delete")
    }
    
    // MARK: - Collection Management
    
    /// Create the organizations collection schema (no-op in local mode)
    /// Kept for compatibility
    func createCollectionSchema() async throws {
        print("TypesenseManager: Schema creation not needed in local mode")
    }
    
    // MARK: - Distance Calculation
    
    private func calculateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
        let distanceInMeters = fromLocation.distance(from: toLocation)
        // Convert to miles
        return distanceInMeters / 1609.34
    }
}

// MARK: - Models

/// Document structure for Typesense
struct OrganizationDocument: Codable {
    let id: String
    let name: String
    let type: String
    let address: String
    let latitude: Double?
    let longitude: Double?
}

/// Search result with calculated distance
struct SearchResult: Identifiable, Hashable {
    let id: String
    let name: String
    let type: String
    let address: String
    let latitude: Double?
    let longitude: Double?
    let distance: Double? // in miles
    
    var formattedDistance: String {
        guard let distance = distance else { return "Unknown distance" }
        return String(format: "%.1f mi", distance)
    }
}

// MARK: - Errors

enum TypesenseError: LocalizedError {
    case notConfigured
    
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Typesense client is not configured. Call configure() first."
        }
    }
}
