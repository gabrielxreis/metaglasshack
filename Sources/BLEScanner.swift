import Foundation
import CoreBluetooth

/// Pistas de que um aparelho BLE é um óculos Meta / Ray-Ban.
enum GlassesHints {
    static let nameKeywords = ["ray-ban", "rayban", "ray ban", "meta", "stories", "wayfarer", "skyler", "headliner", "oakley"]
    /// Company IDs do Bluetooth SIG ligados a Meta / Facebook / Oculus (pistas, não garantia).
    static let companyIDs: [UInt16: String] = [0x01AB: "Meta / Facebook", 0x0133: "Oculus", 0x058E: "Meta Platforms Technologies"]
    /// UUIDs de serviço de 16 bits registrados para Facebook / Oculus.
    static let serviceUUIDs: [CBUUID] = [CBUUID(string: "FD5F"), CBUUID(string: "FEB7"), CBUUID(string: "FEB8")]

    static func matches(name: String?, manufacturer: Data?, services: [CBUUID]) -> Bool {
        if let n = name?.lowercased(), nameKeywords.contains(where: { n.contains($0) }) { return true }
        if let id = companyID(manufacturer), companyIDs[id] != nil { return true }
        return services.contains(where: { serviceUUIDs.contains($0) })
    }

    static func companyID(_ data: Data?) -> UInt16? {
        guard let d = data, d.count >= 2 else { return nil }
        return UInt16(d[d.startIndex]) | (UInt16(d[d.startIndex + 1]) << 8)
    }
}

struct DiscoveredDevice: Identifiable {
    let id: UUID
    var name: String
    var rssi: Int
    var manufacturer: Data?
    var serviceUUIDs: [CBUUID]
    var connectable: Bool
    var lastSeen: Date
    var isLikelyGlasses: Bool
    let peripheral: CBPeripheral
}

struct CharInfo: Identifiable {
    var id: String { service.uuidString + "/" + uuid.uuidString }
    let service: CBUUID
    let uuid: CBUUID
    let properties: CBCharacteristicProperties
    var value: Data?
    var notifying = false
    let characteristic: CBCharacteristic
}

struct ServiceInfo: Identifiable {
    var id: String { uuid.uuidString }
    let uuid: CBUUID
    var chars: [CharInfo]
}

@MainActor
final class BLEScanner: NSObject, ObservableObject {
    @Published var state: CBManagerState = .unknown
    @Published var scanning = false
    @Published var devices: [UUID: DiscoveredDevice] = [:]
    @Published var onlyGlasses = false
    @Published var connectedID: UUID?
    @Published var connectionStatus = ""
    @Published var services: [ServiceInfo] = []
    @Published var log: [String] = []

