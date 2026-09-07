import Foundation
import UIKit

/// Credentials for the KeyAuth application (https://keyauth.cc).
/// Create an application in the KeyAuth panel to get the app name and owner ID.
struct KeyAuthConfiguration {
    let appName: String
    let ownerID: String
    let version: String
    let apiURL: URL
    static let shared = KeyAuthConfiguration(
        appName: "moonexternal",
        ownerID: "SQc5dKoope",
        version: "1.0",
        apiURL: URL(string: "https://keyauth.win/api/1.2/")!
    )

    static var isConfigured: Bool {
        let config = KeyAuthConfiguration.shared
        return !config.appName.contains("YOUR_APP_NAME")
            && !config.ownerID.contains("YOUR_OWNER_ID")
            && config.ownerID.count == 10
    }
}

enum KeyAuthError: LocalizedError {
    case notConfigured
    case invalidResponse
    case server(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "KeyAuth app name or owner ID is not configured."
        case .invalidResponse:
            return "KeyAuth returned an invalid response."
        case .server(let message):
            return message
        }
    }
}

/// Client for the KeyAuth v1.2 API (https://keyauth.cc).
///
/// Flow: `init` first (validates the app and returns a session ID), then
/// `login` or `register` with the device HWID. Successful responses carry the
/// user profile and license expiry, which the app stores locally so the
/// session can be restored without prompting every launch.
final class KeyAuthClient: MoonPlaceSessionBackend {
    private let configuration: KeyAuthConfiguration
    private var sessionID = ""

    private static let profileKey = "keyauth.session.profile.v1"

    init(configuration: KeyAuthConfiguration = .shared) {
        self.configuration = configuration
    }

    // MARK: MoonPlaceSessionBackend

    func login(username: String, password: String, key: String) async throws -> MoonPlaceAuthenticationResult {
        try await ensureInitialized()
        let object = try await request([
            "type": "login",
            "username": username,
            "pass": password,
            "hwid": Self.hwid,
            "sessionid": sessionID,
            "name": configuration.appName,
            "ownerid": configuration.ownerID
        ])
        let result = try Self.authenticationResult(from: object)
        Self.persistProfile(result)
        return result
    }

    func register(username: String, password: String, key: String, phone: String) async throws -> MoonPlaceAuthenticationResult {
        try await ensureInitialized()
        let object = try await request([
            "type": "register",
            "username": username,
            "pass": password,
            "key": key,
            "hwid": Self.hwid,
            "sessionid": sessionID,
            "name": configuration.appName,
            "ownerid": configuration.ownerID
        ])
        let result = try Self.authenticationResult(from: object)
        Self.persistProfile(result)
        return result
    }

    func cachedProfile() -> MoonPlaceStoredProfile? {
        guard let data = UserDefaults.standard.data(forKey: Self.profileKey) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(MoonPlaceStoredProfile.self, from: data)
    }

    func restoreSession() async -> MoonPlaceAuthenticationResult? {
        guard let profile = cachedProfile() else { return nil }
        if let expiresAt = profile.expiresAt, expiresAt <= Date() {
            signOut(username: profile.username)
            return nil
        }
        return MoonPlaceAuthenticationResult(
            username: profile.username,
            phone: profile.phone,
            expiresAt: profile.expiresAt
        )
    }

    func signOut(username: String) {
        UserDefaults.standard.removeObject(forKey: Self.profileKey)
    }

    // MARK: KeyAuth API

