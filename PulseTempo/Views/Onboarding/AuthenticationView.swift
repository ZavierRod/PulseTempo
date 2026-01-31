//
//  AuthenticationView.swift
//  PulseTempo
//
//  Created by Zavier Rodrigues on 1/28/26.
//

import SwiftUI

/// Authentication mode - sign up or log in
enum AuthenticationMode {
    case signUp
    case logIn
}

/// Onboarding step that handles user authentication with email/password
struct AuthenticationView: View {
    
    // MARK: - Callbacks
    
    /// Called when authentication succeeds
    var onAuthenticated: () -> Void
    
    /// Optional callback when the user wants to go back
    var onBack: (() -> Void)?
    
    // MARK: - State
    
    @StateObject private var authService = AuthService.shared
    
    @State private var mode: AuthenticationMode = .signUp
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var showPassword: Bool = false
    @State private var localError: String?
    
    @FocusState private var focusedField: Field?
    
    private enum Field {
        case email, password, confirmPassword, firstName, lastName
    }
    
    // MARK: - Body
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header
                
                titleSection
                
                formFields
                
                if let error = authService.errorMessage ?? localError {
                    errorView(message: error)
                }
                
                actionButtons
                
                modeToggle
                
                Spacer(minLength: 40)
            }
            .padding(24)
        }
        .background(Color(.systemBackground))
        .onChange(of: authService.isAuthenticated) { isAuthenticated in
            if isAuthenticated {
                onAuthenticated()
            }
        }
    }
    
    // MARK: - Subviews
    
    private var header: some View {
        HStack {
            if let onBack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            
            Spacer()
            
            Image(systemName: "person.circle.fill")
                .font(.system(size: 28))
                .foregroundColor(.accentColor)
            
            Spacer()
            
            if onBack != nil {
                // Keep layout balanced
                Color.clear
                    .frame(width: 44, height: 44)
            }
        }
    }
    
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(mode == .signUp ? "Create Account" : "Welcome Back")
                .font(.system(size: 28, weight: .bold, design: .rounded))
            
            Text(mode == .signUp
                 ? "Sign up to save your workout history and sync across devices."
                 : "Log in to access your workout history.")
                .font(.system(size: 16))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var formFields: some View {
        VStack(spacing: 16) {
            // Name fields (sign up only)
            if mode == .signUp {
                HStack(spacing: 12) {
                    CustomTextField(
                        placeholder: "First name",
                        text: $firstName,
                        icon: "person",
                        keyboardType: .default,
                        textContentType: .givenName
                    )
                    .focused($focusedField, equals: .firstName)
                    
                    CustomTextField(
                        placeholder: "Last name",
                        text: $lastName,
                        icon: nil,
                        keyboardType: .default,
                        textContentType: .familyName
                    )
                    .focused($focusedField, equals: .lastName)
                }
            }
            
            // Email field
            CustomTextField(
                placeholder: "Email",
                text: $email,
                icon: "envelope",
                keyboardType: .emailAddress,
                textContentType: .emailAddress,
                autocapitalization: .never
            )
            .focused($focusedField, equals: .email)
            
            // Password field
            CustomSecureField(
                placeholder: "Password",
                text: $password,
                showPassword: $showPassword,
                icon: "lock"
            )
            .focused($focusedField, equals: .password)
            
            // Confirm password (sign up only)
            if mode == .signUp {
                CustomSecureField(
                    placeholder: "Confirm password",
                    text: $confirmPassword,
                    showPassword: $showPassword,
                    icon: "lock.fill"
                )
                .focused($focusedField, equals: .confirmPassword)
            }
        }
    }
    
    private func errorView(message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            
            Text(message)
                .font(.system(size: 14))
                .foregroundColor(.red)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.red.opacity(0.1))
        )
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Primary action button
            Button(action: performAction) {
                HStack {
                    if authService.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }
                    
                    Text(mode == .signUp ? "Sign Up" : "Log In")
                        .font(.system(size: 18, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    isFormValid
                        ? LinearGradient(
                            colors: [Color.pink, Color.purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        : LinearGradient(
                            colors: [Color.gray, Color.gray],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                )
                .cornerRadius(16)
            }
            .disabled(!isFormValid || authService.isLoading)
        }
    }
    
    private var modeToggle: some View {
        HStack(spacing: 4) {
            Text(mode == .signUp ? "Already have an account?" : "Don't have an account?")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            
            Button(action: toggleMode) {
                Text(mode == .signUp ? "Log In" : "Sign Up")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.accentColor)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var isFormValid: Bool {
        let emailValid = !email.isEmpty && email.contains("@")
        let passwordValid = password.count >= 6
        
        if mode == .signUp {
            let passwordsMatch = password == confirmPassword
            return emailValid && passwordValid && passwordsMatch
        } else {
            return emailValid && passwordValid
        }
    }
    
    // MARK: - Actions
    
    private func performAction() {
        focusedField = nil
        localError = nil
        authService.clearError()
        
        // Validate
        if mode == .signUp && password != confirmPassword {
            localError = "Passwords don't match"
            return
        }
        
        if password.count < 6 {
            localError = "Password must be at least 6 characters"
            return
        }
        
        // Perform auth
        Task {
            do {
                if mode == .signUp {
                    try await authService.register(
                        email: email,
                        password: password,
                        firstName: firstName.isEmpty ? nil : firstName,
                        lastName: lastName.isEmpty ? nil : lastName
                    )
                } else {
                    try await authService.login(email: email, password: password)
                }
                // onAuthenticated will be called via onChange when isAuthenticated becomes true
            } catch {
                // Error is already set in authService.errorMessage
            }
        }
    }
    
    private func toggleMode() {
        withAnimation(.easeInOut(duration: 0.2)) {
            mode = mode == .signUp ? .logIn : .signUp
            localError = nil
            authService.clearError()
        }
    }
}

// MARK: - Custom Text Field

struct CustomTextField: View {
    let placeholder: String
    @Binding var text: String
    let icon: String?
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType?
    var autocapitalization: TextInputAutocapitalization = .sentences
    
    var body: some View {
        HStack(spacing: 12) {
            if let icon {
                Image(systemName: icon)
                    .foregroundColor(.secondary)
                    .frame(width: 20)
            }
            
            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .textContentType(textContentType)
                .textInputAutocapitalization(autocapitalization)
                .autocorrectionDisabled()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

// MARK: - Custom Secure Field

struct CustomSecureField: View {
    let placeholder: String
    @Binding var text: String
    @Binding var showPassword: Bool
    let icon: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 20)
            
            if showPassword {
                TextField(placeholder, text: $text)
                    .textContentType(.password)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            } else {
                SecureField(placeholder, text: $text)
                    .textContentType(.password)
            }
            
            Button(action: { showPassword.toggle() }) {
                Image(systemName: showPassword ? "eye.slash" : "eye")
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

// MARK: - Preview

#if DEBUG
struct AuthenticationView_Previews: PreviewProvider {
    static var previews: some View {
        AuthenticationView(
            onAuthenticated: { print("Authenticated!") },
            onBack: { print("Back tapped") }
        )
    }
}
#endif
