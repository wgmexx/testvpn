import Foundation
import NetworkExtension

class VlessConf {
    static func createConfiguration(from vlessURL: String) -> VlessModel? {
        guard let vlessConfig = VlessModel(from: vlessURL) else {
            print("Error: VLESS-parsing")
            return nil
        }
        return vlessConfig
    }

    static func configureTunnelProtocol(with config: VlessModel) -> NETunnelProviderProtocol {
        let tunnelProtocol = NETunnelProviderProtocol()
        tunnelProtocol.providerBundleIdentifier = VlessConst.providerBundleIdentifier
        tunnelProtocol.serverAddress = config.host

        tunnelProtocol.providerConfiguration = [
            "UUID": config.id,
            "host": config.host,
            "port": config.port,
            "security": config.security,
            "type": config.type,
            "flow": config.flow ?? "",
            "sni": config.sni ?? "",
            "fingerprint": config.fingerprint ?? "",
            "publicKey": config.publicKey ?? "",
            "IPSettings": VlessConst.defaultIPSettings,
            "AlwaysOn": true,
            "OnDemandEnabled": true,
            "OnDemandRules": VlessConst.defaultOnDemandRules
        ]

        tunnelProtocol.disconnectOnSleep = false
        return tunnelProtocol
    }
}
