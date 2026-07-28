import Foundation

struct ActivationDeepLink: Equatable {
    static let scheme = "cmdtab"
    static let host = "activate"
    static let maximumCodeLength = 4_096

    let activationCode: String

    static func parse(_ url: URL) -> ActivationDeepLink? {
        guard url.scheme?.lowercased() == scheme,
              url.host?.lowercased() == host,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }

        let matchingItems = (components.queryItems ?? []).filter {
            $0.name == "code" || $0.name == "key"
        }
        guard matchingItems.count == 1,
              let rawValue = matchingItems[0].value else {
            return nil
        }

        let normalized = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)
        guard !normalized.isEmpty,
              normalized.count <= maximumCodeLength,
              isSupportedActivationCode(normalized) else {
            return nil
        }

        return ActivationDeepLink(activationCode: normalized)
    }

    static func makeURL(activationCode: String) -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.queryItems = [
            URLQueryItem(name: "code", value: activationCode)
        ]
        return components.url
    }

    private static func isSupportedActivationCode(_ value: String) -> Bool {
        if value.range(
            of: "^CMDTAB-ACT-[A-Za-z0-9_-]{43}$",
            options: .regularExpression
        ) != nil {
            return true
        }
        return value.range(
            of: "^CMDTAB1\\.[A-Za-z0-9_-]+\\.[A-Za-z0-9_-]+$",
            options: .regularExpression
        ) != nil
    }
}
