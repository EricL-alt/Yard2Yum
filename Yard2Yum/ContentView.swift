// ContentView.swift
// Yard2Yum Hackathon
import SwiftUI
import PhotosUI
import Combine
import FirebaseAuth
import UIKit
import MapKit
import CoreLocation

extension Color {
    static let y2yBackground = Color(red: 0/255,  green: 77/255, blue: 61/255)
    static let y2yCard       = Color(red: 4/255,  green: 46/255, blue: 37/255)
    static let y2yAccent     = Color(red: 0.48,   green: 0.88,   blue: 0.62)
    static let y2yTan        = Color(red: 0.97,   green: 0.95,   blue: 0.90)
    static let y2ySubtext    = Color(red: 0.72,   green: 0.88,   blue: 0.80)
}
enum UserType: String, CaseIterable {
    case restaurant        = "Restaurant"
    case farm              = "Farm"
    case compostingFacility = "Composting Facility"
    var icon: String {
        switch self {
        case .restaurant:         return "fork.knife"
        case .farm:               return "leaf.fill"
        case .compostingFacility: return "arrow.3.trianglepath"
        }
    }
    var accentColor: Color {
        switch self {
        case .restaurant:         return Color(red: 0.95, green: 0.58, blue: 0.35)
        case .farm:               return Color.y2yAccent
        case .compostingFacility: return Color(red: 0.78, green: 0.65, blue: 0.38)
        }
    }
}
struct PickupRequest: Identifiable {
    let id = UUID()
    var restaurantName: String
    var date: Date
    var pounds: Double
    var location: String
}
struct CompostListing: Identifiable {
    let id = UUID()
    var facilityName: String
    var pricePerPound: Double
    var availablePounds: Double
}
// MARK: - New: Farm Produce Listing
struct ProduceListing: Identifiable {
    let id = UUID()
    var farmName: String
    var produceName: String
    var pricePerUnit: Double
    var availableUnits: Double
    var unit: String        // e.g. "lb", "bunch", "each"
    var produceEmoji: String
    var produceImage: UIImage? = nil
    var freshScore: Double? = nil   // Fresh Confidence Score from the on-device classifier
}
// MARK: - New: Produce Order (restaurant buys produce)
struct ProduceOrder: Identifiable {
    let id = UUID()
    var restaurantName: String
    var farmName: String
    var produceName: String
    var quantity: Double
    var unit: String
    var totalPrice: Double
    var date: Date
}
// MARK: - Restaurant Points / Badge System
struct RestaurantBadge: Identifiable {
    let id = UUID()
    var name: String
    var icon: String
    var description: String
    var requiredLbs: Double
    var color: Color
}
let allBadges: [RestaurantBadge] = [
    RestaurantBadge(name: "Sprout",       icon: "🌱", description: "First donation!",          requiredLbs: 1,    color: Color(red: 0.48, green: 0.88, blue: 0.62)),
    RestaurantBadge(name: "Seedling",     icon: "🪴", description: "Donated 50 lbs",           requiredLbs: 50,   color: Color(red: 0.55, green: 0.80, blue: 0.45)),
    RestaurantBadge(name: "Composter",    icon: "♻️", description: "Donated 150 lbs",          requiredLbs: 150,  color: Color(red: 0.78, green: 0.65, blue: 0.38)),
    RestaurantBadge(name: "Earth Hero",   icon: "🌍", description: "Donated 300 lbs",          requiredLbs: 300,  color: Color(red: 0.48, green: 0.72, blue: 0.95)),
    RestaurantBadge(name: "Green Legend", icon: "🏆", description: "Donated 500 lbs",          requiredLbs: 500,  color: Color(red: 0.95, green: 0.78, blue: 0.30)),
]
func pointsForLbs(_ lbs: Double) -> Int {
    return Int(lbs * 2)
}
func levelForPoints(_ points: Int) -> (level: Int, title: String) {
    switch points {
    case 0..<100:   return (1, "Seedling")
    case 100..<300: return (2, "Grower")
    case 300..<600: return (3, "Cultivator")
    case 600..<1000:return (4, "Harvester")
    default:        return (5, "Earth Guardian")
}
}
@MainActor
class AppState: ObservableObject {
    @Published var isLoggedIn      = false
    @Published var showOnboarding  = false
    @Published var username        = ""
    @Published var email           = ""
    @Published var userID          = ""
    @Published var selectedUserType: UserType? = nil
    @Published var address         = ""
    @Published var latitude: Double = 0
    @Published var longitude: Double = 0
    @Published var restaurantName  = ""
    @Published var restaurantType  = ""
    @Published var restaurantImage: UIImage? = nil
    @Published var pickupDate      = Date()
    @Published var pickupPounds: Double = 0
    // MARK: - Restaurant Points System
    @Published var totalDonatedLbs: Double = 0
    @Published var totalPoints: Int = 0
    @Published var farmName        = ""
    @Published var farmLocation    = ""
    @Published var farmImage: UIImage? = nil
    @Published var facilityName    = ""
    @Published var marketplaceListings: [CompostListing] = [
        CompostListing(facilityName: "Green Earth Compost", pricePerPound: 0.45, availablePounds: 500),
        CompostListing(facilityName: "Urban Cycle",         pricePerPound: 0.38, availablePounds: 300)
    ]
    @Published var pickupRequests: [PickupRequest] = [
        PickupRequest(restaurantName: "The Green Table",  date: Date(),                           pounds: 50, location: "123 Main St"),
        PickupRequest(restaurantName: "Harvest Kitchen",  date: Date().addingTimeInterval(86400), pounds: 75, location: "456 Oak Ave")
    ]
    // MARK: - Farm Produce Marketplace (shared, all users can see)
    @Published var produceListings: [ProduceListing] = [
        ProduceListing(farmName: "Sunflower Acres", produceName: "Heirloom Tomatoes", pricePerUnit: 3.50, availableUnits: 200, unit: "lb",    produceEmoji: "🍅"),
        ProduceListing(farmName: "Sunflower Acres", produceName: "Sweet Corn",        pricePerUnit: 0.75, availableUnits: 500, unit: "each",  produceEmoji: "🌽"),
        ProduceListing(farmName: "River Bend Farm", produceName: "Mixed Greens",      pricePerUnit: 4.00, availableUnits: 80,  unit: "bunch", produceEmoji: "🥬"),
    ]
    // MARK: - Produce Orders (restaurants buying from farms)
    @Published var produceOrders: [ProduceOrder] = []
    // Earned badges computed from totalDonatedLbs
    var earnedBadges: [RestaurantBadge] {
        allBadges.filter { totalDonatedLbs >= $0.requiredLbs }
    }
    
    // MARK: - Firebase Auth Integration
    func resetForLogout() {
        isLoggedIn = false
        showOnboarding = false
        username = ""
        email = ""
        userID = ""
        selectedUserType = nil
        address = ""
        latitude = 0
        longitude = 0
        restaurantName = ""
        restaurantType = ""
        restaurantImage = nil
        totalDonatedLbs = 0
        totalPoints = 0
        farmName = ""
        farmLocation = ""
        farmImage = nil
        facilityName = ""
    }
}
struct ContentView: View {
    @StateObject private var appState = AppState()
    @StateObject private var authManager = AuthenticationManager()
    @StateObject private var firestoreManager = FirestoreManager()
    
