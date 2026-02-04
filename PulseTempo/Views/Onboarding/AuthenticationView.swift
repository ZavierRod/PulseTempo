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
    @State private var animateGradient = false
    
    private enum Field {
        case email, password, confirmPassword, firstName, lastName
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Animated gradient background (matching WelcomeView)
            LinearGradient(
                colors: [
                    Color(red: 0.1, green: 0.1, blue: 0.2),
                    Color(red: 0.2, green: 0.1, blue: 0.3),
                    Color(red: 0.1, green: 0.2, blue: 0.3)
                ],
                startPoint: animateGradient ? .topLeading : .bottomLeading,
                endPoint: animateGradient ? .bottomTrailing : .topTrailing
            )
            .ignoresSafeArea()
            .onAppear {
                withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                    animateGradient = true
                }
            }
            
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
        }
    }
    
    // MARK: - Subviews
    
    private var header: some View {
        HStack {
            if let onBack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.bebasNeueSubheadline)
                        .foregroundColor(.white)
                }
            }
            
            Spacer()
            
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.pink, Color.purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 70, height: 70)
                    .shadow(color: Color.pink.opacity(0.5), radius: 15, x: 0, y: 8)
                
                Image(systemName: "person.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.white)
            }
            
            Spacer()
            
            if onBack != nil {
                Color.clear
                    .frame(width: 44, height: 44)
            }
        }
    }
    
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(mode == .signUp ? "Create Account" : "Welcome Back")
                .font(.bebasNeueMedium)
                .foregroundColor(.white)
            
            Text(mode == .signUp
                 ? "Sign up to save your workout history and sync across devices."
                 : "Log in to access your workout history.")
                .font(.bebasNeueSubheadline)
                .foregroundColor(.white.opacity(0.7))
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
                .font(.bebasNeueCaption)
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
                        .font(.bebasNeueBody)
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
                .font(.bebasNeueCaption)
                .foregroundColor(.white.opacity(0.6))
            
            Button(action: toggleMode) {
                Text(mode == .signUp ? "Log In" : "Sign Up")
                    .font(.bebasNeueCaption)
                    .foregroundColor(.pink)
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
                // Call onAuthenticated directly after successful auth
                await MainActor.run {
                    onAuthenticated()
                }
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
                    .foregroundColor(.white.opacity(0.5))
                    .frame(width: 20)
            }
            
            TextField(placeholder, text: $text, prompt: Text(placeholder).foregroundColor(.white.opacity(0.4)))
                .keyboardType(keyboardType)
                .textContentType(textContentType)
                .textInputAutocapitalization(autocapitalization)
                .autocorrectionDisabled()
                .foregroundColor(.white)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.1))
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
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
                .foregroundColor(.white.opacity(0.5))
                .frame(width: 20)
            
            if showPassword {
                TextField(placeholder, text: $text, prompt: Text(placeholder).foregroundColor(.white.opacity(0.4)))
                    .textContentType(.password)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .foregroundColor(.white)
            } else {
                SecureField(placeholder, text: $text, prompt: Text(placeholder).foregroundColor(.white.opacity(0.4)))
                    .textContentType(.password)
                    .foregroundColor(.white)
            }
            
            Button(action: { showPassword.toggle() }) {
                Image(systemName: showPassword ? "eye.slash" : "eye")
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.1))
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
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
