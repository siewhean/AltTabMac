import Foundation

enum FeedbackConfiguration {
    static let contactEmail = "tohsh17@gmail.com"

    static let reportBugURL = mailtoURL(
        subject: "CmdTab Bug Report",
        body: """
        What happened?

        Steps to reproduce:
        1.
        2.
        3.

        Expected result:

        Actual result:

        macOS version:
        CmdTab version:
        """
    )

    static let requestFeatureURL = mailtoURL(
        subject: "CmdTab Feature Request",
        body: """
        What would you like to change or add?

        Why would it help?

        Example workflow:
        """
    )

    private static func mailtoURL(subject: String, body: String) -> URL {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = contactEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body)
        ]
        return components.url!
    }
}