    private var central: CBCentralManager!
    private var connected: CBPeripheral?

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: .main)
    }

    var sortedDevices: [DiscoveredDevice] {
        devices.values
            .filter { !onlyGlasses || $0.isLikelyGlasses }
            .sorted { ($0.isLikelyGlasses ? 1 : 0, $0.rssi) > ($1.isLikelyGlasses ? 1 : 0, $1.rssi) }
    }

    var stateText: String {
        switch state {
        case .poweredOn: return "Bluetooth ligado"
        case .poweredOff: return "Bluetooth desligado"
        case .unauthorized: return "Sem permissão de Bluetooth (Ajustes > Privacidade > Bluetooth)"
        case .unsupported: return "Este Mac não suporta BLE"
        case .resetting: return "Bluetooth reiniciando"
        default: return "Verificando Bluetooth…"
        }
    }

    func startScan() {
        guard state == .poweredOn else { return }
        // Óculos já conectados ao Mac (ou a outro app daqui) não anunciam: busca também os conectados.
        let known = [CBUUID(string: "180A"), CBUUID(string: "180F")] + GlassesHints.serviceUUIDs
        for p in central.retrieveConnectedPeripherals(withServices: known) {
            upsert(p, name: p.name, rssi: 0, manufacturer: nil, services: [], connectable: true)
        }
        central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
        scanning = true
        addLog("Varredura iniciada")
    }

    func stopScan() {
        central.stopScan()
        scanning = false
        addLog("Varredura parada")
    }

    func connect(_ d: DiscoveredDevice) {
        if let c = connected { central.cancelPeripheralConnection(c) }
        services = []
        connected = d.peripheral
        connectedID = d.id
        connectionStatus = "Conectando em \(d.name)…"
        d.peripheral.delegate = self
        central.connect(d.peripheral)
        addLog("Conectando: \(d.name) \(d.id)")
    }

    func disconnect() {
        if let c = connected { central.cancelPeripheralConnection(c) }
    }

    func read(_ c: CharInfo) {
        connected?.readValue(for: c.characteristic)
    }

    func toggleNotify(_ c: CharInfo) {
        connected?.setNotifyValue(!c.notifying, for: c.characteristic)
    }

    func clearLog() { log = [] }

    /// Relatório completo (anúncios + GATT + log) para guardar ou usar em engenharia reversa.
    func report() -> String {
        var out = ["# Wayfarer Mac: relatório BLE", "Data: \(Date())", ""]
        out.append("## Aparelhos com pista de óculos")
        for d in devices.values where d.isLikelyGlasses {
            out.append("- \(d.name) | id \(d.id) | RSSI \(d.rssi) | fabricante \(d.manufacturer.map(hex) ?? "-") | serviços \(d.serviceUUIDs.map(\.uuidString).joined(separator: ","))")
        }
        out.append("")
        out.append("## GATT do aparelho conectado")
        for s in services {
            out.append("Serviço \(s.uuid.uuidString) (\(s.uuid))")
            for c in s.chars {
                out.append("  Característica \(c.uuid.uuidString) (\(c.uuid)) [\(propText(c.properties))] = \(c.value.map(hex) ?? "-") \(c.value.flatMap(text).map { "\"\($0)\"" } ?? "")")
            }
        }
        out.append("")
        out.append("## Log")
        out.append(contentsOf: log)
        return out.joined(separator: "\n")
    }

    fileprivate func addLog(_ s: String) {
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss.SSS"
        log.append("[\(f.string(from: Date()))] \(s)")
        if log.count > 3000 { log.removeFirst(log.count - 3000) }
    }

    fileprivate func upsert(_ p: CBPeripheral, name: String?, rssi: Int, manufacturer: Data?, services: [CBUUID], connectable: Bool) {
        var d = devices[p.identifier] ?? DiscoveredDevice(
            id: p.identifier, name: "", rssi: rssi, manufacturer: nil, serviceUUIDs: [],
            connectable: connectable, lastSeen: Date(), isLikelyGlasses: false, peripheral: p)
        if let n = name ?? p.name, !n.isEmpty { d.name = n } else if d.name.isEmpty { d.name = "Sem nome" }
        if rssi != 0 && rssi != 127 { d.rssi = rssi }
        if let m = manufacturer { d.manufacturer = m }
        if !services.isEmpty { d.serviceUUIDs = services }
        d.connectable = connectable || d.connectable
        d.lastSeen = Date()
        let was = d.isLikelyGlasses
        d.isLikelyGlasses = GlassesHints.matches(name: d.name, manufacturer: d.manufacturer, services: d.serviceUUIDs)
        if d.isLikelyGlasses && !was { addLog("Possível óculos: \(d.name) (\(d.id))") }
        devices[p.identifier] = d
    }

    fileprivate func setValue(_ c: CBCharacteristic) {
        guard let sUUID = c.service?.uuid,
              let si = services.firstIndex(where: { $0.uuid == sUUID }),
              let ci = services[si].chars.firstIndex(where: { $0.uuid == c.uuid }) else { return }
        services[si].chars[ci].value = c.value
        services[si].chars[ci].notifying = c.isNotifying
    }
}

