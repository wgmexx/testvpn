import Foundation
import Libbox
import NetworkExtension

open class ExtensionProvider: NEPacketTunnelProvider {
    private var boxService: LibboxBoxService!
    private var platformInterface: ExtensionPlatformInterface!

    override open func startTunnel(options: [String: NSObject]?) async throws {
        LibboxClearServiceError()

        try? FileManager.default.createDirectory(at: ExtensionFilePath.cacheDirectory, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: ExtensionFilePath.workingDirectory, withIntermediateDirectories: true)

        let opts = LibboxSetupOptions()
        opts.basePath = ExtensionFilePath.sharedDirectory.path
        opts.workingPath = ExtensionFilePath.workingDirectory.path
        opts.tempPath = ExtensionFilePath.cacheDirectory.path

        var err: NSError?
        LibboxSetup(opts, &err)
        if let err {
            writeFatalError("(packet-tunnel) setup: \(err.localizedDescription)")
            return
        }

        let stderrPath = ExtensionFilePath.cacheDirectory.appendingPathComponent("stderr.log").path
        LibboxRedirectStderr(stderrPath, &err)
        if let err {
            writeFatalError("(packet-tunnel) redirect stderr: \(err.localizedDescription)")
            return
        }

        await LibboxSetMemoryLimit(false)

        if platformInterface == nil {
            platformInterface = ExtensionPlatformInterface(self)
        }
        writeMessage("(packet-tunnel) starting")
        await startService()
    }

    func writeMessage(_ message: String) {
        #if DEBUG
        NSLog("%@", message)
        #endif
    }

    public func writeFatalError(_ message: String) {
        #if DEBUG
        NSLog("%@", message)
        #endif
        var err: NSError?
        LibboxWriteServiceError(message, &err)
        cancelTunnelWithError(nil)
    }

    private func startService() async {
        guard let configContent = (protocolConfiguration as? NETunnelProviderProtocol)?.providerConfiguration?["config"] as? String,
              !configContent.isEmpty else {
            writeFatalError("(packet-tunnel) missing config in providerConfiguration")
            return
        }

        var err: NSError?
        let service = LibboxNewService(configContent, platformInterface, &err)
        if let err {
            writeFatalError("(packet-tunnel) create service: \(err.localizedDescription)")
            return
        }
        guard let service else {
            writeFatalError("(packet-tunnel) LibboxNewService returned nil")
            return
        }
        do {
            try service.start()
        } catch {
            writeFatalError("(packet-tunnel) start service: \(error.localizedDescription)")
            return
        }
        boxService = service
    }

    private func stopService() {
        if let service = boxService {
            do {
                try service.close()
            } catch {
                writeMessage("(packet-tunnel) stop error: \(error.localizedDescription)")
            }
            boxService = nil
        }
        platformInterface?.reset()
    }

    func reloadService() async {
        writeMessage("(packet-tunnel) reloading")
        reasserting = true
        defer { reasserting = false }
        stopService()
        await startService()
    }

    func postServiceClose() {
        boxService = nil
    }

    override open func stopTunnel(with reason: NEProviderStopReason) async {
        writeMessage("(packet-tunnel) stopping: \(reason)")
        stopService()
    }

    override open func sleep() async {
        boxService?.pause()
    }

    override open func wake() {
        boxService?.wake()
    }
}
