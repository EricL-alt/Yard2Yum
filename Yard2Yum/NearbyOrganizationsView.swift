// NearbyOrganizationsView.swift
// Yard2Yum — Enhanced map view with Typesense search

import SwiftUI
import MapKit
import CoreLocation

struct NearbyOrganizationsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var firestoreManager: FirestoreManager
    @StateObject private var typesenseManager = TypesenseManager()
    @Environment(\.dismiss) var dismiss
    
    // State
    @State private var searchText = ""
    @State private var searchResults: [SearchResult] = []
    @State private var isSearching = false
    @State private var selectedResult: SearchResult? = nil
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var showError = false
    @State private var errorMessage = ""
    
    // Layout
    @State private var isMapExpanded = true
    
    private var userLocation: CLLocationCoordinate2D? {
        guard appState.latitude != 0 || appState.longitude != 0 else { return nil }
        return CLLocationCoordinate2D(latitude: appState.latitude, longitude: appState.longitude)
    }
    
    var body: some View {
        ZStack {
            Color.y2yBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Search Bar
                searchBarView
                
                if isMapExpanded {
                    // Map View
                    mapView
                        .frame(height: 300)
                } else {
                    // Collapsed map indicator
                    collapsedMapButton
                }
                
                // Search Results List
                searchResultsList
            }
        }
        .navigationBarHidden(true)
        .task {
            await setupTypesense()
            await performSearch()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Back")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                }
                .foregroundColor(Color.y2yAccent)
            }
            
            Spacer()
            
            VStack(spacing: 2) {
                Text("Find Organizations")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(Color.y2yTan)
                if !searchResults.isEmpty {
                    Text("\(searchResults.count) found")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(Color.y2ySubtext)
                }
            }
            
            Spacer()
            
            // Filter button placeholder
            Button {
                // Toggle map expansion
                withAnimation(.spring(response: 0.3)) {
                    isMapExpanded.toggle()
                }
            } label: {
                Image(systemName: isMapExpanded ? "map.fill" : "map")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.y2yAccent)
                    .frame(width: 60, height: 36)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.y2yCard)
    }
    
    // MARK: - Search Bar
    
    private var searchBarView: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Color.y2ySubtext)
                    .font(.system(size: 16))
                
                TextField("Search organizations...", text: $searchText)
                    .font(.system(size: 15, design: .rounded))
                    .foregroundColor(Color.y2yTan)
                    .autocorrectionDisabled()
                    .onChange(of: searchText) { _, _ in
                        Task {
                            await performSearch()
                        }
                    }
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color.y2ySubtext)
                            .font(.system(size: 16))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.y2yCard)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.y2yAccent.opacity(0.3), lineWidth: 1)
            )
            
            if isSearching {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color.y2yAccent))
                    .scaleEffect(0.8)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.y2yBackground)
    }
    
    // MARK: - Map
    
    private var mapView: some View {
        Map(position: $cameraPosition, selection: $selectedResult) {
            // User's location
            if let userLoc = userLocation {
                Annotation("You", coordinate: userLoc) {
                    ZStack {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 20, height: 20)
                        Circle()
                            .stroke(Color.white, lineWidth: 3)
                            .frame(width: 20, height: 20)
                    }
                }
            }
            
            // Search results
            ForEach(searchResults) { result in
                if let lat = result.latitude, let lon = result.longitude {
                    Marker(result.name, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon))
                        .tint(colorForType(result.type))
                        .tag(result)
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .mapControls {
            MapUserLocationButton()
            MapCompass()
        }
        .onChange(of: selectedResult) { _, newValue in
            if let result = newValue,
               let lat = result.latitude,
               let lon = result.longitude {
                withAnimation {
                    cameraPosition = .region(MKCoordinateRegion(
                        center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    ))
                }
            }
        }
    }
    
    private var collapsedMapButton: some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                isMapExpanded = true
            }
        } label: {
            HStack {
                Image(systemName: "map.fill")
                    .font(.system(size: 14))
                Text("Show Map")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 12))
            }
            .foregroundColor(Color.y2yAccent)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.y2yCard)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }
    
    // MARK: - Search Results List
    
    private var searchResultsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if searchResults.isEmpty && !isSearching {
                    emptyStateView
                } else {
                    ForEach(searchResults) { result in
                        SearchResultCard(
                            result: result,
                            isSelected: selectedResult?.id == result.id,
                            onTap: {
                                selectedResult = result
                                if !isMapExpanded {
                                    withAnimation(.spring(response: 0.3)) {
                                        isMapExpanded = true
                                    }
                                }
                            },
                            onNavigate: {
                                openInMaps(result: result)
                            }
                        )
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(Color.y2yBackground)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(Color.y2ySubtext.opacity(0.5))
            
            Text(searchText.isEmpty ? "Search for nearby organizations" : "No organizations found")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(Color.y2ySubtext)
            
            if !searchText.isEmpty {
                Text("Try a different search term")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundColor(Color.y2ySubtext.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    // MARK: - Typesense Integration
    
    private func setupTypesense() async {
        // Configure with FirestoreManager for local search
        typesenseManager.configure(firestoreManager: firestoreManager)
        
        // Load organizations from Firestore
        do {
            try await typesenseManager.loadOrganizations()
        } catch {
            await MainActor.run {
                errorMessage = "Failed to load organizations: \(error.localizedDescription)"
                showError = true
            }
        }
    }
    
    private func performSearch() async {
        guard typesenseManager.isConfigured else { return }
        
        await MainActor.run {
            isSearching = true
        }
        
        do {
            let results = try await typesenseManager.searchOrganizations(
                query: searchText,
                userLocation: userLocation
            )
            
            // Sort by distance if available
            let sortedResults = results.sorted { a, b in
                guard let distA = a.distance, let distB = b.distance else {
                    return a.distance != nil
                }
                return distA < distB
            }
            
            await MainActor.run {
                searchResults = sortedResults
                isSearching = false
                
                // Update camera position to show results
                if let userLoc = userLocation, !sortedResults.isEmpty {
                    cameraPosition = .region(MKCoordinateRegion(
                        center: userLoc,
                        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
                    ))
                }
            }
        } catch {
            await MainActor.run {
                isSearching = false
                errorMessage = "Search failed: \(error.localizedDescription)"
                showError = true
            }
        }
    }
    
    // MARK: - Helpers
    
    private func colorForType(_ type: String) -> Color {
        switch type.lowercased() {
        case "restaurant":
            return Color(red: 0.95, green: 0.58, blue: 0.35)
        case "farm":
            return Color.y2yAccent
        case "composting facility":
            return Color(red: 0.78, green: 0.65, blue: 0.38)
        default:
            return Color.gray
        }
    }
    
    private func openInMaps(result: SearchResult) {
        guard let lat = result.latitude, let lon = result.longitude else { return }
        
        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        mapItem.name = result.name
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }
}

// MARK: - Search Result Card

struct SearchResultCard: View {
    let result: SearchResult
    let isSelected: Bool
    let onTap: () -> Void
    let onNavigate: () -> Void
    
    private var organizationType: UserType? {
        switch result.type.lowercased() {
        case "restaurant":
            return .restaurant
        case "farm":
            return .farm
        case "composting facility":
            return .compostingFacility
        default:
            return nil
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 14) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(organizationType?.accentColor.opacity(0.18) ?? Color.gray.opacity(0.18))
                            .frame(width: 54, height: 54)
                        Image(systemName: organizationType?.icon ?? "building.2")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(organizationType?.accentColor ?? Color.gray)
                    }
                    
                    // Info
                    VStack(alignment: .leading, spacing: 6) {
                        Text(result.name)
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(Color.y2yTan)
                            .lineLimit(1)
                        
                        Text(result.type)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(organizationType?.accentColor ?? Color.y2ySubtext)
                        
                        if let distance = result.distance {
                            HStack(spacing: 4) {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 11))
                                Text(result.formattedDistance)
                                    .font(.system(size: 12, design: .rounded))
                            }
                            .foregroundColor(Color.y2ySubtext.opacity(0.8))
                        }
                    }
                    
                    Spacer()
                    
                    // Selected indicator
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(organizationType?.accentColor ?? Color.y2yAccent)
                    }
                }
                .padding(16)
                
                // Address
                if !result.address.isEmpty {
                    Divider()
                        .background(Color.y2ySubtext.opacity(0.2))
                    
                    HStack(spacing: 8) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 13))
                            .foregroundColor(Color.y2ySubtext)
                        
                        Text(result.address)
                            .font(.system(size: 13, design: .rounded))
                            .foregroundColor(Color.y2ySubtext)
                            .lineLimit(2)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                
                // Navigate button
                Divider()
                    .background(Color.y2ySubtext.opacity(0.2))
                
                Button(action: onNavigate) {
                    HStack {
                        Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                            .font(.system(size: 15))
                        Text("Get Directions")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(organizationType?.accentColor ?? Color.y2yAccent)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .background(Color.y2yCard)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? (organizationType?.accentColor ?? Color.y2yAccent) : Color.clear, lineWidth: 2)
            )
            .shadow(color: Color.black.opacity(isSelected ? 0.25 : 0.15), radius: isSelected ? 12 : 6, x: 0, y: isSelected ? 4 : 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

#Preview {
    NearbyOrganizationsView()
        .environmentObject(AppState())
        .environmentObject(FirestoreManager())
}
