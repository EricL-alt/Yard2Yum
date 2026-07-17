//
//  AuthenticationManager.swift
//  Yard2Yum
//
//  Created by Eric Liu on 09/03/2026.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

@MainActor
class AuthenticationManager: ObservableObject {

    // MARK: - Error Translation
    // Firebase surfaces cryptic strings like "The supplied auth credential is
    // malformed or has expired" for plain wrong-password sign-ins (email
    // enumeration protection collapses wrongPassword/userNotFound into
    // invalidCredential). Translate the common codes before showing them.
    nonisolated static func friendlyMessage(for error: Error) -> String {
        let nsError = error as NSError
        if nsError.domain == AuthErrorDomain, let code = AuthErrorCode(rawValue: nsError.code) {
            switch code {
            case .invalidCredential, .wrongPassword, .userNotFound:
                return "Incorrect email or password. Please try again."
            case .invalidEmail:
                return "That email address isn't valid."
            case .emailAlreadyInUse:
                return "An account with this email already exists. Try signing in instead."
            case .weakPassword:
                return "Password is too weak — use at least 6 characters."
            case .userDisabled:
                return "This account has been disabled."
            case .tooManyRequests:
                return "Too many attempts. Please wait a moment and try again."
            case .networkError:
                return "Network error. Check your connection and try again."
            case .userTokenExpired, .invalidUserToken:
                return "Your session has expired. Please sign in again."
            default:
                return error.localizedDescription
            }
        }
        if nsError.domain == FirestoreErrorDomain,
           nsError.code == FirestoreErrorCode.permissionDenied.rawValue {
            return "Couldn't access your profile data. Please try again later."
        }
        return error.localizedDescription
    }
    @Published var user: User?
    @Published var isAuthenticated = false
    @Published var errorMessage: String?
    
    private var authStateHandler: AuthStateDidChangeListenerHandle?
    
    init() {
        configureAuthStateChanges()
    }
    
    deinit {
        if let handler = authStateHandler {
            Auth.auth().removeStateDidChangeListener(handler)
        }
    }
    
    private func configureAuthStateChanges() {
        authStateHandler = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.user = user
                self?.isAuthenticated = user != nil
            }
        }
    }
    
    // MARK: - Sign Up
    func signUp(email: String, password: String, username: String) async throws {
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            
            // Update display name
            let changeRequest = result.user.createProfileChangeRequest()
            changeRequest.displayName = username
            try await changeRequest.commitChanges()
            
            self.user = result.user
            self.isAuthenticated = true
            self.errorMessage = nil
        } catch {
            self.errorMessage = Self.friendlyMessage(for: error)
            throw error
        }
    }
    
    // MARK: - Sign In
    func signIn(email: String, password: String) async throws {
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            self.user = result.user
            self.isAuthenticated = true
            self.errorMessage = nil
        } catch {
            self.errorMessage = Self.friendlyMessage(for: error)
            throw error
        }
    }
    
    // MARK: - Sign Out
    func signOut() throws {
        do {
            try Auth.auth().signOut()
            self.user = nil
            self.isAuthenticated = false
            self.errorMessage = nil
        } catch {
            self.errorMessage = Self.friendlyMessage(for: error)
            throw error
        }
    }
    
    // MARK: - Password Reset
    func resetPassword(email: String) async throws {
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
            self.errorMessage = nil
        } catch {
            self.errorMessage = Self.friendlyMessage(for: error)
            throw error
        }
    }
    
    // MARK: - Delete Account
    func deleteAccount() async throws {
        guard let user = Auth.auth().currentUser else {
            throw NSError(domain: "AuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user logged in"])
        }
        
        do {
            try await user.delete()
            self.user = nil
            self.isAuthenticated = false
            self.errorMessage = nil
        } catch {
            self.errorMessage = Self.friendlyMessage(for: error)
            throw error
        }
    }
}
