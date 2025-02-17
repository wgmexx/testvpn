import Foundation
import NetworkExtension

class VlessManager {
    static let shared = VlessManager()
    private var providerManager: NETunnelProviderManager?

    private init() {
        loadProviderManager()
    }

    public func loadProviderManager() {
        NETunnelProviderManager.loadAllFromPreferences { [weak self] (managers, error) in
            if let error = error {
                print("Error: load VPN config: \(error.localizedDescription)")
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
                self?.setupVPNConfiguration(manager, withURL: "vless://")
            }

            self?.providerManager = manager
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
            if let error = error {
                print("Error: reloading configuration: \(error.localizedDescription)")
                return
            }

            if let updatedManager = managers?.first {
                self?.providerManager = updatedManager
                print("VPN config updated")
            }
        }
    }
}
