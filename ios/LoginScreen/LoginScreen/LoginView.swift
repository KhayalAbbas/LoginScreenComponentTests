import SwiftUI

/// SwiftUI view for the login screen.
/// Observes ViewModel state and displays login form with validation feedback.
struct LoginView: View {
    /// The ViewModel managing login state and logic
    @StateObject var viewModel: LoginViewModel
    /// Callback invoked when login succeeds and navigation should occur
    let onNavigateToHome: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Login")
                .font(.largeTitle)
                .padding(.bottom, 32)
            
            TextField("Username", text: Binding(
                get: { viewModel.state.username },
                set: { viewModel.updateUsername($0) }
            ))
            .textFieldStyle(.roundedBorder)
            .disabled(viewModel.state.isLockedOut || viewModel.state.isLoading)
            
            SecureField("Password", text: Binding(
                get: { viewModel.state.password },
                set: { viewModel.updatePassword($0) }
            ))
            .textFieldStyle(.roundedBorder)
            .disabled(viewModel.state.isLockedOut || viewModel.state.isLoading)
            
            Toggle("Remember me", isOn: Binding(
                get: { viewModel.state.rememberMe },
                set: { viewModel.updateRememberMe($0) }
            ))
            .disabled(viewModel.state.isLockedOut || viewModel.state.isLoading)
            
            if let errorMessage = viewModel.state.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            if viewModel.state.isOffline {
                Text("No internet connection")
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            if viewModel.state.isLockedOut {
                Text("Account locked. Too many failed attempts.")
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            Button(action: {
                viewModel.login()
            }) {
                if viewModel.state.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("Login")
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(viewModel.state.isButtonEnabled ? Color.blue : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(8)
            .disabled(!viewModel.state.isButtonEnabled)
        }
        .padding(16)
        .onChange(of: viewModel.state.navigationEvent) { oldValue, newValue in
            if case .navigateToHome = newValue {
                onNavigateToHome()
                viewModel.clearNavigationEvent()
            }
        }
    }
}

