import SwiftUI
import NetworkExtension

struct ContentView: View {
    @State private var isConnected = false
    @State private var vlessURL = "vless://iD--V2RAXX@fastlyipcloudflaretamiz.fast.hosting-ip.com:80/?type=ws&encryption=none&host=V2RAXX.IR&path=%2FTelegram%2CV2RAXX%2CTelegram%2CV2RAXX%3Fed%3D443#United States%20473%20/%20VlessKey.com%20/%20t.me/VlessVpnFree"

    var body: some View {
        ZStack {
            Color(isConnected ? .green.opacity(0.2) : .gray.opacity(0.2)).ignoresSafeArea(edges: .all)
            VStack {
                TextEditor(text: $vlessURL)
                                 .padding()
                                 .cornerRadius(10)
                                 .frame(height: 150)
                                 .padding()

                Button(action: {
                    if isConnected {
                        VlessManager.shared.stopVPN()
                    } else {
                        VlessManager.shared.startVPN(withURL: vlessURL) 
                    }
                    isConnected.toggle()
                }) {
                    Text(isConnected ? "Disconnect" : "Connect")
                        .font(.title)
                        .padding(20)
                        .background(isConnected ? Color.red : Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(20)
                }
            }
            .onAppear {
                VlessManager.shared.loadProviderManager()
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