    private func ensureInitialized() async throws {
        guard configuration.apiURL.scheme == "https" else {
            throw KeyAuthError.server(
                "The KeyAuth API URL must use https:// (current value: \(configuration.apiURL.absoluteString))."
            )
        }
        guard sessionID.isEmpty else { return }
        let object = try await request([
            "type": "init",
            "ver": configuration.version,
            "hash": "",
            "name": configuration.appName,
            "ownerid": configuration.ownerID
        ])
        guard let sid = object["sessionid"] as? String, !sid.isEmpty else {
            throw KeyAuthError.server(object["message"] as? String ?? "KeyAuth initialization failed.")
        }
        sessionID = sid
    }
    private func request(_ params: [String: String]) async throws -> [String: Any] {
        guard KeyAuthConfiguration.isConfigured else { throw KeyAuthError.notConfigured }

        var components = URLComponents(url: configuration.apiURL, resolvingAgainstBaseURL: false)
        components?.queryItems = params
            .sorted { $0.key < $1.key }
            .map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let endpoint = components?.url else { throw KeyAuthError.invalidResponse }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = components?.query?.data(using: .utf8)

        let sessionConfiguration = URLSessionConfiguration.ephemeral
        sessionConfiguration.timeoutIntervalForRequest = 30
        sessionConfiguration.timeoutIntervalForResource = 60
        let session = URLSession(configuration: sessionConfiguration)
        defer { session.invalidateAndCancel() }

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw KeyAuthError.invalidResponse
            }
            let bodyText = String(data: data, encoding: .utf8) ?? ""
            let bodyObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard (200..<300).contains(httpResponse.statusCode), let object = bodyObject else {
                if bodyText.trimmingCharacters(in: .whitespacesAndNewlines) == "KeyAuth_Invalid" {
                    throw KeyAuthError.server(
                        "The KeyAuth application does not exist. Check the app name and owner ID in KeyAuthConfiguration."
                    )
                }
                throw KeyAuthError.invalidResponse
            }
            guard let success = object["success"] as? Bool else {
                throw KeyAuthError.invalidResponse
            }
            guard success else {
                throw KeyAuthError.server(object["message"] as? String ?? "KeyAuth failed.")
            }
            return object
        } catch let error as URLError {
            let host = request.url?.host ?? "keyauth.win"
            log("keyauth: transport error \(error.code.rawValue) — \(error.localizedDescription) (\(host))")
            switch error.code {
            case .secureConnectionFailed:
                throw KeyAuthError.server("Secure connection to \(host) failed (TLS).")
            case .notConnectedToInternet:
                throw KeyAuthError.server("There is no Internet connection.")
            case .timedOut:
                throw KeyAuthError.server("The connection to \(host) timed out. Try again.")
            case .appTransportSecurityRequiresSecureConnection:
                throw KeyAuthError.server("The connection to \(host) was blocked: the KeyAuth API URL must use https://.")
            default:
                throw KeyAuthError.server("Could not connect to \(host): \(error.localizedDescription).")
            }
        }
    }
    // MARK: Helpers

    private static func authenticationResult(from object: [String: Any]) throws -> MoonPlaceAuthenticationResult {
        guard let info = object["info"] as? [String: Any] else {
            throw KeyAuthError.invalidResponse
        }
        let username = info["username"] as? String ?? ""
        guard !username.isEmpty else { throw KeyAuthError.invalidResponse }

        let subscriptions = info["subscriptions"] as? [[String: Any]]
        let phone = subscriptions?.first?["subscription"] as? String ?? ""
        var expiresAt: Date?
        if let expiry = subscriptions?.first?["expiry"] {
            let timestamp = (expiry as? NSNumber)?.doubleValue ?? Double(expiry as? String ?? "") ?? 0
            if timestamp > 0 {
                expiresAt = Date(timeIntervalSince1970: timestamp)
            }
        }
        return MoonPlaceAuthenticationResult(username: username, phone: phone, expiresAt: expiresAt)
    }

    private static func persistProfile(_ result: MoonPlaceAuthenticationResult) {
        let profile = MoonPlaceStoredProfile(
            username: result.username,
            phone: result.phone,
            expiresAt: result.expiresAt
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(profile) else { return }
        UserDefaults.standard.set(data, forKey: profileKey)
    }

    /// Stable per-device identifier used as the KeyAuth HWID.
    private static var hwid: String {
        if let id = UIDevice.current.identifierForVendor?.uuidString {
            return id
        }
        let raw = "\(UIDevice.current.name)-\(ProcessInfo.processInfo.hostName)"
        return String(raw.replacingOccurrences(of: " ", with: "-").lowercased().prefix(32))
    }
}