extension BLEScanner: CBCentralManagerDelegate, CBPeripheralDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        MainActor.assumeIsolated {
            state = central.state
            addLog(stateText)
            if central.state != .poweredOn { scanning = false }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                                    advertisementData: [String: Any], rssi RSSI: NSNumber) {
        MainActor.assumeIsolated {
            let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String
            let man = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data
            let svcs = (advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? [])
                + ((advertisementData[CBAdvertisementDataServiceDataKey] as? [CBUUID: Data])?.keys.map { $0 } ?? [])
            let conn = (advertisementData[CBAdvertisementDataIsConnectable] as? NSNumber)?.boolValue ?? false
            upsert(peripheral, name: name, rssi: RSSI.intValue, manufacturer: man, services: svcs, connectable: conn)
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        MainActor.assumeIsolated {
            connectionStatus = "Conectado em \(peripheral.name ?? "aparelho"). Lendo serviços…"
            addLog("Conectado: \(peripheral.name ?? "?")")
            peripheral.discoverServices(nil)
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        MainActor.assumeIsolated {
            connectionStatus = "Falhou: \(error?.localizedDescription ?? "erro desconhecido")"
            addLog(connectionStatus)
            connectedID = nil
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        MainActor.assumeIsolated {
            connectionStatus = "Desconectado" + (error.map { ": \($0.localizedDescription)" } ?? "")
            addLog(connectionStatus)
            if connected == peripheral { connected = nil; connectedID = nil }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        MainActor.assumeIsolated {
            if let e = error { addLog("Erro serviços: \(e.localizedDescription)"); return }
            let list = peripheral.services ?? []
            services = list.map { ServiceInfo(uuid: $0.uuid, chars: []) }
            addLog("\(list.count) serviços encontrados")
            for s in list { peripheral.discoverCharacteristics(nil, for: s) }
            connectionStatus = "Conectado: \(list.count) serviços"
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        MainActor.assumeIsolated {
            if let e = error { addLog("Erro em \(service.uuid): \(e.localizedDescription)"); return }
            guard let si = services.firstIndex(where: { $0.uuid == service.uuid }) else { return }
            let chars = service.characteristics ?? []
            services[si].chars = chars.map {
                CharInfo(service: service.uuid, uuid: $0.uuid, properties: $0.properties, value: $0.value, characteristic: $0)
            }
            addLog("Serviço \(service.uuid.uuidString): \(chars.count) características")
            for c in chars where c.properties.contains(.read) { peripheral.readValue(for: c) }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        MainActor.assumeIsolated {
            if let e = error { addLog("Leitura \(characteristic.uuid.uuidString) negada: \(e.localizedDescription)"); return }
            setValue(characteristic)
            let v = characteristic.value ?? Data()
            addLog("← \(characteristic.uuid.uuidString) \(hex(v))\(text(v).map { "  \"\($0)\"" } ?? "")")
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        MainActor.assumeIsolated {
            if let e = error { addLog("Notificação \(characteristic.uuid.uuidString) negada: \(e.localizedDescription)"); return }
            setValue(characteristic)
            addLog("Notificação \(characteristic.uuid.uuidString): \(characteristic.isNotifying ? "ligada" : "desligada")")
        }
    }
}

// MARK: - Formatação

func hex(_ d: Data) -> String {
    d.prefix(64).map { String(format: "%02X", $0) }.joined(separator: " ") + (d.count > 64 ? " …(\(d.count) bytes)" : "")
}

func text(_ d: Data) -> String? {
    guard !d.isEmpty, let s = String(data: d, encoding: .utf8) else { return nil }
    let printable = s.unicodeScalars.allSatisfy { $0.value >= 32 || $0 == "\n" || $0 == "\0" }
    return printable ? s.trimmingCharacters(in: CharacterSet(charactersIn: "\0")) : nil
}

func propText(_ p: CBCharacteristicProperties) -> String {
    var a: [String] = []
    if p.contains(.read) { a.append("ler") }
    if p.contains(.write) { a.append("escrever") }
    if p.contains(.writeWithoutResponse) { a.append("escrever s/ resp") }
    if p.contains(.notify) { a.append("notificar") }
    if p.contains(.indicate) { a.append("indicar") }
    return a.joined(separator: ", ")
}

/// Interpreta características padrão (Device Information, Bateria).
func friendlyValue(_ c: CharInfo) -> String? {
    guard let v = c.value, !v.isEmpty else { return nil }
    switch c.uuid.uuidString {
    case "2A19": return "\(v[v.startIndex])% de bateria"
    case "2A24", "2A25", "2A26", "2A27", "2A28", "2A29", "2A00": return text(v)
    default: return text(v)
    }
}
