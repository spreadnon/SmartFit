import Foundation
import AuthenticationServices

class AuthService: NSObject {
    static let shared = AuthService()
    
    private let loginURL = URL(string: "http://10.108.2.95:8001/api/apple/login")!
    
    private var completion: ((Result<User, Error>) -> Void)?
    
    func startAppleLogin(completion: @escaping (Result<User, Error>) -> Void) {
        self.completion = completion
        
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }
    
    private func loginWithBackend(idToken: String, code: String?, name: String?, completion: @escaping (Result<User, Error>) -> Void) {
        var request = URLRequest(url: loginURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "id_token": idToken,
            "code": code ?? "",
            "name": name ?? ""
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let data = data else {
                    completion(.failure(NSError(domain: "AuthService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                    return
                }
                
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("Auth response JSON: \(jsonString)")
                }
                
                do {
                    // Try to decode as a wrapped response (common in your project)
                    struct WrappedLoginResponse: Codable {
                        let code: Int
                        let msg: String?
                        let data: User?
                    }
                    
                    let wrapped = try JSONDecoder().decode(WrappedLoginResponse.self, from: data)
                    if let user = wrapped.data {
                        completion(.success(user))
                    } else {
                        completion(.failure(NSError(domain: "AuthService", code: -4, userInfo: [NSLocalizedDescriptionKey: wrapped.msg ?? "Login failed without error message"])))
                    }
                } catch {
                    print("Decoding failed: \(error)")
                    completion(.failure(error))
                }
            }
        }.resume()
    }
}

extension AuthService: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            completion?(.failure(NSError(domain: "AuthService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid credential"])))
            return
        }
        
        guard let identityTokenData = appleIDCredential.identityToken,
              let identityToken = String(data: identityTokenData, encoding: .utf8) else {
            completion?(.failure(NSError(domain: "AuthService", code: -3, userInfo: [NSLocalizedDescriptionKey: "No identity token"])))
            return
        }
        
        let code = appleIDCredential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }
        let name = [appleIDCredential.fullName?.givenName, appleIDCredential.fullName?.familyName]
            .compactMap { $0 }
            .joined(separator: " ")
        
        loginWithBackend(idToken: identityToken, code: code, name: name.isEmpty ? nil : name) { result in
            self.completion?(result)
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        completion?(.failure(error))
    }
}

extension AuthService: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return UIWindow()
        }
        return window
    }
}
