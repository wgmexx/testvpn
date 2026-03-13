import Foundation

struct VlessModel {
    let id: String
    let host: String
    let port: Int
    let security: String
    let type: String
    let flow: String?
    let sni: String?
    let fingerprint: String?
    let publicKey: String?
    /// Путь для WebSocket (query-параметр path)
    let path: String?
    /// Host-заголовок для WebSocket (query-параметр host)
    let hostHeader: String?

    init?(from urlString: String) {
        guard let url = URLComponents(string: urlString),
              let user = url.user,
              let host = url.host,
              let port = url.port else {
            print("Error: Invalid URL format")
            return nil
        }

        let queryItems = url.queryItems ?? []
        
        self.id = user
        self.host = host
        self.port = port
        self.security = queryItems.first(where: { $0.name == "security" })?.value ?? "none"
        self.type = queryItems.first(where: { $0.name == "type" })?.value ?? "tcp"
        self.flow = queryItems.first(where: { $0.name == "flow" })?.value
        self.sni = queryItems.first(where: { $0.name == "sni" })?.value
        self.fingerprint = queryItems.first(where: { $0.name == "fp" })?.value
        self.publicKey = queryItems.first(where: { $0.name == "pbk" })?.value
        self.path = queryItems.first(where: { $0.name == "path" })?.value
        self.hostHeader = queryItems.first(where: { $0.name == "host" })?.value

        if self.security == "none" {
            print("Warning: 'security' parameter not found, using default 'none'")
        }
        if self.type == "tcp" {
            print("Warning: 'type' parameter not found, using default 'tcp'")
        }
    }
}
