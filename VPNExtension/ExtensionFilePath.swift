import Foundation

enum ExtensionFilePath {
    static let groupIdentifier = "group.com.freecity.vpn"

    static var sharedDirectory: URL {
        guard let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupIdentifier) else {
            return FileManager.default.temporaryDirectory
        }
        return url
    }

    static var cacheDirectory: URL {
        sharedDirectory.appendingPathComponent("Library/Caches", isDirectory: true)
    }

    static var workingDirectory: URL {
        cacheDirectory.appendingPathComponent("Working", isDirectory: true)
    }
}

extension URL {
    var relativePath: String { path }
}
