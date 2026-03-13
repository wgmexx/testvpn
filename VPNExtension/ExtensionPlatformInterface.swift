import Foundation
import Libbox
import NetworkExtension
import Network

public final class ExtensionPlatformInterface: NSObject, LibboxPlatformInterfaceProtocol {
    private weak var tunnel: ExtensionProvider?
    private var networkSettings: NEPacketTunnelNetworkSettings?

    init(_ tunnel: ExtensionProvider) {
        self.tunnel = tunnel
    }

    public func openTun(_ options: LibboxTunOptionsProtocol?, ret0_: UnsafeMutablePointer<Int32>?) throws {
        try runBlocking { [weak self] in
            try await self?.openTun0(options, ret0_) ?? ()
        }
    }

    private func openTun0(_ options: LibboxTunOptionsProtocol?, _ ret0_: UnsafeMutablePointer<Int32>?) async throws {
        guard let options, let ret0_, let tunnel else {
            throw NSError(domain: "ExtensionPlatformInterface", code: 0, userInfo: [NSLocalizedDescriptionKey: "nil options or tunnel"])
        }

        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")
        if options.getAutoRoute() {
            settings.mtu = NSNumber(value: options.getMTU())
            let dnsServer = try options.getDNSServerAddress()
            let dnsSettings = NEDNSSettings(servers: [dnsServer.value])
            dnsSettings.matchDomains = [""]
            dnsSettings.matchDomainsNoSearch = true
            settings.dnsSettings = dnsSettings

            var ipv4Address: [String] = []
            var ipv4Mask: [String] = []
            let iter4 = options.getInet4Address()!
            while iter4.hasNext() {
                let p = iter4.next()!
                ipv4Address.append(p.address())
                ipv4Mask.append(p.mask())
            }
            let ipv4Settings = NEIPv4Settings(addresses: ipv4Address, subnetMasks: ipv4Mask)
            var ipv4Routes: [NEIPv4Route] = []
            var ipv4Exclude: [NEIPv4Route] = []
            let route4 = options.getInet4RouteAddress()!
            if route4.hasNext() {
                while route4.hasNext() {
                    let p = route4.next()!
                    ipv4Routes.append(NEIPv4Route(destinationAddress: p.address(), subnetMask: p.mask()))
                }
            } else {
                ipv4Routes.append(NEIPv4Route.default())
            }
            let excl4 = options.getInet4RouteExcludeAddress()!
            while excl4.hasNext() {
                let p = excl4.next()!
                ipv4Exclude.append(NEIPv4Route(destinationAddress: p.address(), subnetMask: p.mask()))
            }
            ipv4Settings.includedRoutes = ipv4Routes
            ipv4Settings.excludedRoutes = ipv4Exclude
            settings.ipv4Settings = ipv4Settings

            var ipv6Address: [String] = []
            var ipv6Prefixes: [NSNumber] = []
            let iter6 = options.getInet6Address()!
            while iter6.hasNext() {
                let p = iter6.next()!
                ipv6Address.append(p.address())
                ipv6Prefixes.append(NSNumber(value: p.prefix()))
            }
            let ipv6Settings = NEIPv6Settings(addresses: ipv6Address, networkPrefixLengths: ipv6Prefixes)
            var ipv6Routes: [NEIPv6Route] = []
            var ipv6Exclude: [NEIPv6Route] = []
            let route6 = options.getInet6RouteAddress()!
            if route6.hasNext() {
                while route6.hasNext() {
                    let p = route6.next()!
                    ipv6Routes.append(NEIPv6Route(destinationAddress: p.address(), networkPrefixLength: NSNumber(value: p.prefix())))
                }
            } else {
                ipv6Routes.append(NEIPv6Route.default())
            }
            let excl6 = options.getInet6RouteExcludeAddress()!
            while excl6.hasNext() {
                let p = excl6.next()!
                ipv6Exclude.append(NEIPv6Route(destinationAddress: p.address(), networkPrefixLength: NSNumber(value: p.prefix())))
            }
            ipv6Settings.includedRoutes = ipv6Routes
            ipv6Settings.excludedRoutes = ipv6Exclude
            settings.ipv6Settings = ipv6Settings
        }

        if options.isHTTPProxyEnabled() {
            let proxy = NEProxySettings()
            proxy.httpServer = NEProxyServer(address: options.getHTTPProxyServer(), port: Int(options.getHTTPProxyServerPort()))
            proxy.httpsServer = proxy.httpServer
            proxy.httpEnabled = true
            proxy.httpsEnabled = true
            settings.proxySettings = proxy
        }

        networkSettings = settings
        try await tunnel.setTunnelNetworkSettings(settings)

        if let fd = tunnel.packetFlow.value(forKeyPath: "socket.fileDescriptor") as? Int32 {
            ret0_.pointee = fd
            return
        }
        let fdFromLib = LibboxGetTunnelFileDescriptor()
        if fdFromLib != -1 {
            ret0_.pointee = fdFromLib
        } else {
            throw NSError(domain: "ExtensionPlatformInterface", code: 0, userInfo: [NSLocalizedDescriptionKey: "missing tunnel fd"])
        }
    }

