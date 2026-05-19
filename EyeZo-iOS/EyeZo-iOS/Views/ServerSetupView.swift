import SwiftUI

struct ServerSetupView: View {
    @StateObject private var serverURLManager = ServerURLManager.shared
    @State private var urlInput = ""
    @State private var isValidating = false
    @State private var errorMessage: String?
    @State private var isConfigured = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Spacer()

                VStack(spacing: 16) {
                    // App icon/logo - add an image named "logo" to Assets.xcassets
                    // If you haven't added it yet, you'll see a placeholder
                    if let _ = UIImage(named: "logo") {
                        Image("logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 120, height: 120)
                            .cornerRadius(20)
                    } else {
                        // Fallback icon if logo not added yet
                        Image(systemName: "eye.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.blue)
                    }

                    Text("EyeZo")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Connect to your video server")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                VStack(spacing: 16) {
                    TextField("Server URL", text: $urlInput)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .keyboardType(.URL)
                        .padding(.horizontal, 40)
                        .onChange(of: urlInput) {
                            errorMessage = nil
                        }

                    Text("Example: http://127.0.0.1:3000")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal, 40)
                    }

                    Button(action: validateAndSave) {
                        HStack {
                            if isValidating {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Connect")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(urlInput.isEmpty || isValidating)
                    .padding(.horizontal, 40)
                }

                Spacer()
            }
            .navigationDestination(isPresented: $isConfigured) {
                DirectoryBrowserView()
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            // Pre-populate with current server URL if available, otherwise start with http://
            if urlInput.isEmpty {
                if let currentURL = serverURLManager.serverURL {
                    urlInput = currentURL.absoluteString
                } else {
                    urlInput = "http://"
                }
            }
        }
    }

    private func validateAndSave() {
        var urlString = urlInput.trimmingCharacters(in: .whitespaces)

        // Auto-add http:// if no scheme is provided
        if !urlString.lowercased().hasPrefix("http://") && !urlString.lowercased().hasPrefix("https://") {
            urlString = "http://" + urlString
        }

        // Remove trailing slash
        if urlString.hasSuffix("/") {
            urlString.removeLast()
        }

        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid URL format"
            return
        }

        isValidating = true
        errorMessage = nil

        Task {
            let isValid = await serverURLManager.validateServerURL(url)

            await MainActor.run {
                isValidating = false

                if isValid {
                    serverURLManager.saveServerURL(url)
                    isConfigured = true
                } else {
                    errorMessage = "Cannot connect to server. Please check the URL and try again."
                }
            }
        }
    }
}

struct ServerSetupView_Previews: PreviewProvider {
    static var previews: some View {
        ServerSetupView()
    }
}
