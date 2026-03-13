import Foundation

/// Конвертирует VLESS URL (через `VlessModel`) в JSON-конфиг sing-box.
/// Результат можно записать в App Group и передать в extension с Libbox.
enum VlessToSingbox {

    /// Строит полный sing-box конфиг (tun inbound + vless outbound + route).
    /// Подходит для передачи в `LibboxNewService(configContent, ...)` после добавления Libbox в проект.
    static func buildConfig(from model: VlessModel) -> String? {
        let outbound = buildVlessOutbound(model)
        guard let outboundJson = outbound else { return nil }

        // Минимальный конфиг: tun inbound (Libbox может переопределить через platform), один outbound, маршрут.
        let config: [String: Any] = [
            "log": ["level": "info"],
            "dns": [
                "servers": [
                    ["address": "8.8.8.8", "detour": "proxy"],
                    ["address": "1.1.1.1", "detour": "proxy"]
                ],
                "strategy": "prefer_ipv4"
            ],
            "inbounds": [
                [
                    "type": "tun",
                    "tag": "tun-in",
                    "interface_name": "utun8",
                    "mtu": 9000,
                    "auto_route": true,
                    "strict_route": true,
                    "stack": "system",
                    "sniff": true,
                    "sniff_override_destination": true
                ]
            ],
            "outbounds": [
                outboundJson,
                ["type": "direct", "tag": "direct"],
                ["type": "dns", "tag": "dns-out"]
            ],
            "route": [
                "rules": [
                    ["outbound": "dns-out", "protocol": "dns"]
                ],
                "final": "proxy",
                "auto_detect_interface": true
            ]
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: config, options: [.sortedKeys, .prettyPrinted]),
              let str = String(data: data, encoding: .utf8) else { return nil }
        return str
    }

    /// Строит один outbound типа `vless` из `VlessModel`.
    static func buildVlessOutbound(_ model: VlessModel) -> [String: Any]? {
        let network = (model.type.lowercased() == "ws" ? "tcp" : model.type)
        var out: [String: Any] = [
            "type": "vless",
            "tag": "proxy",
            "server": model.host,
            "server_port": model.port,
            "uuid": model.id,
            "network": network
        ]

        if let flow = model.flow, !flow.isEmpty {
            out["flow"] = flow
        }

        // TLS
        if model.security.lowercased() == "tls" || model.security.lowercased() == "reality" {
            var tls: [String: Any] = ["enabled": true]
            if let sni = model.sni, !sni.isEmpty {
                tls["server_name"] = sni
            }
            if let fp = model.fingerprint, !fp.isEmpty {
                tls["fingerprint"] = fp
            }
            out["tls"] = tls
        }

        // Transport: ws, grpc, http и т.д.
        if model.type.lowercased() == "ws" {
            var transport: [String: Any] = ["type": "ws"]
            if let path = model.path, !path.isEmpty {
                transport["path"] = path
            }
            let wsHost = model.hostHeader ?? model.sni ?? model.host
            if !wsHost.isEmpty {
                transport["headers"] = ["Host": wsHost]
            }
            out["transport"] = transport
        }

        return out
    }

    /// Строит sing-box JSON из VLESS URL-строки (удобно вызывать из приложения).
    static func buildConfigFromVlessURL(_ vlessURL: String) -> String? {
        guard let model = VlessModel(from: vlessURL) else { return nil }
        return buildConfig(from: model)
    }
}