    var body: some View {
        ZStack {
            if authManager.isAuthenticated && appState.isLoggedIn {
                if appState.showOnboarding {
                    OnboardingView { withAnimation(.easeInOut(duration: 0.4)) { appState.showOnboarding = false } }
                        .transition(.opacity)
                } else {
                    mainFlow.transition(.opacity)
                }
            } else {
                AuthenticationView()
                    .environmentObject(appState)
                    .environmentObject(authManager)
                    .environmentObject(firestoreManager)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: authManager.isAuthenticated)
        .animation(.easeInOut(duration: 0.4), value: appState.isLoggedIn)
        .animation(.easeInOut(duration: 0.4), value: appState.showOnboarding)
        .onChange(of: authManager.isAuthenticated) { isAuth in
            if !isAuth {
                appState.resetForLogout()
            }
        }
    }
    
    @ViewBuilder var mainFlow: some View {
        switch appState.selectedUserType {
        case .restaurant:         RestaurantFlowView().environmentObject(appState).environmentObject(authManager).environmentObject(firestoreManager)
        case .farm:               FarmFlowView().environmentObject(appState).environmentObject(authManager).environmentObject(firestoreManager)
        case .compostingFacility: CompostFacilityFlowView().environmentObject(appState).environmentObject(authManager).environmentObject(firestoreManager)
        case .none:               AuthenticationView().environmentObject(appState).environmentObject(authManager).environmentObject(firestoreManager)
        }
    }
}
struct OnboardingSlide {
    let icon: String
    let title: String
    let caption: String
}
private let slides: [OnboardingSlide] = [
    OnboardingSlide(
        icon: "leaf",
        title: "Welcome to Yard2Yum",
        caption: "Your sustainability journey starts here.\nLet's turn food waste into something truly beautiful."
    ),
    OnboardingSlide(
        icon: "arrow.3.trianglepath",
        title: "How It Works",
        caption: "Restaurants send food waste to composting facilities.\nFacilities process it and sell rich compost to farms — at a fraction of retail cost."
    ),
    OnboardingSlide(
        icon: "star",
        title: "Everyone Wins",
        caption: "A Win-Win-Win for all.\nRestaurants reduce waste. Facilities earn revenue.\nFarms grow more with less."
    )
]
struct OnboardingView: View {
    let onFinish: () -> Void
    @State private var currentSlide = 0
    var body: some View {
        ZStack {
            Color.y2yBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                Yard2YumHeader()
                    .padding(.top, 26)
                    .padding(.bottom, 14)
                TabView(selection: $currentSlide) {
                    ForEach(Array(slides.enumerated()), id: \.offset) { idx, slide in
                        OnboardingSlideView(slide: slide).tag(idx)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(maxHeight: .infinity)
                // Dot indicators
                HStack(spacing: 10) {
                    ForEach(0..<slides.count, id: \.self) { i in
                        Capsule()
                            .fill(i == currentSlide ? Color.y2yAccent : Color.y2ySubtext.opacity(0.35))
                            .frame(width: i == currentSlide ? 26 : 8, height: 8)
                            .animation(.spring(response: 0.4), value: currentSlide)
                    }
                }
                .padding(.bottom, 30)
                Button {
                    if currentSlide < slides.count - 1 {
                        withAnimation(.spring(response: 0.45)) { currentSlide += 1 }
                    } else {
                        onFinish()
                    }
                } label: {
                    Text(currentSlide < slides.count - 1 ? "Next" : "Get Started →")
                        .font(Font.custom("Georgia-Bold", size: 18))
                        .foregroundColor(Color.y2yCard)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color.y2yAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 26))
                        .shadow(color: Color.y2yAccent.opacity(0.35), radius: 14, x: 0, y: 6)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 52)
            }
        }
    }
}
struct OnboardingSlideView: View {
    let slide: OnboardingSlide
    var body: some View {
        VStack(spacing: 38) {
            ZStack {
                Circle()
                    .fill(Color.y2yCard)
                    .frame(width: 148, height: 148)
                    .shadow(color: Color.black.opacity(0.28), radius: 24, x: 0, y: 10)
                Image(systemName: slide.icon)
                    .font(.system(size: 60, weight: .thin))
                    .foregroundColor(.white)
            }
            VStack(spacing: 16) {
                Text(slide.title)
                    .font(Font.custom("Georgia-Bold", size: 26))
                    .foregroundColor(Color.y2yTan)
                    .multilineTextAlignment(.center)
                Text(slide.caption)
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundColor(Color.y2ySubtext)
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .padding(.horizontal, 28)
            }
        }
        .padding(.horizontal, 24)
    }
}
// MARK: - Authentication View
struct AuthenticationView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var firestoreManager: FirestoreManager
    @State private var isSignUp = true
    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var selectedType: UserType? = nil
    @State private var errorMessage: String? = nil
    @State private var isLoading = false
    @State private var showForgotPassword = false
    @State private var resetEmail = ""
    @State private var showResetSuccess = false
    @State private var needsProfileRecovery = false
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        let predicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return predicate.evaluate(with: email)
    }
    
    private func validateFields() -> Bool {
        if email.isEmpty || password.isEmpty {
            errorMessage = "Please fill in all fields."
            return false
        }
        
        if !isValidEmail(email) {
            errorMessage = "Please enter a valid email address."
            return false
        }
        
        if isSignUp {
            if username.isEmpty {
                errorMessage = "Please enter a username."
                return false
            }
            
            if selectedType == nil {
                errorMessage = "Please select a user type."
                return false
            }
            
            if password.count < 6 {
                errorMessage = "Password must be at least 6 characters."
                return false
            }
            
            if password != confirmPassword {
                errorMessage = "Passwords do not match."
                return false
            }
        }
        
        return true
    }
    
    private func handleAuthentication() {
        guard validateFields() else { return }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                if isSignUp {
                    // Sign up new user
                    try await authManager.signUp(email: email, password: password, username: username)
                    
                    guard let userID = authManager.user?.uid else {
                        throw NSError(domain: "AuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get user ID"])
                    }
                    
                    // Create user profile in Firestore
                    var profile = UserProfile(
                        userID: userID,
                        username: username,
                        email: email,
                        userType: selectedType?.rawValue ?? ""
                    )
                    
                    try await firestoreManager.createUserProfile(profile)
                    
                    // Set up local app state
                    await MainActor.run {
                        appState.username = username
                        appState.email = email
                        appState.userID = userID
                        appState.selectedUserType = selectedType
                        appState.showOnboarding = true
                        appState.isLoggedIn = true
                        isLoading = false
                    }
                } else {
                    // Sign in existing user
                    try await authManager.signIn(email: email, password: password)
                    
                    guard let userID = authManager.user?.uid else {
                        throw NSError(domain: "AuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get user ID"])
                    }
                    
                    // Load user profile from Firestore
                    if let profile = try await firestoreManager.getUserProfile(userID: userID) {
                        await MainActor.run {
                            appState.username = profile.username
                            appState.email = profile.email
                            appState.userID = profile.userID
                            appState.address = profile.address ?? ""
                            appState.latitude = profile.latitude ?? 0
                            appState.longitude = profile.longitude ?? 0
                            
                            // Set user type
                            if let userType = UserType.allCases.first(where: { $0.rawValue == profile.userType }) {
                                appState.selectedUserType = userType
                            }
                            
                            // Check if user has completed profile setup
                            var hasCompletedSetup = false
                            
                            // Load type-specific data
                            if let restaurantName = profile.restaurantName, !restaurantName.isEmpty {
                                appState.restaurantName = restaurantName
                                appState.restaurantType = profile.restaurantType ?? ""
                                hasCompletedSetup = true
                            }
                            if let farmName = profile.farmName, !farmName.isEmpty {
                                appState.farmName = farmName
                                appState.farmLocation = profile.farmLocation ?? ""
                                hasCompletedSetup = true
                            }
                            if let facilityName = profile.facilityName, !facilityName.isEmpty {
                                appState.facilityName = facilityName
                                hasCompletedSetup = true
                            }
                            
                            // Load progress data
                            appState.totalDonatedLbs = profile.totalDonatedLbs ?? 0
                            appState.totalPoints = profile.totalPoints ?? 0
                            
                            appState.isLoggedIn = true
                            // Show onboarding if profile is incomplete (including address)
                            appState.showOnboarding = !hasCompletedSetup || appState.address.isEmpty
                            isLoading = false
                        }
                    } else {
                        // Auth account exists but the Firestore profile doc is missing
                        // (e.g. sign-ups made while the database rules were expired).
                        // Let the user pick their type and rebuild it instead of failing.
                        await MainActor.run {
                            needsProfileRecovery = true
                            errorMessage = nil
                            isLoading = false
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = AuthenticationManager.friendlyMessage(for: error)
                    isLoading = false
                }
            }
        }
    }

    private func handleProfileRecovery() {
        guard let selectedType = selectedType else {
            errorMessage = "Please select a user type."
            return
        }
        guard let user = authManager.user else {
            errorMessage = "Your session ended. Please sign in again."
            needsProfileRecovery = false
            return
        }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                let profile = UserProfile(
                    userID: user.uid,
                    username: user.displayName ?? "",
                    email: user.email ?? email,
                    userType: selectedType.rawValue
                )
                try await firestoreManager.createUserProfile(profile)

                await MainActor.run {
                    appState.username = profile.username
                    appState.email = profile.email
                    appState.userID = profile.userID
                    appState.selectedUserType = selectedType
                    appState.showOnboarding = true
                    appState.isLoggedIn = true
                    needsProfileRecovery = false
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = AuthenticationManager.friendlyMessage(for: error)
                    isLoading = false
                }
            }
        }
    }
    
    private func handlePasswordReset() {
        guard !resetEmail.isEmpty else {
            errorMessage = "Please enter your email address."
            return
        }
        
        guard isValidEmail(resetEmail) else {
            errorMessage = "Please enter a valid email address."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await authManager.resetPassword(email: resetEmail)
                await MainActor.run {
                    showResetSuccess = true
                    isLoading = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        showForgotPassword = false
                        showResetSuccess = false
                        resetEmail = ""
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = AuthenticationManager.friendlyMessage(for: error)
                    isLoading = false
                }
            }
        }
    }

    var body: some View {
        ZStack {
            Color.y2yBackground.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 26) {
                    Yard2YumHeader().padding(.top, 16)
                    
                    ZStack {
                        Circle().fill(Color.y2yCard).frame(width: 90, height: 90)
                            .shadow(color: Color.black.opacity(0.22), radius: 14, x: 0, y: 6)
                        Image(systemName: "leaf.circle.fill")
                            .font(.system(size: 52)).foregroundColor(Color.y2yAccent)
                    }
                    
                    Text("Connecting food, farms & future")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(Color.y2ySubtext)
                    
                    // Toggle between Sign In / Sign Up
                    HStack(spacing: 0) {
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                isSignUp = false
                                errorMessage = nil
                                needsProfileRecovery = false
                            }
                        } label: {
                            Text("Sign In")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundColor(isSignUp ? Color.y2ySubtext : Color.y2yCard)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(isSignUp ? Color.clear : Color.y2yAccent)
                                .clipShape(RoundedRectangle(cornerRadius: 18))
                        }
                        
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                isSignUp = true
                                errorMessage = nil
                                needsProfileRecovery = false
                            }
                        } label: {
                            Text("Sign Up")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundColor(isSignUp ? Color.y2yCard : Color.y2ySubtext)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(isSignUp ? Color.y2yAccent : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 18))
                        }
                    }
                    .padding(4)
                    .background(Color.y2yCard)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal, 24)
                    
                    // Form Fields
                    VStack(spacing: 14) {
                        if isSignUp {
                            Y2YTextField(placeholder: "Username", text: $username, icon: "person.fill")
                        }
                        
                        Y2YTextField(placeholder: "Email", text: $email, icon: "envelope.fill")
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                        
                        SecureY2YTextField(placeholder: "Password", text: $password, icon: "lock.fill")
                        
                        if isSignUp {
                            SecureY2YTextField(placeholder: "Confirm Password", text: $confirmPassword, icon: "lock.fill")
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    // Profile recovery notice (account exists, profile doc missing)
                    if needsProfileRecovery {
                        Text("You're signed in, but your profile setup wasn't finished. Choose your account type below to continue.")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(Color.y2yAccent)
                            .padding(.horizontal, 24)
                            .multilineTextAlignment(.center)
                    }

                    // User Type Selection (Sign Up or profile recovery)
                    if isSignUp || needsProfileRecovery {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("I AM A...")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(Color.y2ySubtext.opacity(0.65))
                                .padding(.horizontal, 24)
                            
                            ForEach(UserType.allCases, id: \.self) { type in
                                UserTypeCard(type: type, isSelected: selectedType == type) {
                                    withAnimation(.spring(response: 0.3)) { selectedType = type }
                                }
                                .padding(.horizontal, 24)
                            }
                        }
                    }
                    
                    // Error Message
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13, design: .rounded))
                            .foregroundColor(Color(red: 1, green: 0.5, blue: 0.45))
                            .padding(.horizontal, 24)
                            .multilineTextAlignment(.center)
                    }
                    
                    // Submit Button
                    Button {
                        if needsProfileRecovery {
                            handleProfileRecovery()
                        } else {
                            handleAuthentication()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: Color.y2yCard))
                            } else {
                                Text(needsProfileRecovery ? "Finish Setup" : (isSignUp ? "Create Account" : "Sign In"))
                                    .font(Font.custom("Georgia-Bold", size: 18))
                            }
                        }
                        .foregroundColor(Color.y2yCard)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color.y2yAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 26))
                        .shadow(color: Color.y2yAccent.opacity(0.3), radius: 12, x: 0, y: 5)
                    }
                    .disabled(isLoading)
                    .padding(.horizontal, 24)
                    
                    // Forgot Password (Sign In Only)
                    if !isSignUp {
                        Button {
                            showForgotPassword = true
                        } label: {
                            Text("Forgot Password?")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(Color.y2yAccent)
                        }
                    }
                }
                .padding(.bottom, 52)
            }
        }
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordSheet(
                email: $resetEmail,
                errorMessage: $errorMessage,
                showSuccess: $showResetSuccess,
                isLoading: $isLoading,
                onReset: handlePasswordReset
            )
        }
    }
}

