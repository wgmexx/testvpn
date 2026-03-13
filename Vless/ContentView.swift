import SwiftUI
import NetworkExtension
import UniformTypeIdentifiers

private enum VPNMode: String, CaseIterable, Identifiable {
    case vless
    case openvpn

    var id: String { rawValue }

    var title: String {
        switch self {
        case .vless: return "VLESS"
        case .openvpn: return "OpenVPN"
        }
    }
}

struct ContentView: View {
    @ObservedObject private var vlessManager = VlessManager.shared
    @ObservedObject private var openVPNManager = OpenVPNManager.shared

    @State private var vlessURL = "vless://iD--V2RAXX@fastlyipcloudflaretamiz.fast.hosting-ip.com:80/?type=ws&encryption=none&host=V2RAXX.IR&path=%2FTelegram%2CV2RAXX%2CTelegram%2CV2RAXX%3Fed%3D443#United States%20473%20/%20VlessKey.com%20/%20t.me/VlessVpnFree"

    @State private var mode: VPNMode = .vless

    @State private var showingOVPNPicker = false
    @State private var ovpnFileName: String?

    private var isConnected: Bool {
        switch mode {
        case .vless:
            return vlessManager.connectionStatus == .connected
        case .openvpn:
            return openVPNManager.connectionStatus == .connected
        }
    }

    var body: some View {
        ZStack {
            Color(isConnected ? .green.opacity(0.2) : .gray.opacity(0.2)).ignoresSafeArea(edges: .all)
            VStack(spacing: 16) {
                Picker("Режим VPN", selection: $mode) {
                    ForEach(VPNMode.allCases) { m in
                        Text(m.title).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                if mode == .vless {
                    // VLESS URL
                    TextEditor(text: $vlessURL)
                        .padding()
                        .cornerRadius(10)
                        .frame(height: 150)
                        .padding(.horizontal)
                } else {
                    // OpenVPN import
                    VStack(spacing: 8) {
                        Button {
                            showingOVPNPicker = true
                        } label: {
                            HStack {
                                Image(systemName: "doc.badge.plus")
                                Text("Импортировать OpenVPN (.ovpn)")
                            }
                            .font(.body.bold())
                            .padding(12)
                            .frame(maxWidth: .infinity)
                            .background(Color.blue.opacity(0.15))
                            .foregroundColor(.blue)
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }

                        if let name = ovpnFileName {
                            Text("Выбран файл: \(name)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                        } else if !openVPNManager.isConfigLoaded {
                            Text("Файл .ovpn не выбран")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                        }
                    }
                }

                // Connect button
                Button(action: connectOrDisconnect) {
                    Text(buttonTitle)
                        .font(.title)
                        .padding(20)
                        .frame(maxWidth: .infinity)
                        .background(buttonColor)
                        .foregroundColor(.white)
                        .cornerRadius(20)
                        .padding(.horizontal)
                }
                .disabled(connectDisabled)
            }
            .onAppear {
                VlessManager.shared.loadProviderManager()
                loadSavedOVPN()
            }
            .sheet(isPresented: $showingOVPNPicker) {
                OVPNDocumentPicker { name, content in
                    ovpnFileName = name
                    saveOVPN(name: name)
                    OpenVPNManager.shared.configure(withOVPN: content)
                }
            }
        }
    }

    private var buttonTitle: String {
        switch mode {
        case .vless:
            if !vlessManager.isConfigLoaded { return "Loading..." }
            switch vlessManager.connectionStatus {
            case .connecting, .reasserting: return "Connecting..."
            case .disconnecting: return "Disconnecting..."
            case .connected: return "Disconnect"
            default: return "Connect"
            }
        case .openvpn:
            if !openVPNManager.isConfigLoaded { return "Выберите .ovpn" }
            switch openVPNManager.connectionStatus {
            case .connecting, .reasserting: return "Connecting..."
            case .disconnecting: return "Disconnecting..."
            case .connected: return "Disconnect"
            default: return "Connect"
            }
        }
    }

    private var buttonColor: Color {
        switch mode {
        case .vless:
            switch vlessManager.connectionStatus {
            case .connected: return .red
            case .connecting, .reasserting, .disconnecting: return .orange
            default: return .green
            }
        case .openvpn:
            switch openVPNManager.connectionStatus {
            case .connected: return .red
            case .connecting, .reasserting, .disconnecting: return .orange
            default: return openVPNManager.isConfigLoaded ? .green : .gray
            }
        }
    }

    private var connectDisabled: Bool {
        switch mode {
        case .vless:
            return !vlessManager.isConfigLoaded
        case .openvpn:
            return !openVPNManager.isConfigLoaded
        }
    }

    private func connectOrDisconnect() {
        switch mode {
        case .vless:
            if vlessManager.connectionStatus == .connected {
                VlessManager.shared.stopVPN()
            } else {
                VlessManager.shared.startVPN(withURL: vlessURL)
            }
        case .openvpn:
            if openVPNManager.connectionStatus == .connected {
                OpenVPNManager.shared.stopVPN()
            } else {
                OpenVPNManager.shared.startVPN()
            }
        }
    }

    // MARK: - OpenVPN persistence

    private func saveOVPN(name: String) {
        UserDefaults.standard.set(name, forKey: "ovpnFileName")
    }

    private func loadSavedOVPN() {
        ovpnFileName = UserDefaults.standard.string(forKey: "ovpnFileName")
    }
}

// MARK: - OpenVPN Document Picker

struct OVPNDocumentPicker: UIViewControllerRepresentable {
    typealias Callback = (_ fileName: String, _ content: String) -> Void

    let onPick: Callback

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let ovpnType = UTType(filenameExtension: "ovpn") ?? .data
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [ovpnType], asCopy: true)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: Callback

        init(onPick: @escaping Callback) {
            self.onPick = onPick
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            do {
                let data = try Data(contentsOf: url)
                guard let content = String(data: data, encoding: .utf8) else { return }
                onPick(url.lastPathComponent, content)
            } catch {
                print("Error reading .ovpn file: \(error.localizedDescription)")
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
