import Foundation
import NetworkExtension

class VlessManager: ObservableObject {
    static let shared = VlessManager()
    private var providerManager: NETunnelProviderManager?
    private var statusObserver: NSObjectProtocol?

    @Published private(set) var isConfigLoaded = false
    @Published private(set) var connectionStatus: NEVPNStatus = .invalid

    private init() {
        loadProviderManager()
    }

    public func loadProviderManager() {
        loadProviderManager(retryCount: 0)
    }

    private func loadProviderManager(retryCount: Int) {
        let maxRetries = 2
        NETunnelProviderManager.loadAllFromPreferences { [weak self] (managers, error) in
            guard let self = self else { return }
            if let error = error {
                print("Error: load VPN config: \(error.localizedDescription)")
                if (error as NSError).localizedDescription.contains("IPC") && retryCount < maxRetries {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                        self?.loadProviderManager(retryCount: retryCount + 1)
                    }
                    return
                }
                DispatchQueue.main.async {
                    let manager = NETunnelProviderManager()
                    self.providerManager = manager
                    self.connectionStatus = manager.connection.status
                    self.isConfigLoaded = true
                    self.observeVPNStatus(connection: manager.connection)
                }
                return
            }

            if let managers = managers {
                print("Loaded \(managers.count) VPN configs.")
            } else {
                print("No VPN configs found.")
            }

            let manager: NETunnelProviderManager
            if let existingManager = managers?.first {
                manager = existingManager
                print("VPN config exists")
            } else {
                manager = NETunnelProviderManager()
                print("Creating new VPN config")
                self.setupVPNConfiguration(manager, withURL: "vless://")
            }

            self.providerManager = manager
            DispatchQueue.main.async {
                self.connectionStatus = manager.connection.status
                self.isConfigLoaded = true
                self.observeVPNStatus(connection: manager.connection)
            }
        }
    }

    private func observeVPNStatus(connection: NEVPNConnection) {
        if let observer = statusObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        statusObserver = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange,
            object: connection,
            queue: .main
        ) { [weak self] _ in
            self?.connectionStatus = self?.providerManager?.connection.status ?? .invalid
        }
    }

    private func setupVPNConfiguration(_ manager: NETunnelProviderManager, withURL vlessURL: String) {
        guard let config = VlessConf.createConfiguration(from: vlessURL) else {
            print("Error: creating VPN config")
            return
        }

        let tunnelProtocol = VlessConf.configureTunnelProtocol(with: config)
        manager.protocolConfiguration = tunnelProtocol
        manager.localizedDescription = VlessConst.vpnDescription
        manager.isEnabled = true

        saveConfiguration(manager)
    }

    func startVPN(withURL vlessURL: String) {
        guard let manager = providerManager else {
            print("VPN not configured")
            return
        }

        setupVPNConfiguration(manager, withURL: vlessURL)

        do {
            try manager.connection.startVPNTunnel()
            print("VPN ON!")
        } catch {
            print("Error: VPN Starting: \(error.localizedDescription)")
        }
    }

    func stopVPN() {
        providerManager?.connection.stopVPNTunnel()
        print("VPN off")
    }

    private func saveConfiguration(_ manager: NETunnelProviderManager) {
        print("Save config...")
        manager.saveToPreferences { [weak self] error in
            if let error = error {
                print("Error: save config: \(error.localizedDescription)")
                return
            }
            print("VPN config saved")
            self?.reloadConfiguration()
        }
    }

    private func reloadConfiguration() {
        NETunnelProviderManager.loadAllFromPreferences { [weak self] managers, error in
            guard let self = self else { return }
            if let error = error {
                print("Error: reloading configuration: \(error.localizedDescription)")
                return
            }
            if let updatedManager = managers?.first {
                self.providerManager = updatedManager
                DispatchQueue.main.async {
                    self.connectionStatus = updatedManager.connection.status
                    self.observeVPNStatus(connection: updatedManager.connection)
                }
                print("VPN config updated")
            }
        }
    }
}