// MARK: - Secure Text Field
struct SecureY2YTextField: View {
    let placeholder: String
    @Binding var text: String
    var icon: String
    @State private var isSecure = true
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(Color.y2ySubtext.opacity(0.65))
                .frame(width: 20)
            
            if isSecure {
                SecureField("", text: $text, prompt: Text(placeholder).foregroundColor(Color.y2ySubtext.opacity(0.45)))
                    .font(.system(size: 16, design: .rounded))
                    .foregroundColor(Color.y2yTan)
                    .tint(Color.y2yAccent)
            } else {
                TextField("", text: $text, prompt: Text(placeholder).foregroundColor(Color.y2ySubtext.opacity(0.45)))
                    .font(.system(size: 16, design: .rounded))
                    .foregroundColor(Color.y2yTan)
                    .tint(Color.y2yAccent)
            }
            
            Button {
                isSecure.toggle()
            } label: {
                Image(systemName: isSecure ? "eye.slash.fill" : "eye.fill")
                    .foregroundColor(Color.y2ySubtext.opacity(0.5))
                    .font(.system(size: 14))
            }
        }
        .padding(16)
        .background(Color.y2yCard)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.07), lineWidth: 1))
    }
}

// MARK: - Forgot Password Sheet
struct ForgotPasswordSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var email: String
    @Binding var errorMessage: String?
    @Binding var showSuccess: Bool
    @Binding var isLoading: Bool
    let onReset: () -> Void
    
    var body: some View {
        ZStack {
            Color.y2yBackground.ignoresSafeArea()
            
            VStack(spacing: 24) {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color.y2ySubtext)
                            .font(.system(size: 28))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.y2yCard)
                            .frame(width: 80, height: 80)
                        Image(systemName: "lock.rotation")
                            .font(.system(size: 36))
                            .foregroundColor(Color.y2yAccent)
                    }
                    
                    Text("Reset Password")
                        .font(Font.custom("Georgia-Bold", size: 24))
                        .foregroundColor(Color.y2yTan)
                    
                    Text("Enter your email and we'll send you a link to reset your password.")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(Color.y2ySubtext)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                
                VStack(spacing: 16) {
                    Y2YTextField(placeholder: "Email", text: $email, icon: "envelope.fill")
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .padding(.horizontal, 24)
                    
                    if showSuccess {
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(Color.y2yAccent)
                            Text("Reset link sent! Check your email.")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(Color.y2yTan)
                        }
                        .padding(14)
                        .background(Color.y2yCard)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .padding(.horizontal, 24)
                    }
                    
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13, design: .rounded))
                            .foregroundColor(Color(red: 1, green: 0.5, blue: 0.45))
                            .padding(.horizontal, 24)
                            .multilineTextAlignment(.center)
                    }
                    
                    Button {
                        onReset()
                    } label: {
                        HStack(spacing: 8) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: Color.y2yCard))
                            } else {
                                Text("Send Reset Link")
                                    .font(Font.custom("Georgia-Bold", size: 17))
                                Image(systemName: "paperplane.fill")
                                    .font(.system(size: 14, weight: .bold))
                            }
                        }
                        .foregroundColor(Color.y2yCard)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background(Color.y2yAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 26))
                        .shadow(color: Color.y2yAccent.opacity(0.3), radius: 12, x: 0, y: 5)
                    }
                    .disabled(isLoading)
                    .padding(.horizontal, 24)
                }
                
                Spacer()
            }
        }
    }
}
struct UserTypeCard: View {
    let type: UserType
    let isSelected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(isSelected ? type.accentColor : Color.white.opacity(0.07))
                        .frame(width: 46, height: 46)
                    Image(systemName: type.icon)
                        .foregroundColor(isSelected ? Color.y2yCard : Color.y2ySubtext)
                        .font(.system(size: 18, weight: .medium))
                }
                Text(type.rawValue)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.y2yTan)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(type.accentColor).font(.system(size: 22))
                }
            }
            .padding(16)
            .background(Color.y2yCard)
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(isSelected ? type.accentColor : Color.white.opacity(0.06), lineWidth: 1.5))
            .shadow(color: Color.black.opacity(0.18), radius: 8, x: 0, y: 4)
        }
    }
}
struct Y2YTextField: View {
    let placeholder: String
    @Binding var text: String
    var icon: String
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundColor(Color.y2ySubtext.opacity(0.65)).frame(width: 20)
            TextField("", text: $text, prompt: Text(placeholder).foregroundColor(Color.y2ySubtext.opacity(0.45)))
                .font(.system(size: 16, design: .rounded))
                .foregroundColor(Color.y2yTan)
                .tint(Color.y2yAccent)
        }
        .padding(16)
        .background(Color.y2yCard)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.07), lineWidth: 1))
    }
}
// MARK: - Restaurant Flow
struct RestaurantFlowView: View {
    @EnvironmentObject var appState: AppState
    @State private var currentPage = 1
    var body: some View {
        NavigationStack {
            switch currentPage {
            case 1: RestaurantPage1(onNext: { currentPage = 2 }).environmentObject(appState)
            case 2: RestaurantPage2(onBack: { currentPage = 1 }, onNext: { currentPage = 3 }).environmentObject(appState)
            case 3: RestaurantProduceMarketplacePage(onBack: { currentPage = 2 }, onDispatch: { currentPage = 4 }).environmentObject(appState)
            case 4: CompostDispatchView(initialRole: .restaurant, onBack: { currentPage = 3 }).environmentObject(appState)
            default: RestaurantPage1(onNext: { currentPage = 2 }).environmentObject(appState)
            }
        }
    }
}
// MARK: - Y2Y Organizations Map View
struct OrganizationAnnotation: Identifiable {
    let id = UUID()
    let profile: UserProfile
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: profile.latitude ?? 0, longitude: profile.longitude ?? 0)
    }
    var name: String {
        profile.restaurantName ?? profile.farmName ?? profile.facilityName ?? "Unknown"
    }
    var userType: UserType? {
        UserType.allCases.first { $0.rawValue == profile.userType }
    }
}

struct Y2YMapView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var firestoreManager: FirestoreManager
    @Environment(\.dismiss) var dismiss
    @State private var organizations: [UserProfile] = []
    @State private var isLoading = true
    @State private var selectedOrg: UserProfile? = nil
    @State private var cameraPosition: MapCameraPosition = .automatic
    
    private var mapView: some View {
        Map(position: $cameraPosition) {
            // User's location
            if appState.latitude != 0 || appState.longitude != 0 {
                userLocationAnnotation
            }
            
            // Other organizations
            ForEach(filteredOrganizations) { org in
                organizationAnnotation(for: org)
            }
        }
        .mapStyle(.standard(elevation: .realistic))
    }
    
    private var userLocationAnnotation: some MapContent {
        Annotation("You", coordinate: CLLocationCoordinate2D(latitude: appState.latitude, longitude: appState.longitude)) {
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
    
    private var filteredOrganizations: [UserProfile] {
        organizations.filter { org in
            guard org.userID != appState.userID,
                  let lat = org.latitude,
                  let lon = org.longitude else {
                return false
            }
            return lat != 0 || lon != 0
        }
    }
    
    private func organizationAnnotation(for org: UserProfile) -> some MapContent {
        let coordinate = CLLocationCoordinate2D(
            latitude: org.latitude ?? 0,
            longitude: org.longitude ?? 0
        )
        let name = org.restaurantName ?? org.farmName ?? org.facilityName ?? "Organization"
        
        return Annotation(name, coordinate: coordinate) {
            MapPinView(userType: UserType.allCases.first { $0.rawValue == org.userType })
                .onTapGesture {
                    selectedOrg = org
                }
        }
    }
    
    var body: some View {
        ZStack {
            Color.y2yBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
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
                    Text("Nearby Organizations")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(Color.y2yTan)
                    Spacer()
                    // Placeholder for symmetry
                    Color.clear.frame(width: 60)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color.y2yCard)
                
                // Map
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Color.y2yAccent))
                        Text("Loading organizations...")
                            .font(.system(size: 14, design: .rounded))
                            .foregroundColor(Color.y2ySubtext)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    mapView
                }
                
                // Selected organization detail card
                if let org = selectedOrg {
                    OrganizationDetailCard(profile: org)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(16)
                }
            }
        }
        .navigationBarHidden(true)
        .task {
            await loadOrganizations()
        }
    }
    
    private func loadOrganizations() async {
        do {
            let orgs = try await firestoreManager.getAllOrganizations()
            await MainActor.run {
                organizations = orgs
                isLoading = false
                
                // Set initial camera position to user's location
                if appState.latitude != 0 || appState.longitude != 0 {
                    cameraPosition = .region(MKCoordinateRegion(
                        center: CLLocationCoordinate2D(latitude: appState.latitude, longitude: appState.longitude),
                        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
                    ))
                }
            }
        } catch {
            print("Error loading organizations: \(error.localizedDescription)")
            await MainActor.run {
                isLoading = false
            }
        }
    }
}

struct MapPinView: View {
    let userType: UserType?
    
    var body: some View {
        ZStack {
            Circle()
                .fill(userType?.accentColor ?? Color.gray)
                .frame(width: 36, height: 36)
                .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
            
            Image(systemName: userType?.icon ?? "mappin")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color.white)
        }
    }
}

struct OrganizationDetailCard: View {
    let profile: UserProfile
    
    var userType: UserType? {
        UserType.allCases.first { $0.rawValue == profile.userType }
    }
    
    var name: String {
        profile.restaurantName ?? profile.farmName ?? profile.facilityName ?? "Unknown"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(userType?.accentColor.opacity(0.2) ?? Color.gray.opacity(0.2))
                        .frame(width: 50, height: 50)
                    Image(systemName: userType?.icon ?? "mappin")
                        .font(.system(size: 22))
                        .foregroundColor(userType?.accentColor ?? Color.gray)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(Color.y2yTan)
                    Text(profile.userType)
                        .font(.system(size: 13, design: .rounded))
                        .foregroundColor(userType?.accentColor ?? Color.y2ySubtext)
                }
                
