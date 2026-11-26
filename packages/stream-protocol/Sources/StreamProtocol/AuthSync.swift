import CryptoKit
import Foundation
import Security

/// Wire payload sent from DuoDeck iOS/iPadOS to DuoDeck Host on macOS (kind 45)
/// so an already-authenticated mobile user seamlessly authenticates the Mac without manual re-login.
public struct AuthSyncMessage: Codable, Sendable, Equatable {
    public enum Action: String, Codable, Sendable {
        case handoff
        case refresh
        case signOut
    }

    public var version: Int
    public var action: Action
    public var handoffCode: String?
    public var userId: String?
    public var email: String?
    public var tier: String?
    public var authBaseURL: String?

    public init(
        version: Int = 1,
        action: Action,
        handoffCode: String? = nil,
        userId: String? = nil,
        email: String? = nil,
        tier: String? = nil,
        authBaseURL: String? = nil
    ) {
        self.version = version
        self.action = action
        self.handoffCode = handoffCode
        self.userId = userId
        self.email = email
        self.tier = tier
        self.authBaseURL = authBaseURL
    }
}

public struct MegawebsUser: Codable, Sendable, Equatable {
    public var id: String
    public var email: String
    public var name: String
    public var emailVerified: Bool
}

public struct MegawebsAppEntitlement: Codable, Sendable, Equatable {
    public var appId: String
    public var appName: String
    public var tier: String
    public var isPro: Bool
    public var status: String
    public var source: String?
    public var planSku: String?
    public var expiresAt: String?
    public var features: [String: Bool]
}

public struct MegawebsMeResponse: Codable, Sendable, Equatable {
    public var authenticated: Bool
    public var user: MegawebsUser?
    public var app: MegawebsAppEntitlement?
}

public struct MegawebsTokenResponse: Codable, Sendable, Equatable {
    public var accessToken: String
    public var expiresAt: String
    public var user: MegawebsUser
    public var app: MegawebsAppEntitlement
}

public struct MegawebsHandoffResponse: Codable, Sendable, Equatable {
    public var code: String
    public var expiresAt: String
}

public struct MegawebsAccountState: Sendable, Equatable {
    public var user: MegawebsUser
    public var entitlement: MegawebsAppEntitlement

    public var isPro: Bool { entitlement.isPro }
    public var tierLabel: String { entitlement.isPro ? "DuoDeck Pro" : "Free" }

    public func hasFeature(_ key: String) -> Bool {
        entitlement.features[key] ?? false
    }

    public init(user: MegawebsUser, entitlement: MegawebsAppEntitlement) {
        self.user = user
        self.entitlement = entitlement
    }
}

/// Lightweight, zero-dependency client for auth.megawebs.com (PKCE, /v1/me, Mac device handoff, Keychain).
public enum MegawebsAuthClient {
    public static let defaultBaseURL = URL(string: "https://auth.megawebs.com")!
    public static let appID = "duodeck"
    public static let redirectURI = "duodeck://auth"

    public struct PKCEPair: Sendable {
        public let verifier: String
        public let challenge: String
        public let state: String
    }

    public static func makePKCE() -> PKCEPair {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        let verifier = Base64URL.encode(Data(bytes))
        let digest = SHA256.hash(data: Data(verifier.utf8))
        let challenge = Base64URL.encode(Data(digest))
        var stateBytes = [UInt8](repeating: 0, count: 16)
        _ = SecRandomCopyBytes(kSecRandomDefault, stateBytes.count, &stateBytes)
        let state = Base64URL.encode(Data(stateBytes))
        return PKCEPair(verifier: verifier, challenge: challenge, state: state)
    }

    public static func authorizeURL(baseURL: URL = defaultBaseURL, pkce: PKCEPair) -> URL {
        var components = URLComponents(url: baseURL.appendingPathComponent("authorize"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "app", value: appID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "state", value: pkce.state),
            URLQueryItem(name: "code_challenge", value: pkce.challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
        ]
        return components.url!
    }

    public static func exchangeOAuthCode(
        baseURL: URL = defaultBaseURL,
        code: String,
        verifier: String
    ) async throws -> MegawebsTokenResponse {
        let body: [String: String] = [
            "code": code,
            "appId": appID,
            "redirectUri": redirectURI,
            "codeVerifier": verifier,
        ]
        return try await postJSON(url: baseURL.appendingPathComponent("v1/oauth/token"), body: body, token: nil)
    }

    public static func fetchMe(
        baseURL: URL = defaultBaseURL,
        token: String
    ) async throws -> MegawebsMeResponse {
        var components = URLComponents(url: baseURL.appendingPathComponent("v1/me"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "app", value: appID)]
        var req = URLRequest(url: components.url!)
        req.httpMethod = "GET"
        req.timeoutInterval = 10
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw AuthClientError.httpStatus((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        return try JSONDecoder().decode(MegawebsMeResponse.self, from: data)
    }

    public static func createDeviceHandoff(
        baseURL: URL = defaultBaseURL,
        token: String,
        sourcePlatform: String,
        targetPlatform: String,
        targetDeviceId: String?
    ) async throws -> MegawebsHandoffResponse {
        var body: [String: String] = [
            "appId": appID,
            "sourcePlatform": sourcePlatform,
            "targetPlatform": targetPlatform,
        ]
        if let targetDeviceId, !targetDeviceId.isEmpty {
            body["targetDeviceId"] = targetDeviceId
        }
        return try await postJSON(url: baseURL.appendingPathComponent("v1/device-handoff"), body: body, token: token)
    }

    public static func exchangeDeviceHandoff(
        baseURL: URL = defaultBaseURL,
        code: String,
        deviceId: String,
        deviceName: String,
        platform: String,
        fingerprint: String?
    ) async throws -> MegawebsTokenResponse {
        var body: [String: String] = [
            "code": code,
            "appId": appID,
            "deviceId": deviceId,
            "deviceName": deviceName,
            "platform": platform,
        ]
        if let fingerprint, !fingerprint.isEmpty {
            body["fingerprint"] = fingerprint
        }
        return try await postJSON(url: baseURL.appendingPathComponent("v1/device-handoff/exchange"), body: body, token: nil)
    }

    public static func signOut(baseURL: URL = defaultBaseURL, token: String) async {
        var req = URLRequest(url: baseURL.appendingPathComponent("api/auth/sign-out"))
        req.httpMethod = "POST"
        req.timeoutInterval = 6
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = Data("{}".utf8)
        _ = try? await URLSession.shared.data(for: req)
    }

    private static func postJSON<T: Decodable>(url: URL, body: [String: String], token: String?) async throws -> T {
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 10
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        req.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw AuthClientError.httpStatus((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    public enum AuthClientError: Error {
        case httpStatus(Int)
    }

    // MARK: Keychain token storage

    public static func loadToken(service: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "megawebs_session_token",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let token = String(data: data, encoding: .utf8),
              !token.isEmpty else {
            return nil
        }
        return token
    }

    public static func saveToken(_ token: String, service: String) {
        let data = Data(token.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "megawebs_session_token",
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(add as CFDictionary, nil)
    }

    public static func deleteToken(service: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "megawebs_session_token",
        ]
        SecItemDelete(query as CFDictionary)
    }
}