    public func usePlatformAutoDetectControl() -> Bool { false }
    public func autoDetectControl(_: Int32) throws {}
    public func findConnectionOwner(_: Int32, sourceAddress _: String?, sourcePort _: Int32, destinationAddress _: String?, destinationPort _: Int32, ret0_ _: UnsafeMutablePointer<Int32>?) throws {}
    public func packageName(byUid _: Int32, error _: NSErrorPointer) -> String { "" }
    public func uid(byPackageName _: String?, ret0_ _: UnsafeMutablePointer<Int32>?) throws {}
    public func useProcFS() -> Bool { false }

    public func writeLog(_ message: String?) {
        guard let message else { return }
        tunnel?.writeMessage(message)
    }

    private var nwMonitor: NWPathMonitor?

    public func startDefaultInterfaceMonitor(_ listener: LibboxInterfaceUpdateListenerProtocol?) throws {
        guard let listener else { return }
        let monitor = NWPathMonitor()
        nwMonitor = monitor
        let sem = DispatchSemaphore(value: 0)
        monitor.pathUpdateHandler = { [weak self] path in
            self?.onUpdate(listener, path as Network.NWPath)
            sem.signal()
            monitor.pathUpdateHandler = { [weak self] p in self?.onUpdate(listener, p as Network.NWPath) }
        }
        monitor.start(queue: .global())
        sem.wait()
    }

    private func onUpdate(_ listener: LibboxInterfaceUpdateListenerProtocol, _ path: Network.NWPath) {
        if path.status == .unsatisfied {
            listener.updateDefaultInterface("", interfaceIndex: -1, isExpensive: false, isConstrained: false)
        } else if let iface = path.availableInterfaces.first {
            listener.updateDefaultInterface(iface.name, interfaceIndex: Int32(iface.index), isExpensive: path.isExpensive, isConstrained: path.isConstrained)
        }
    }

    public func closeDefaultInterfaceMonitor(_: LibboxInterfaceUpdateListenerProtocol?) throws {
        nwMonitor?.cancel()
        nwMonitor = nil
    }

    public func getInterfaces() throws -> LibboxNetworkInterfaceIteratorProtocol {
        guard let nwMonitor else { throw NSError(domain: "ExtensionPlatformInterface", code: 0, userInfo: nil) }
        let path = nwMonitor.currentPath
        if path.status == .unsatisfied { return NetworkInterfaceArray([]) }
        var list: [LibboxNetworkInterface] = []
        for it in path.availableInterfaces {
            let obj = LibboxNetworkInterface()
            obj.name = it.name
            obj.index = Int32(it.index)
            switch it.type {
            case .wifi: obj.type = LibboxInterfaceTypeWIFI
            case .cellular: obj.type = LibboxInterfaceTypeCellular
            case .wiredEthernet: obj.type = LibboxInterfaceTypeEthernet
            default: obj.type = LibboxInterfaceTypeOther
            }
            list.append(obj)
        }
        return NetworkInterfaceArray(list)
    }

    final class NetworkInterfaceArray: NSObject, LibboxNetworkInterfaceIteratorProtocol {
        private var iterator: IndexingIterator<[LibboxNetworkInterface]>
        private var nextVal: LibboxNetworkInterface?
        init(_ arr: [LibboxNetworkInterface]) { iterator = arr.makeIterator(); nextVal = nil }
        func hasNext() -> Bool { nextVal = iterator.next(); return nextVal != nil }
        func next() -> LibboxNetworkInterface? { nextVal }
    }

    public func underNetworkExtension() -> Bool { true }
    public func includeAllNetworks() -> Bool { false }

    public func clearDNSCache() {
        guard let settings = networkSettings else { return }
        tunnel?.reasserting = true
        tunnel?.setTunnelNetworkSettings(nil) { _ in }
        tunnel?.setTunnelNetworkSettings(settings) { _ in }
        tunnel?.reasserting = false
    }

    public func readWIFIState() -> LibboxWIFIState? { nil }

    public func serviceReload() throws {
        runBlocking { [weak tunnel] in
            await tunnel?.reloadService()
        }
    }

    public func postServiceClose() {
        reset()
        tunnel?.postServiceClose()
    }

    public func getSystemProxyStatus() -> LibboxSystemProxyStatus? {
        let s = LibboxSystemProxyStatus()
        guard let settings = networkSettings?.proxySettings, settings.httpServer != nil else { return s }
        s.available = true
        s.enabled = settings.httpEnabled
        return s
    }

    public func setSystemProxyEnabled(_: Bool) throws {}
    public func send(_: LibboxNotification?) throws {}
    public func localDNSTransport() -> (any LibboxLocalDNSTransportProtocol)? { nil }
    public func systemCertificates() -> (any LibboxStringIteratorProtocol)? { nil }

    func reset() { networkSettings = nil }
}