                Spacer()
            }
            
            if let address = profile.address, !address.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(Color.y2ySubtext)
                        .font(.system(size: 14))
                    Text(address)
                        .font(.system(size: 13, design: .rounded))
                        .foregroundColor(Color.y2ySubtext)
                        .lineLimit(2)
                }
            }
            
            // Visit Now button
            if let address = profile.address, !address.isEmpty {
                Button {
                    openInMaps(address: address, name: name)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "map.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Visit Now in Maps")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(Color.y2yCard)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(userType?.accentColor ?? Color.y2yAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
        }
        .padding(16)
        .background(Color.y2yCard)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.black.opacity(0.25), radius: 12, x: 0, y: 4)
    }
    
    private func openInMaps(address: String, name: String) {
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(address) { placemarks, error in
            if let location = placemarks?.first?.location {
                let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: location.coordinate))
                mapItem.name = name
                mapItem.openInMaps(launchOptions: [
                    MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
                ])
            }
        }
    }
}

struct RestaurantPage1: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var firestoreManager: FirestoreManager
    let onNext: () -> Void
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var isSaving = false
    @State private var geocodeError: String? = nil
    let types = ["Fine Dining", "Casual", "Fast Casual", "Café", "Bakery", "Food Truck", "Other"]
    
    private func geocodeAddress() async -> (latitude: Double, longitude: Double)? {
        let geocoder = CLGeocoder()
        do {
            let placemarks = try await geocoder.geocodeAddressString(appState.address)
            if let location = placemarks.first?.location {
                return (location.coordinate.latitude, location.coordinate.longitude)
            }
        } catch {
            await MainActor.run {
                geocodeError = "Unable to find address. Please check and try again."
            }
        }
        return nil
    }
    
    private func saveRestaurantInfo() {
        guard !appState.restaurantName.isEmpty, !appState.address.isEmpty else { return }
        
        isSaving = true
        geocodeError = nil
        
        Task {
            // Geocode address first
            guard let coordinates = await geocodeAddress() else {
                await MainActor.run {
                    isSaving = false
                }
                return
            }
            
            do {
                try await firestoreManager.updateRestaurantInfo(
                    userID: appState.userID,
                    name: appState.restaurantName,
                    type: appState.restaurantType,
                    address: appState.address,
                    latitude: coordinates.latitude,
                    longitude: coordinates.longitude
                )
                await MainActor.run {
                    appState.latitude = coordinates.latitude
                    appState.longitude = coordinates.longitude
                    isSaving = false
                    onNext()
                }
            } catch {
                print("Error saving restaurant info: \(error.localizedDescription)")
                await MainActor.run {
                    isSaving = false
                }
            }
        }
    }
    
    var body: some View {
        Y2YPage(title: "Your Restaurant", subtitle: "Tell us about your establishment") {
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                ZStack {
                    RoundedRectangle(cornerRadius: 24).fill(Color.y2yCard).frame(height: 180)
                    if let img = appState.restaurantImage {
                        Image(uiImage: img).resizable().scaledToFill().frame(height: 180).clipShape(RoundedRectangle(cornerRadius: 24))
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "photo.badge.plus").font(.system(size: 34)).foregroundColor(Color.y2yAccent)
                            Text("Add Restaurant Photo").font(.system(size: 13, weight: .medium, design: .rounded)).foregroundColor(Color.y2ySubtext)
                        }
                    }
                }
            }
            .onChange(of: selectedPhoto) { item in Task { if let d = try? await item?.loadTransferable(type: Data.self), let img = UIImage(data: d) { appState.restaurantImage = img } } }
            Y2YInputField(label: "Restaurant Name", placeholder: "e.g. The Green Table", text: $appState.restaurantName)
            VStack(alignment: .leading, spacing: 8) {
                Text("Type of Restaurant").font(.system(size: 12, weight: .bold, design: .rounded)).foregroundColor(Color.y2ySubtext)
                Menu {
                    ForEach(types, id: \.self) { t in Button(t) { appState.restaurantType = t } }
                } label: {
                    HStack {
                        Text(appState.restaurantType.isEmpty ? "Select type..." : appState.restaurantType)
                            .font(.system(size: 15, design: .rounded))
                            .foregroundColor(appState.restaurantType.isEmpty ? Color.y2ySubtext.opacity(0.45) : Color.y2yTan)
                        Spacer()
                        Image(systemName: "chevron.down").foregroundColor(Color.y2yAccent).font(.system(size: 13))
                    }
                    .padding(16).background(Color.y2yCard).clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.07), lineWidth: 1))
                }
            }
            Y2YInputField(label: "Street Address", placeholder: "e.g. 123 Main St, Springfield, CA 12345", text: $appState.address)
            
            if let error = geocodeError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(Color(red: 1, green: 0.5, blue: 0.45))
                    Text(error)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(Color(red: 1, green: 0.5, blue: 0.45))
                }
                .padding(12)
                .background(Color.y2yCard)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            
            Y2YButton(title: isSaving ? "Saving..." : "Next: Schedule Pickup", icon: "arrow.right", action: saveRestaurantInfo)
                .disabled(appState.restaurantName.isEmpty || appState.address.isEmpty || isSaving).padding(.top, 4)
        }
        .toolbar { LogoutToolbarItem() }
    }
}
struct RestaurantPage2: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var firestoreManager: FirestoreManager
    let onBack: () -> Void
    let onNext: () -> Void
    @State private var submitted = false
    @State private var showBadgeUnlock: RestaurantBadge? = nil
    @State private var animatePoints = false
    @State private var showMap = false
    var levelInfo: (level: Int, title: String) { levelForPoints(appState.totalPoints) }
    var nextLevelPoints: Int {
        switch levelInfo.level {
        case 1: return 100
        case 2: return 300
        case 3: return 600
        case 4: return 1000
        default: return appState.totalPoints
        }
    }
    var progressFraction: Double {
        let current = appState.totalPoints
        let prev: Int
        let next: Int
        switch levelInfo.level {
        case 1: prev = 0;   next = 100
        case 2: prev = 100; next = 300
        case 3: prev = 300; next = 600
        case 4: prev = 600; next = 1000
        default: return 1.0
        }
        guard next > prev else { return 1.0 }
        return min(1.0, Double(current - prev) / Double(next - prev))
    }
    var body: some View {
        Y2YPage(title: "Schedule Pickup", subtitle: "When do you need compost collected?") {
            // MARK: - Points Dashboard Card
            VStack(spacing: 0) {
                // Header row
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text("Level \(levelInfo.level)")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(Color.y2yAccent)
                                .padding(.horizontal, 10).padding(.vertical, 4)
                                .background(Color.y2yAccent.opacity(0.15))
                                .clipShape(Capsule())
                        }
                        Text(levelInfo.title)
                            .font(Font.custom("Georgia-Bold", size: 22))
                            .foregroundColor(Color.y2yTan)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(appState.totalPoints)")
                            .font(Font.custom("Georgia-Bold", size: 32))
                            .foregroundColor(Color.y2yAccent)
                            .scaleEffect(animatePoints ? 1.25 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.5), value: animatePoints)
                        Text("pts")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(Color.y2ySubtext)
                    }
                }
                .padding(.horizontal, 18).padding(.top, 18).padding(.bottom, 12)
                // Progress bar
                VStack(alignment: .leading, spacing: 6) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.white.opacity(0.08))
                                .frame(height: 10)
                            RoundedRectangle(cornerRadius: 6)
                                .fill(
                                    LinearGradient(colors: [Color.y2yAccent, Color(red: 0.30, green: 0.95, blue: 0.60)],
                                                   startPoint: .leading, endPoint: .trailing)
                                )
                                .frame(width: geo.size.width * progressFraction, height: 10)
                                .animation(.spring(response: 0.6), value: progressFraction)
                        }
                    }
                    .frame(height: 10)
                    HStack {
                        Text("\(appState.totalPoints) pts")
                            .font(.system(size: 10, design: .rounded)).foregroundColor(Color.y2ySubtext.opacity(0.6))
                        Spacer()
                        Text("\(nextLevelPoints) pts to next level")
                            .font(.system(size: 10, design: .rounded)).foregroundColor(Color.y2ySubtext.opacity(0.6))
                    }
                }
                .padding(.horizontal, 18).padding(.bottom, 14)
                Divider().background(Color.white.opacity(0.07)).padding(.horizontal, 18)
                // Stats row
                HStack {
                    StatMiniCell(label: "Total Donated", value: "\(Int(appState.totalDonatedLbs)) lbs", icon: "leaf.fill",     color: Color.y2yAccent)
                    Divider().frame(height: 36).background(Color.white.opacity(0.08))
                    StatMiniCell(label: "Badges Earned", value: "\(appState.earnedBadges.count)/\(allBadges.count)",  icon: "star.fill",    color: Color(red: 0.95, green: 0.78, blue: 0.30))
                    Divider().frame(height: 36).background(Color.white.opacity(0.08))
                    StatMiniCell(label: "Pickups Made",  value: "\(appState.pickupRequests.filter { $0.restaurantName == appState.restaurantName }.count)",    icon: "arrow.3.trianglepath", color: Color(red: 0.78, green: 0.65, blue: 0.38))
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
            }
            .background(Color.y2yCard)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.y2yAccent.opacity(0.18), lineWidth: 1.5))
            .shadow(color: Color.black.opacity(0.22), radius: 14, x: 0, y: 6)
            // MARK: - Badges Section
            VStack(alignment: .leading, spacing: 10) {
                Text("BADGES")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(Color.y2ySubtext.opacity(0.65))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(allBadges) { badge in
                            let earned = appState.earnedBadges.contains(where: { $0.id == badge.id })
                            BadgeChip(badge: badge, earned: earned)
                        }
                    }
                    .padding(.horizontal, 2).padding(.vertical, 4)
                }
            }
            // MARK: - Badge Unlock Toast
            if let unlocked = showBadgeUnlock {
                HStack(spacing: 12) {
                    Text(unlocked.icon).font(.system(size: 28))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Badge Unlocked!").font(.system(size: 12, weight: .bold, design: .rounded)).foregroundColor(Color.y2yAccent)
                        Text(unlocked.name).font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundColor(Color.y2yTan)
                        Text(unlocked.description).font(.system(size: 11, design: .rounded)).foregroundColor(Color.y2ySubtext)
                    }
                    Spacer()
                }
                .padding(16)
                .background(LinearGradient(colors: [Color.y2yCard, unlocked.color.opacity(0.15)], startPoint: .leading, endPoint: .trailing))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(unlocked.color.opacity(0.4), lineWidth: 1.5))
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            // MARK: - Pickup Form
            VStack(alignment: .leading, spacing: 8) {
                Text("Pickup Date & Time").font(.system(size: 12, weight: .bold, design: .rounded)).foregroundColor(Color.y2ySubtext)
                DatePicker("", selection: $appState.pickupDate, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.graphical).tint(Color.y2yAccent).colorScheme(.dark)
                    .padding(12).background(Color.y2yCard).clipShape(RoundedRectangle(cornerRadius: 22))
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Amount (lbs)").font(.system(size: 12, weight: .bold, design: .rounded)).foregroundColor(Color.y2ySubtext)
                HStack {
                    Slider(value: $appState.pickupPounds, in: 0...500, step: 5).tint(Color.y2yAccent)
                    Text("\(Int(appState.pickupPounds)) lbs")
                        .font(.system(size: 15, weight: .bold, design: .rounded)).foregroundColor(Color.y2yAccent).frame(width: 74, alignment: .trailing)
                }
                .padding(16).background(Color.y2yCard).clipShape(RoundedRectangle(cornerRadius: 20))
            }
            if submitted {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill").foregroundColor(Color.y2yAccent)
                    Text("Pickup request submitted!").font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundColor(Color.y2yTan)
                }
                .padding(14).background(Color.y2yCard).clipShape(RoundedRectangle(cornerRadius: 18))
            }
            Y2YButton(title: "Submit Pickup Request", icon: "paperplane.fill") {
                withAnimation(.spring(response: 0.45)) {
                    let lbs = appState.pickupPounds
                    let earnedBefore = appState.earnedBadges.map { $0.id }
                    let newRequest = PickupRequest(
                        restaurantName: appState.restaurantName,
                        date: appState.pickupDate,
                        pounds: lbs,
                        location: appState.restaurantName
                    )
                    appState.pickupRequests.append(newRequest)
                    appState.totalDonatedLbs += lbs
                    let gained = pointsForLbs(lbs)
                    appState.totalPoints += gained
                    
                    // Save progress to Firestore
                    Task {
                        do {
                            try await firestoreManager.updateProgress(
                                userID: appState.userID,
                                totalDonatedLbs: appState.totalDonatedLbs,
                                totalPoints: appState.totalPoints
                            )
                        } catch {
                            print("Error saving progress: \(error.localizedDescription)")
                        }
                    }
                    
                    submitted = true
                    animatePoints = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { animatePoints = false }
                    // Check new badge unlocks
                    let newBadges = appState.earnedBadges.filter { !earnedBefore.contains($0.id) }
                    if let newest = newBadges.last {
                        withAnimation(.spring(response: 0.5)) { showBadgeUnlock = newest }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                            withAnimation { showBadgeUnlock = nil }
                        }
                    }
                    appState.pickupPounds = 0
                }
            }
            .disabled(appState.pickupPounds == 0)
            // MARK: - Buy Produce CTA
            Button(action: onNext) {
                HStack(spacing: 8) {
                    Text("🛒  Browse Local Farm Produce")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(Color.y2yTan)
                    Spacer()
                    Image(systemName: "chevron.right").foregroundColor(Color.y2yAccent)
                }
                .padding(16).background(Color.y2yCard).clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.y2yAccent.opacity(0.25), lineWidth: 1))
            }
            // MARK: - Map CTA
            Button(action: { showMap = true }) {
                HStack(spacing: 8) {
                    Text("🗺️  View Nearby Y2Y Organizations")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(Color.y2yTan)
                    Spacer()
                    Image(systemName: "chevron.right").foregroundColor(Color.y2yAccent)
                }
                .padding(16).background(Color.y2yCard).clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.y2yAccent.opacity(0.25), lineWidth: 1))
            }
            BackButton(action: onBack)
        }
        .toolbar { LogoutToolbarItem() }
        .sheet(isPresented: $showMap) {
            Y2YMapView()
                .environmentObject(appState)
                .environmentObject(firestoreManager)
        }
    }
}
// MARK: - Restaurant: Browse Farm Produce Marketplace
struct RestaurantProduceMarketplacePage: View {
    @EnvironmentObject var appState: AppState
    let onBack: () -> Void
    let onDispatch: () -> Void
    @State private var purchasedIDs: Set<UUID> = []
    @State private var quantitySelections: [UUID: Double] = [:]
    var body: some View {
        Y2YPage(title: "Farm Marketplace", subtitle: "Fresh produce direct from local farms") {
            if appState.produceListings.isEmpty {
                VStack(spacing: 12) {
                    Text("🌾").font(.system(size: 48))
                    Text("No produce listings yet.\nCheck back soon!")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(Color.y2ySubtext)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity).padding(32)
                .background(Color.y2yCard).clipShape(RoundedRectangle(cornerRadius: 22))
            } else {
                ForEach(appState.produceListings) { listing in
                    let qty = quantitySelections[listing.id] ?? 1
                    let purchased = purchasedIDs.contains(listing.id)
                    ProduceListingCard(
                        listing: listing,
                        quantity: qty,
                        isPurchased: purchased,
                        onQuantityChange: { q in quantitySelections[listing.id] = q },
                        onBuy: {
                            withAnimation(.spring(response: 0.4)) {
                                purchasedIDs.insert(listing.id)
                                let order = ProduceOrder(
                                    restaurantName: appState.restaurantName,
                                    farmName: listing.farmName,
                                    produceName: listing.produceName,
                                    quantity: qty,
                                    unit: listing.unit,
                                    totalPrice: qty * listing.pricePerUnit,
                                    date: Date()
                                )
                                appState.produceOrders.append(order)
                            }
                        }
                    )
                }
            }
            // Show recent orders placed by this restaurant
            if !appState.produceOrders.filter({ $0.restaurantName == appState.restaurantName }).isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("YOUR ORDERS")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(Color.y2ySubtext.opacity(0.65))
                    ForEach(appState.produceOrders.filter { $0.restaurantName == appState.restaurantName }) { order in
                        ProduceOrderRow(order: order)
                    }
                }
            }
            // MARK: - Track Live Dispatch CTA
            Button(action: onDispatch) {
                HStack(spacing: 8) {
                    Text("🚚  Track Live Compost Dispatch")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(Color.y2yTan)
                    Spacer()
                    Image(systemName: "chevron.right").foregroundColor(Color.y2yAccent)
                }
                .padding(16).background(Color.y2yCard).clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.y2yAccent.opacity(0.25), lineWidth: 1))
            }
            BackButton(action: onBack)
        }
        .toolbar { LogoutToolbarItem() }
    }
}
struct ProduceListingCard: View {
    let listing: ProduceListing
    let quantity: Double
    let isPurchased: Bool
    let onQuantityChange: (Double) -> Void
    let onBuy: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                if let img = listing.produceImage {
                    Image(uiImage: img).resizable().scaledToFill()
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                } else {
                    Text(listing.produceEmoji).font(.system(size: 36))
                        .frame(width: 56, height: 56)
                        .background(Color.y2yBackground.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(listing.produceName)
                        .font(.system(size: 16, weight: .bold, design: .rounded)).foregroundColor(Color.y2yTan)
                    Text(listing.farmName)
                        .font(.system(size: 12, design: .rounded)).foregroundColor(Color.y2yAccent)
                    Text("\(Int(listing.availableUnits)) \(listing.unit)s available")
                        .font(.system(size: 11, design: .rounded)).foregroundColor(Color.y2ySubtext)
                    if let score = listing.freshScore {
                        FreshnessBadge(score: score)
                    }
                }
                Spacer()
                Text(String(format: "$%.2f/\(listing.unit)", listing.pricePerUnit))
                    .font(.system(size: 15, weight: .bold, design: .rounded)).foregroundColor(Color.y2yAccent)
            }
            if !isPurchased {
                HStack(spacing: 12) {
                    Text("Qty:").font(.system(size: 12, weight: .bold, design: .rounded)).foregroundColor(Color.y2ySubtext)
                    Slider(value: Binding(get: { quantity }, set: onQuantityChange), in: 1...min(listing.availableUnits, 100), step: 1)
                        .tint(Color.y2yAccent)
                    Text("\(Int(quantity)) \(listing.unit)")
                        .font(.system(size: 13, weight: .bold, design: .rounded)).foregroundColor(Color.y2yAccent)
                        .frame(width: 66, alignment: .trailing)
                }
                .padding(12).background(Color.y2yBackground.opacity(0.4)).clipShape(RoundedRectangle(cornerRadius: 14))
            }
            Button(action: onBuy) {
                HStack {
                    Image(systemName: isPurchased ? "checkmark.circle.fill" : "bag.fill")
                    Text(isPurchased ? "Order Placed! ✓" : String(format: "Order — $%.2f", quantity * listing.pricePerUnit))
                }
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(isPurchased ? Color.y2ySubtext : Color.y2yCard)
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(isPurchased ? Color.white.opacity(0.08) : Color.y2yAccent)
                .clipShape(RoundedRectangle(cornerRadius: 18))
            }
            .disabled(isPurchased)
        }
        .padding(18).background(Color.y2yCard).clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
    }
}
struct ProduceOrderRow: View {
    let order: ProduceOrder
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Color.y2yAccent.opacity(0.15)).frame(width: 40, height: 40)
                Image(systemName: "bag.fill").foregroundColor(Color.y2yAccent).font(.system(size: 16))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("\(order.produceName) from \(order.farmName)")
                    .font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundColor(Color.y2yTan)
                Text("\(Int(order.quantity)) \(order.unit) · \(order.date.formatted(date: .abbreviated, time: .omitted))")
                    .font(.system(size: 11, design: .rounded)).foregroundColor(Color.y2ySubtext)
            }
            Spacer()
            Text(String(format: "$%.2f", order.totalPrice))
                .font(.system(size: 13, weight: .bold, design: .rounded)).foregroundColor(Color.y2yAccent)
        }
        .padding(14).background(Color.y2yCard).clipShape(RoundedRectangle(cornerRadius: 18))
    }
}
// MARK: - Shared UI: Badge Chip
struct BadgeChip: View {
    let badge: RestaurantBadge
    let earned: Bool
    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(earned ? badge.color.opacity(0.2) : Color.white.opacity(0.05))
                    .frame(width: 54, height: 54)
                    .overlay(Circle().stroke(earned ? badge.color.opacity(0.5) : Color.white.opacity(0.08), lineWidth: 1.5))
                Text(badge.icon).font(.system(size: 24))
                    .opacity(earned ? 1.0 : 0.3)
                if !earned {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Color.white.opacity(0.25))
                        .offset(x: 16, y: 16)
                }
            }
            Text(badge.name)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(earned ? Color.y2yTan : Color.y2ySubtext.opacity(0.4))
            Text("\(Int(badge.requiredLbs)) lbs")
                .font(.system(size: 9, design: .rounded))
                .foregroundColor(earned ? badge.color.opacity(0.8) : Color.y2ySubtext.opacity(0.3))
        }
        .frame(width: 70)
    }
}
// MARK: - Stat Mini Cell
struct StatMiniCell: View {
    let label: String
    let value: String
    let icon: String
    let color: Color
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon).foregroundColor(color).font(.system(size: 14))
            Text(value).font(.system(size: 14, weight: .bold, design: .rounded)).foregroundColor(Color.y2yTan)
            Text(label).font(.system(size: 9, design: .rounded)).foregroundColor(Color.y2ySubtext.opacity(0.65)).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}
