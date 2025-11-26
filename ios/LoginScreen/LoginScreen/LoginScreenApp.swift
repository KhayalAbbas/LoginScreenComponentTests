import SwiftUI

@main
struct LoginScreenApp: App {
    var body: some Scene {
        WindowGroup {
            LoginView(
                viewModel: LoginViewModel(
                    authService: AuthService(),
                    networkMonitor: NetworkMonitor(),
                    tokenStorage: TokenStorage()
                ),
                onNavigateToHome: {
                    // Handle navigation to home screen
                }
            )
        }
    }
}