// MARK: - Farm Flow
struct FarmFlowView: View {
    @EnvironmentObject var appState: AppState
    @State private var currentPage = 1
    var body: some View {
        NavigationStack {
            switch currentPage {
            case 1: FarmPage1(onNext: { currentPage = 2 }).environmentObject(appState)
            case 2: FarmPage2(onBack: { currentPage = 1 }, onNext: { currentPage = 3 }).environmentObject(appState)
            case 3: FarmProduceMarketplacePage(onBack: { currentPage = 2 }, onDispatch: { currentPage = 4 }).environmentObject(appState)
            case 4: CompostDispatchView(initialRole: .farm, onBack: { currentPage = 3 }).environmentObject(appState)
            default: FarmPage1(onNext: { currentPage = 2 }).environmentObject(appState)
            }
        }
    }
}
struct FarmPage1: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var firestoreManager: FirestoreManager
    let onNext: () -> Void
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var isSaving = false
    @State private var geocodeError: String? = nil
    
    private func geocodeAddress() async -> (latitude: Double, longitude: Double)? {
        let geocoder = CLGeocoder()
        do {
            let placemarks = try await geocoder.geocodeAddressString(appState.address)
            if let location = placemarks.first?.location {
                return (location.coordinate.latitude, location.coordinate.longitude)
            }
        } catch {
            await MainActor.run {
                geocodeError = "Unable to find address. Please check and try again."
            }
        }
        return nil
    }
    
    private func saveFarmInfo() {
        guard !appState.farmName.isEmpty, !appState.farmLocation.isEmpty, !appState.address.isEmpty else { return }
        
        isSaving = true
        geocodeError = nil
        
        Task {
            // Geocode address first
            guard let coordinates = await geocodeAddress() else {
                await MainActor.run {
                    isSaving = false
                }
                return
            }
            
            do {
                try await firestoreManager.updateFarmInfo(
                    userID: appState.userID,
                    name: appState.farmName,
                    location: appState.farmLocation,
                    address: appState.address,
                    latitude: coordinates.latitude,
                    longitude: coordinates.longitude
                )
                await MainActor.run {
                    appState.latitude = coordinates.latitude
                    appState.longitude = coordinates.longitude
                    isSaving = false
                    onNext()
                }
            } catch {
                print("Error saving farm info: \(error.localizedDescription)")
                await MainActor.run {
                    isSaving = false
                }
            }
        }
    }
    
    var body: some View {
        Y2YPage(title: "Your Farm", subtitle: "Share your farm's details") {
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                ZStack {
                    RoundedRectangle(cornerRadius: 24).fill(Color.y2yCard).frame(height: 180)
                    if let img = appState.farmImage {
                        Image(uiImage: img).resizable().scaledToFill().frame(height: 180).clipShape(RoundedRectangle(cornerRadius: 24))
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "photo.badge.plus").font(.system(size: 34)).foregroundColor(Color.y2yAccent)
                            Text("Add Farm Photo").font(.system(size: 13, weight: .medium, design: .rounded)).foregroundColor(Color.y2ySubtext)
                        }
                    }
                }
            }
            .onChange(of: selectedPhoto) { item in Task { if let d = try? await item?.loadTransferable(type: Data.self), let img = UIImage(data: d) { appState.farmImage = img } } }
            Y2YInputField(label: "Farm Name", placeholder: "e.g. Sunflower Acres", text: $appState.farmName)
            Y2YInputField(label: "Farm Location", placeholder: "e.g. Springfield County", text: $appState.farmLocation)
            Y2YInputField(label: "Street Address", placeholder: "e.g. 789 County Rd, Springfield, CA 12345", text: $appState.address)
            
            if let error = geocodeError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(Color(red: 1, green: 0.5, blue: 0.45))
                    Text(error)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(Color(red: 1, green: 0.5, blue: 0.45))
                }
                .padding(12)
                .background(Color.y2yCard)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            
            Y2YButton(title: isSaving ? "Saving..." : "Next: Browse Compost", icon: "arrow.right", action: saveFarmInfo)
                .disabled(appState.farmName.isEmpty || appState.farmLocation.isEmpty || appState.address.isEmpty || isSaving).padding(.top, 4)
        }
        .toolbar { LogoutToolbarItem() }
    }
}
struct FarmPage2: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var firestoreManager: FirestoreManager
    let onBack: () -> Void
    let onNext: () -> Void
    @State private var purchasedID: UUID? = nil
    @State private var showMap = false
    var body: some View {
        Y2YPage(title: "Compost Marketplace", subtitle: "Buy from local composting facilities") {
            ForEach(appState.marketplaceListings) { listing in
                CompostListingCard(listing: listing, isPurchased: purchasedID == listing.id) { withAnimation { purchasedID = listing.id } }
            }
            // CTA to manage produce listings
            Button(action: onNext) {
                HStack(spacing: 8) {
                    Text("🌿  Manage Your Produce Listings")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(Color.y2yTan)
                    Spacer()
                    Image(systemName: "chevron.right").foregroundColor(Color.y2yAccent)
                }
                .padding(16).background(Color.y2yCard).clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.y2yAccent.opacity(0.25), lineWidth: 1))
            }
            // MARK: - Map CTA
            Button(action: { showMap = true }) {
                HStack(spacing: 8) {
                    Text("🗺️  View Nearby Y2Y Organizations")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(Color.y2yTan)
                    Spacer()
                    Image(systemName: "chevron.right").foregroundColor(Color.y2yAccent)
                }
                .padding(16).background(Color.y2yCard).clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.y2yAccent.opacity(0.25), lineWidth: 1))
            }
            BackButton(action: onBack)
        }
        .toolbar { LogoutToolbarItem() }
        .sheet(isPresented: $showMap) {
            Y2YMapView()
                .environmentObject(appState)
                .environmentObject(firestoreManager)
        }
    }
}
// MARK: - Farm: Produce Marketplace Management
struct FarmProduceMarketplacePage: View {
    @EnvironmentObject var appState: AppState
    let onBack: () -> Void
    let onDispatch: () -> Void
    @State private var newProduce    = ""
    @State private var newEmoji      = ""
    @State private var newPrice      = ""
    @State private var newUnits      = ""
    @State private var newUnit       = "lb"
    @State private var showSuccess   = false
    @State private var newPhotoItem: PhotosPickerItem? = nil
    @State private var newImage: UIImage? = nil
    @State private var newFreshScore: Double? = nil
    @State private var isClassifying = false
    @State private var classifierUnavailable = false
    @State private var postError: String? = nil
    let unitOptions = ["lb", "bunch", "each", "oz", "flat", "bag"]
    let emojiOptions = ["🍅","🥕","🥬","🌽","🥦","🍓","🫑","🧅","🌿","🍠","🥒","🫛"]
    var myListings: [ProduceListing] {
        appState.produceListings.filter { $0.farmName == appState.farmName }
    }
    var myOrders: [ProduceOrder] {
        appState.produceOrders.filter { $0.farmName == appState.farmName }
    }
    var body: some View {
        Y2YPage(title: "My Produce", subtitle: "List your crops for local restaurants") {
            // Revenue summary
            if !myOrders.isEmpty {
                let totalRevenue = myOrders.reduce(0.0) { $0 + $1.totalPrice }
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Total Revenue").font(.system(size: 11, weight: .bold, design: .rounded)).foregroundColor(Color.y2ySubtext)
                        Text(String(format: "$%.2f", totalRevenue))
                            .font(Font.custom("Georgia-Bold", size: 28)).foregroundColor(Color.y2yAccent)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Orders Filled").font(.system(size: 11, weight: .bold, design: .rounded)).foregroundColor(Color.y2ySubtext)
                        Text("\(myOrders.count)").font(Font.custom("Georgia-Bold", size: 28)).foregroundColor(Color.y2yTan)
                    }
                }
                .padding(18).background(Color.y2yCard).clipShape(RoundedRectangle(cornerRadius: 22))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.y2yAccent.opacity(0.2), lineWidth: 1.5))
            }
            // My active listings
            if !myListings.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("YOUR ACTIVE LISTINGS")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(Color.y2ySubtext.opacity(0.65))
                    ForEach(myListings) { listing in
                        FarmProduceListingCard(listing: listing, onDelete: {
                            withAnimation { appState.produceListings.removeAll { $0.id == listing.id } }
                        })
                    }
                }
            }
            // Incoming orders for this farm
            if !myOrders.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("INCOMING ORDERS")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(Color.y2ySubtext.opacity(0.65))
                    ForEach(myOrders) { order in
                        IncomingOrderCard(order: order)
                    }
                }
            }
            // Add new listing form
            VStack(alignment: .leading, spacing: 14) {
                Text("ADD NEW LISTING")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(Color.y2ySubtext.opacity(0.65))
                // MARK: Produce photo (required) + freshness check
                VStack(alignment: .leading, spacing: 8) {
                    Text("Produce Photo (required)").font(.system(size: 12, weight: .bold, design: .rounded)).foregroundColor(Color.y2ySubtext)
                    PhotosPicker(selection: $newPhotoItem, matching: .images) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 20).fill(Color.y2yBackground.opacity(0.5)).frame(height: 150)
                            if let img = newImage {
                                Image(uiImage: img).resizable().scaledToFill()
                                    .frame(height: 150)
                                    .frame(maxWidth: .infinity)
                                    .clipShape(RoundedRectangle(cornerRadius: 20))
                            } else {
                                VStack(spacing: 8) {
                                    Image(systemName: "camera.badge.ellipsis").font(.system(size: 30)).foregroundColor(Color.y2yAccent)
                                    Text("Add a photo of this produce\nfor its freshness check")
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                        .foregroundColor(Color.y2ySubtext)
                                        .multilineTextAlignment(.center)
                                }
                            }
                        }
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.08), lineWidth: 1))
                    }
                    .onChange(of: newPhotoItem) { item in
                        Task {
                            guard let d = try? await item?.loadTransferable(type: Data.self),
                                  let img = UIImage(data: d) else { return }
                            newImage = img
                            newFreshScore = nil
                            postError = nil
                            classifierUnavailable = false
                            isClassifying = true
                            let score = await FreshnessClassifier.classifyInBackground(image: img)
                            withAnimation(.spring(response: 0.4)) {
                                newFreshScore = score
                                classifierUnavailable = (score == nil)
                                isClassifying = false
                            }
                        }
                    }
                    if isClassifying {
                        HStack(spacing: 8) {
                            ProgressView().progressViewStyle(CircularProgressViewStyle(tint: Color.y2yAccent))
                            Text("Checking freshness...")
                                .font(.system(size: 12, design: .rounded)).foregroundColor(Color.y2ySubtext)
                        }
                    } else if let score = newFreshScore {
                        let category = FreshnessCategory(score: score)
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("FRESH CONFIDENCE SCORE")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundColor(Color.y2ySubtext.opacity(0.7))
                                Spacer()
                                FreshnessBadge(score: score)
                            }
                            Text(String(format: "%.4f", score))
                                .font(Font.custom("Georgia-Bold", size: 24))
                                .foregroundColor(category.color)
                            Text("Range \(category.rangeText) · \(category.colorName) (\(category.title))")
                                .font(.system(size: 11, design: .rounded))
                                .foregroundColor(Color.y2ySubtext)
                        }
                        .padding(14)
                        .background(Color.y2yBackground.opacity(0.4))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(category.color.opacity(0.4), lineWidth: 1.5))
                    } else if classifierUnavailable && newImage != nil {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(Color(red: 0.94, green: 0.85, blue: 0.54))
                            Text("Freshness check unavailable — the listing will post without a score.")
                                .font(.system(size: 12, design: .rounded)).foregroundColor(Color.y2ySubtext)
                        }
                    }
                }
                // Emoji picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Produce Icon").font(.system(size: 12, weight: .bold, design: .rounded)).foregroundColor(Color.y2ySubtext)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(emojiOptions, id: \.self) { emoji in
                                Text(emoji).font(.system(size: 26))
                                    .frame(width: 48, height: 48)
                                    .background(newEmoji == emoji ? Color.y2yAccent.opacity(0.25) : Color.y2yCard)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(newEmoji == emoji ? Color.y2yAccent : Color.clear, lineWidth: 1.5))
                                    .onTapGesture { newEmoji = emoji }
                            }
                        }
                    }
                }
                Y2YInputField(label: "Produce Name", placeholder: "e.g. Heirloom Tomatoes", text: $newProduce)
                Y2YInputField(label: "Price per unit ($)", placeholder: "3.50", text: $newPrice).keyboardType(.decimalPad)
                Y2YInputField(label: "Available quantity", placeholder: "100", text: $newUnits).keyboardType(.numberPad)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Unit").font(.system(size: 12, weight: .bold, design: .rounded)).foregroundColor(Color.y2ySubtext)
                    Menu {
                        ForEach(unitOptions, id: \.self) { u in Button(u) { newUnit = u } }
                    } label: {
                        HStack {
                            Text(newUnit).font(.system(size: 15, design: .rounded)).foregroundColor(Color.y2yTan)
                            Spacer()
                            Image(systemName: "chevron.down").foregroundColor(Color.y2yAccent).font(.system(size: 13))
                        }
                        .padding(16).background(Color.y2yCard).clipShape(RoundedRectangle(cornerRadius: 20))
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.07), lineWidth: 1))
                    }
                }
                if showSuccess {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill").foregroundColor(Color.y2yAccent)
                        Text("Listing posted! Restaurants can now see it.").font(.system(size: 13, design: .rounded)).foregroundColor(Color.y2yTan)
                    }
                    .padding(12).background(Color.y2yCard).clipShape(RoundedRectangle(cornerRadius: 14))
                    .transition(.opacity)
                }
                if let postError = postError {
                    HStack(spacing: 8) {
                        Image(systemName: "xmark.octagon.fill").foregroundColor(Color(red: 0.95, green: 0.35, blue: 0.30))
                        Text(postError)
                            .font(.system(size: 12, design: .rounded)).foregroundColor(Color.y2yTan)
                    }
                    .padding(12).background(Color(red: 0.95, green: 0.35, blue: 0.30).opacity(0.12)).clipShape(RoundedRectangle(cornerRadius: 14))
                }
                Y2YButton(title: "Post Listing", icon: "plus.circle.fill") {
                    guard let price = Double(newPrice), let qty = Double(newUnits), !newProduce.isEmpty,
                          let image = newImage else { return }
                    // Quality gate: High Risk produce can't be listed.
                    if let score = newFreshScore, FreshnessCategory(score: score) == .red {
                        withAnimation { postError = "This photo scored \(String(format: "%.4f", score)) — Red (High Risk). Please retake the photo or list fresher produce." }
                        return
                    }
                    withAnimation(.spring(response: 0.4)) {
                        appState.produceListings.append(ProduceListing(
                            farmName: appState.farmName,
                            produceName: newProduce,
                            pricePerUnit: price,
                            availableUnits: qty,
                            unit: newUnit,
                            produceEmoji: newEmoji.isEmpty ? "🌿" : newEmoji,
                            produceImage: image,
                            freshScore: newFreshScore
                        ))
                        newProduce = ""; newPrice = ""; newUnits = ""; newEmoji = ""
                        newPhotoItem = nil; newImage = nil; newFreshScore = nil
                        classifierUnavailable = false; postError = nil
                        showSuccess = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            withAnimation { showSuccess = false }
                        }
                    }
                }
                .disabled(newProduce.isEmpty || newPrice.isEmpty || newUnits.isEmpty || newImage == nil || isClassifying)
            }
            .padding(18).background(Color.y2yCard).clipShape(RoundedRectangle(cornerRadius: 24))
            // MARK: - Track Live Dispatch CTA
            Button(action: onDispatch) {
                HStack(spacing: 8) {
                    Text("🚚  Track Live Compost Dispatch")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(Color.y2yTan)
                    Spacer()
                    Image(systemName: "chevron.right").foregroundColor(Color.y2yAccent)
                }
                .padding(16).background(Color.y2yCard).clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.y2yAccent.opacity(0.25), lineWidth: 1))
            }
            BackButton(action: onBack)
        }
        .toolbar { LogoutToolbarItem() }
    }
}
struct FarmProduceListingCard: View {
    let listing: ProduceListing
    let onDelete: () -> Void
    var body: some View {
        HStack(spacing: 14) {
            if let img = listing.produceImage {
                Image(uiImage: img).resizable().scaledToFill()
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            } else {
                Text(listing.produceEmoji).font(.system(size: 26))
                    .frame(width: 48, height: 48)
                    .background(Color.y2yBackground.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(listing.produceName).font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundColor(Color.y2yTan)
                Text("\(Int(listing.availableUnits)) \(listing.unit)s · \(String(format: "$%.2f/\(listing.unit)", listing.pricePerUnit))")
                    .font(.system(size: 12, design: .rounded)).foregroundColor(Color.y2ySubtext)
                if let score = listing.freshScore {
                    FreshnessBadge(score: score, compact: true)
                }
            }
            Spacer()
            Button(action: onDelete) {
                Image(systemName: "trash").foregroundColor(Color(red: 0.95, green: 0.45, blue: 0.40)).font(.system(size: 16))
            }
        }
        .padding(14).background(Color.y2yCard).clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.black.opacity(0.14), radius: 6, x: 0, y: 3)
    }
}
struct IncomingOrderCard: View {
    let order: ProduceOrder
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Color(red: 0.95, green: 0.58, blue: 0.35).opacity(0.18)).frame(width: 44, height: 44)
                Image(systemName: "fork.knife").foregroundColor(Color(red: 0.95, green: 0.58, blue: 0.35)).font(.system(size: 16))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(order.restaurantName).font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundColor(Color.y2yTan)
                Text("\(Int(order.quantity)) \(order.unit) of \(order.produceName)")
                    .font(.system(size: 12, design: .rounded)).foregroundColor(Color.y2ySubtext)
                Text(order.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 10, design: .rounded)).foregroundColor(Color.y2ySubtext.opacity(0.6))
            }
            Spacer()
            Text(String(format: "$%.2f", order.totalPrice))
                .font(.system(size: 14, weight: .bold, design: .rounded)).foregroundColor(Color.y2yAccent)
        }
        .padding(14).background(Color.y2yCard).clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.black.opacity(0.14), radius: 6, x: 0, y: 3)
    }
}
// MARK: - Composting Facility Flow
struct CompostFacilityFlowView: View {
    @EnvironmentObject var appState: AppState
    @State private var currentPage = 1
    var body: some View {
        NavigationStack {
            switch currentPage {
            case 1: FacilityPage1(onNext: { currentPage = 2 }).environmentObject(appState)
            case 2: FacilityPage2(onBack: { currentPage = 1 }, onDispatch: { currentPage = 3 }).environmentObject(appState)
            case 3: CompostDispatchView(initialRole: .hub, onBack: { currentPage = 2 }).environmentObject(appState)
            default: FacilityPage1(onNext: { currentPage = 2 }).environmentObject(appState)
            }
        }
    }
}
struct FacilityPage1: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var firestoreManager: FirestoreManager
    let onNext: () -> Void
    @State private var isSaving = false
    @State private var geocodeError: String? = nil
    
    private func geocodeAddress() async -> (latitude: Double, longitude: Double)? {
        let geocoder = CLGeocoder()
        do {
            let placemarks = try await geocoder.geocodeAddressString(appState.address)
            if let location = placemarks.first?.location {
                return (location.coordinate.latitude, location.coordinate.longitude)
            }
        } catch {
            await MainActor.run {
                geocodeError = "Unable to find address. Please check and try again."
            }
        }
        return nil
    }
    
    private func saveFacilityInfo() {
        guard !appState.facilityName.isEmpty, !appState.address.isEmpty else { return }
        
        isSaving = true
        geocodeError = nil
        
        Task {
            // Geocode address first
            guard let coordinates = await geocodeAddress() else {
                await MainActor.run {
                    isSaving = false
                }
                return
            }
            
            do {
                try await firestoreManager.updateFacilityInfo(
                    userID: appState.userID,
                    name: appState.facilityName,
                    address: appState.address,
                    latitude: coordinates.latitude,
                    longitude: coordinates.longitude
                )
                await MainActor.run {
                    appState.latitude = coordinates.latitude
                    appState.longitude = coordinates.longitude
                    isSaving = false
                    onNext()
                }
            } catch {
                print("Error saving facility info: \(error.localizedDescription)")
                await MainActor.run {
                    isSaving = false
                }
            }
        }
    }
    
    var body: some View {
        Y2YPage(title: "Your Facility", subtitle: "Set up your composting facility profile") {
            ZStack {
                Circle().fill(Color.y2yCard).frame(width: 118, height: 118)
                    .shadow(color: Color.black.opacity(0.22), radius: 14, x: 0, y: 6)
                Image(systemName: "arrow.3.trianglepath")
                    .font(.system(size: 50, weight: .thin)).foregroundColor(Color.y2yAccent)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 8)
            Y2YInputField(label: "Facility Name", placeholder: "e.g. Green Earth Compost Co.", text: $appState.facilityName)
            Y2YInputField(label: "Street Address", placeholder: "e.g. 456 Industrial Dr, Springfield, CA 12345", text: $appState.address)
            
            if let error = geocodeError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(Color(red: 1, green: 0.5, blue: 0.45))
                    Text(error)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(Color(red: 1, green: 0.5, blue: 0.45))
                }
                .padding(12)
                .background(Color.y2yCard)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            
            Y2YButton(title: isSaving ? "Saving..." : "Continue to Dashboard", icon: "arrow.right", action: saveFacilityInfo)
                .disabled(appState.facilityName.isEmpty || appState.address.isEmpty || isSaving).padding(.top, 4)
        }
        .toolbar { LogoutToolbarItem() }
    }
}
struct FacilityPage2: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var firestoreManager: FirestoreManager
    let onBack: () -> Void
    let onDispatch: () -> Void
    @State private var selectedTab = 0
    @State private var newPrice = ""
    @State private var newPounds = ""
    @State private var showMap = false
    var body: some View {
        Y2YPage(title: appState.facilityName, subtitle: "Facility Dashboard") {
            HStack(spacing: 0) {
                DashTabButton(title: "Pickups",      isSelected: selectedTab == 0) { selectedTab = 0 }
                DashTabButton(title: "Marketplace",  isSelected: selectedTab == 1) { selectedTab = 1 }
            }
            .background(Color.y2yCard).clipShape(RoundedRectangle(cornerRadius: 20))
            // MARK: - Track Live Dispatch CTA
            Button(action: onDispatch) {
                HStack(spacing: 8) {
                    Text("🚚  Open Live Dispatch Board")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(Color.y2yTan)
                    Spacer()
                    Image(systemName: "chevron.right").foregroundColor(Color.y2yAccent)
                }
                .padding(16).background(Color.y2yCard).clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.y2yAccent.opacity(0.25), lineWidth: 1))
            }
            if selectedTab == 0 {
                ForEach(appState.pickupRequests) { PickupRequestCard(request: $0) }
            } else {
                ForEach(appState.marketplaceListings) { MyListingCard(listing: $0) }
                VStack(alignment: .leading, spacing: 14) {
                    Text("Add New Listing").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundColor(Color.y2ySubtext)
                    Y2YInputField(label: "Price per lb ($)", placeholder: "0.40", text: $newPrice).keyboardType(.decimalPad)
                    Y2YInputField(label: "Available (lbs)", placeholder: "100", text: $newPounds).keyboardType(.numberPad)
                    Y2YButton(title: "Post Listing", icon: "plus.circle.fill") {
                        if let p = Double(newPrice), let lbs = Double(newPounds) {
                            appState.marketplaceListings.append(CompostListing(facilityName: appState.facilityName, pricePerPound: p, availablePounds: lbs))
                            newPrice = ""; newPounds = ""
                        }
                    }
                    .disabled(newPrice.isEmpty || newPounds.isEmpty)
                }
                .padding(18).background(Color.y2yCard).clipShape(RoundedRectangle(cornerRadius: 24))
            }
            // MARK: - Map CTA
            Button(action: { showMap = true }) {
                HStack(spacing: 8) {
                    Text("🗺️  View Nearby Y2Y Organizations")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(Color.y2yTan)
                    Spacer()
                    Image(systemName: "chevron.right").foregroundColor(Color.y2yAccent)
                }
                .padding(16).background(Color.y2yCard).clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.y2yAccent.opacity(0.25), lineWidth: 1))
            }
            BackButton(action: onBack)
        }
        .toolbar { LogoutToolbarItem() }
        .sheet(isPresented: $showMap) {
            Y2YMapView()
                .environmentObject(appState)
                .environmentObject(firestoreManager)
        }
    }
}
struct DashTabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(isSelected ? Color.y2yCard : Color.y2ySubtext)
                .frame(maxWidth: .infinity).padding(.vertical, 12)
                .background(isSelected ? Color.y2yAccent : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .padding(4)
        }
    }
}
struct PickupRequestCard: View {
    let request: PickupRequest
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Color(red: 0.95, green: 0.58, blue: 0.35).opacity(0.18)).frame(width: 46, height: 46)
                Image(systemName: "fork.knife").foregroundColor(Color(red: 0.95, green: 0.58, blue: 0.35))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(request.restaurantName).font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundColor(Color.y2yTan)
                Text(request.location).font(.system(size: 11, design: .rounded)).foregroundColor(Color.y2ySubtext)
                Text(request.date.formatted(date: .abbreviated, time: .shortened)).font(.system(size: 11, design: .rounded)).foregroundColor(Color.y2ySubtext)
            }
            Spacer()
            Text("\(Int(request.pounds)) lbs").font(.system(size: 13, weight: .bold, design: .rounded)).foregroundColor(Color.y2yAccent)
        }
        .padding(16).background(Color.y2yCard).clipShape(RoundedRectangle(cornerRadius: 22))
        .shadow(color: Color.black.opacity(0.16), radius: 7, x: 0, y: 3)
    }
}
struct MyListingCard: View {
    let listing: CompostListing
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(listing.facilityName).font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundColor(Color.y2yTan)
                Text("\(Int(listing.availablePounds)) lbs available").font(.system(size: 12, design: .rounded)).foregroundColor(Color.y2ySubtext)
            }
            Spacer()
            Text(String(format: "$%.2f/lb", listing.pricePerPound))
                .font(.system(size: 14, weight: .bold, design: .rounded)).foregroundColor(Color(red: 0.78, green: 0.65, blue: 0.38))
        }
        .padding(16).background(Color.y2yCard).clipShape(RoundedRectangle(cornerRadius: 22))
        .shadow(color: Color.black.opacity(0.16), radius: 7, x: 0, y: 3)
    }
}
// MARK: - Shared Page Shell
struct Y2YPage<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content
    var body: some View {
        ZStack {
            Color.y2yBackground.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Yard2YumHeader().padding(.bottom, 4)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title).font(Font.custom("Georgia-Bold", size: 26)).foregroundColor(Color.y2yTan)
                        Text(subtitle).font(.system(size: 14, design: .rounded)).foregroundColor(Color.y2ySubtext)
                    }
                    content
                }
                .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 52)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}
struct Y2YInputField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label).font(.system(size: 12, weight: .bold, design: .rounded)).foregroundColor(Color.y2ySubtext)
            TextField("", text: $text, prompt: Text(placeholder).foregroundColor(Color.y2ySubtext.opacity(0.45)))
                .font(.system(size: 15, design: .rounded)).foregroundColor(Color.y2yTan).tint(Color.y2yAccent)
                .padding(16).background(Color.y2yCard).clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.07), lineWidth: 1))
        }
    }
}
struct Y2YButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title).font(Font.custom("Georgia-Bold", size: 17))
                Image(systemName: icon).font(.system(size: 14, weight: .bold))
            }
            .foregroundColor(Color.y2yCard)
            .frame(maxWidth: .infinity).padding(.vertical, 17)
            .background(Color.y2yAccent)
            .clipShape(RoundedRectangle(cornerRadius: 26))
            .shadow(color: Color.y2yAccent.opacity(0.3), radius: 12, x: 0, y: 5)
        }
    }
}
struct BackButton: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.left").font(.system(size: 13, weight: .semibold))
                Text("Back").font(.system(size: 15, weight: .medium, design: .rounded))
            }
            .foregroundColor(Color.y2ySubtext)
        }
        .padding(.top, 4)
    }
}
struct LogoutToolbarItem: ToolbarContent {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authManager: AuthenticationManager
    
    var body: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                Task {
                    do {
                        try authManager.signOut()
                        await MainActor.run {
                            appState.resetForLogout()
                        }
                    } catch {
                        print("Error signing out: \(error.localizedDescription)")
                    }
                }
            } label: {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .foregroundColor(Color.y2yAccent)
            }
        }
    }
}
struct CompostListingCard: View {
    let listing: CompostListing
    let isPurchased: Bool
    let onBuy: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(listing.facilityName).font(.system(size: 16, weight: .bold, design: .rounded)).foregroundColor(Color.y2yTan)
                    Text("\(Int(listing.availablePounds)) lbs available").font(.system(size: 12, design: .rounded)).foregroundColor(Color.y2ySubtext)
                }
                Spacer()
                Text(String(format: "$%.2f/lb", listing.pricePerPound))
                    .font(.system(size: 16, weight: .bold, design: .rounded)).foregroundColor(Color.y2yAccent)
            }
            Button(action: onBuy) {
                HStack {
                    Image(systemName: isPurchased ? "checkmark.circle.fill" : "cart.fill")
                    Text(isPurchased ? "Order Placed!" : "Buy Compost")
                }
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(isPurchased ? Color.y2ySubtext : Color.y2yCard)
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(isPurchased ? Color.white.opacity(0.08) : Color.y2yAccent)
                .clipShape(RoundedRectangle(cornerRadius: 18))
            }
            .disabled(isPurchased)
        }
        .padding(18).background(Color.y2yCard).clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
    }
}
// MARK: - Header
struct Yard2YumHeader: View {
    var body: some View {
        Image("y2y")
            .resizable()
            .scaledToFit()
            .frame(width: 200, height: 200)
            .padding(.top, 1)
    }
}
#Preview {
    ContentView()
}

