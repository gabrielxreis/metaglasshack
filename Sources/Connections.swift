import Foundation
import IOBluetooth
import CoreAudio
import AppKit

struct PairedDevice: Identifiable {
    var id: String { address }
    let address: String
    let name: String
    let connected: Bool
    let isGlasses: Bool
}

/// Aparelhos Bluetooth clássicos pareados com o Mac (é assim que os óculos aparecem como fone).
@MainActor
final class ClassicBluetooth: ObservableObject {
    @Published var devices: [PairedDevice] = []
    @Published var busy: String?
    @Published var message = ""
    private var timer: Timer?

    init() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    var glasses: [PairedDevice] { devices.filter(\.isGlasses) }

    func refresh() {
        var seen = Set<String>()
        let list = ((IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice]) ?? [])
            .filter { seen.insert(($0.addressString ?? "").lowercased()).inserted }
        // O objeto de pairedDevices() guarda status velho: confere num objeto novo e nos aparelhos de áudio ativos.
        let audioNames = Set(AudioRouting.all().map(\.name))
        devices = list.map {
            let n = $0.name ?? $0.addressString ?? "?"
            let fresh = IOBluetoothDevice(addressString: $0.addressString ?? "")?.isConnected() ?? false
            return PairedDevice(address: $0.addressString ?? "", name: n,
                                connected: fresh || $0.isConnected() || audioNames.contains(n),
                                isGlasses: GlassesHints.matches(name: n, manufacturer: nil, services: []))
        }
        .sorted { ($0.isGlasses ? 0 : 1, $0.name) < ($1.isGlasses ? 0 : 1, $1.name) }
    }

    func connect(_ d: PairedDevice) { run(d, connect: true) }
    func disconnect(_ d: PairedDevice) { run(d, connect: false) }

    private func run(_ d: PairedDevice, connect: Bool) {
        busy = d.address
        message = connect ? "Conectando \(d.name)…" : "Desconectando \(d.name)…"
        let addr = d.address
        Task.detached {
            let result: IOReturn = IOBluetoothDevice(addressString: addr)
                .map { connect ? $0.openConnection() : $0.closeConnection() } ?? kIOReturnError
            await MainActor.run {
                self.busy = nil
                self.message = result == kIOReturnSuccess
                    ? (connect ? "\(d.name) conectado" : "\(d.name) desconectado")
                    : (result == kIOReturnTimeout ? "Os óculos não responderam a tempo. Eles provavelmente estão presos ao iPhone: desligue o Bluetooth do celular e tente de novo." : "Não deu (código \(result)). Os óculos estão ligados, fora do estojo e perto do Mac?")
                self.refresh()
            }
        }
    }

    static func openBluetoothSettings() {
        let urls = ["x-apple.systempreferences:com.apple.BluetoothSettings",
                    "x-apple.systempreferences:com.apple.preferences.Bluetooth"]
        for s in urls { if let u = URL(string: s), NSWorkspace.shared.open(u) { return } }
    }
}

// MARK: - Áudio (usar os óculos como fone/microfone do Mac)

struct AudioDev: Identifiable, Hashable {
    let id: AudioDeviceID
    let name: String
    let outputs: Int
    let inputs: Int
}

enum AudioRouting {
    private static var system: AudioObjectID { AudioObjectID(kAudioObjectSystemObject) }

    static func all() -> [AudioDev] {
        var addr = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDevices,
                                              mScope: kAudioObjectPropertyScopeGlobal,
                                              mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &addr, 0, nil, &size) == noErr else { return [] }
        var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(system, &addr, 0, nil, &size, &ids) == noErr else { return [] }
        return ids.map { AudioDev(id: $0, name: name($0),
                                  outputs: channels($0, kAudioObjectPropertyScopeOutput),
                                  inputs: channels($0, kAudioObjectPropertyScopeInput)) }
    }

    static func name(_ id: AudioDeviceID) -> String {
        var addr = AudioObjectPropertyAddress(mSelector: kAudioObjectPropertyName,
                                              mScope: kAudioObjectPropertyScopeGlobal,
                                              mElement: kAudioObjectPropertyElementMain)
        var ref: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let st = withUnsafeMutablePointer(to: &ref) { AudioObjectGetPropertyData(id, &addr, 0, nil, &size, $0) }
        guard st == noErr, let r = ref else { return "?" }
        return r.takeRetainedValue() as String
    }

    static func channels(_ id: AudioDeviceID, _ scope: AudioObjectPropertyScope) -> Int {
        var addr = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyStreamConfiguration,
                                              mScope: scope, mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &addr, 0, nil, &size) == noErr, size > 0 else { return 0 }
        let raw = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: 16)
        defer { raw.deallocate() }
        guard AudioObjectGetPropertyData(id, &addr, 0, nil, &size, raw) == noErr else { return 0 }
        let abl = UnsafeMutableAudioBufferListPointer(raw.assumingMemoryBound(to: AudioBufferList.self))
        return abl.reduce(0) { $0 + Int($1.mNumberChannels) }
    }

    static func current(input: Bool) -> AudioDeviceID {
        var addr = AudioObjectPropertyAddress(
            mSelector: input ? kAudioHardwarePropertyDefaultInputDevice : kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var id = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        AudioObjectGetPropertyData(system, &addr, 0, nil, &size, &id)
        return id
    }

    @discardableResult
    static func setDefault(_ dev: AudioDeviceID, input: Bool) -> Bool {
        var addr = AudioObjectPropertyAddress(
            mSelector: input ? kAudioHardwarePropertyDefaultInputDevice : kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var id = dev
        return AudioObjectSetPropertyData(system, &addr, 0, nil, UInt32(MemoryLayout<AudioDeviceID>.size), &id) == noErr
    }
}

// MARK: - Busca e pareamento de aparelhos em modo de pareamento (luz azul piscando)

struct NearbyClassic: Identifiable {
    var id: String { address }
    let address: String
    let name: String
    let paired: Bool
    let isGlasses: Bool
}

@MainActor
final class ClassicPairer: NSObject, ObservableObject, IOBluetoothDeviceInquiryDelegate, IOBluetoothDevicePairDelegate {
    @Published var searching = false
    @Published var nearby: [NearbyClassic] = []
    @Published var message = ""
    @Published var pairingAddress: String?
    var onPaired: (() -> Void)?

    private var inquiry: IOBluetoothDeviceInquiry?
    private var pairer: IOBluetoothDevicePair?

    func search() {
        inquiry?.stop()
        nearby = []
        let q = IOBluetoothDeviceInquiry(delegate: self)
        q?.updateNewDeviceNames = true
        q?.inquiryLength = 15
        inquiry = q
        let r = q?.start() ?? kIOReturnError
        searching = r == kIOReturnSuccess
        message = searching ? "Procurando aparelhos em modo de pareamento (15 s)…" : "Não consegui iniciar a busca (código \(r))."
    }

    func stop() { inquiry?.stop(); searching = false }

    func pair(_ n: NearbyClassic) {
        guard let dev = IOBluetoothDevice(addressString: n.address) else { return }
        inquiry?.stop()
        let p = IOBluetoothDevicePair(device: dev)
        p?.delegate = self
        pairer = p
        pairingAddress = n.address
        let r = p?.start() ?? kIOReturnError
        message = r == kIOReturnSuccess ? "Pareando com \(n.name)… se aparecer um código, confirme." : "Falhou ao iniciar o pareamento (código \(r))."
        if r != kIOReturnSuccess { pairingAddress = nil }
    }

    private func add(_ d: IOBluetoothDevice) {
        let addr = d.addressString ?? ""
        let name = d.name ?? d.nameOrAddress ?? addr
        let item = NearbyClassic(address: addr, name: name, paired: d.isPaired(),
                                 isGlasses: GlassesHints.matches(name: name, manufacturer: nil, services: []))
        if let i = nearby.firstIndex(where: { $0.address == addr }) { nearby[i] = item } else { nearby.append(item) }
        nearby.sort { ($0.isGlasses ? 0 : 1, $0.name) < ($1.isGlasses ? 0 : 1, $1.name) }
    }

    nonisolated func deviceInquiryDeviceFound(_ sender: IOBluetoothDeviceInquiry!, device: IOBluetoothDevice!) {
        MainActor.assumeIsolated { if let d = device { add(d) } }
    }

    nonisolated func deviceInquiryDeviceNameUpdated(_ sender: IOBluetoothDeviceInquiry!, device: IOBluetoothDevice!, devicesRemaining: UInt32) {
        MainActor.assumeIsolated { if let d = device { add(d) } }
    }

    nonisolated func deviceInquiryComplete(_ sender: IOBluetoothDeviceInquiry!, error: IOReturn, aborted: Bool) {
        MainActor.assumeIsolated {
            searching = false
            if pairingAddress == nil {
                message = nearby.isEmpty
                    ? "Nada encontrado. Confira se a luz está piscando azul e tente de novo."
                    : "Busca terminada: \(nearby.count) aparelho(s)."
            }
        }
    }

    nonisolated func devicePairingFinished(_ sender: Any!, error: IOReturn) {
        MainActor.assumeIsolated {
            let name = nearby.first(where: { $0.address == pairingAddress })?.name ?? "aparelho"
            message = error == kIOReturnSuccess ? "\(name) pareado! Agora ele aparece em Aparelhos pareados." : "Pareamento falhou (código \(error)). Coloque em modo de pareamento de novo e repita."
            if error == kIOReturnSuccess, let a = pairingAddress, let d = IOBluetoothDevice(addressString: a) {
                _ = d.openConnection()
                onPaired?()
            }
            pairingAddress = nil
        }
    }

    nonisolated func devicePairingUserConfirmationRequest(_ sender: Any!, numericValue: BluetoothNumericValue) {
        MainActor.assumeIsolated {
            message = "Código de pareamento: \(numericValue). Confirmando…"
            (sender as? IOBluetoothDevicePair)?.replyUserConfirmation(true)
        }
    }
}

// MARK: - Status detalhado dos óculos (bateria, firmware, perfis) pelo system_profiler

struct GlassesStatus {
    var battery: Int?
    var firmware: String?
    var profiles: String?
    var updated = Date()
}

@MainActor
final class GlassesInfo: ObservableObject {
    @Published var byAddress: [String: GlassesStatus] = [:]
    private var timer: Timer?

    init() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func status(for address: String) -> GlassesStatus? {
        byAddress[address.uppercased().replacingOccurrences(of: "-", with: ":")]
    }

    func refresh() {
        Task.detached {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
            p.arguments = ["SPBluetoothDataType", "-json"]
            let pipe = Pipe(); p.standardOutput = pipe; p.standardError = Pipe()
            guard (try? p.run()) != nil else { return }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            p.waitUntilExit()
            var out: [String: GlassesStatus] = [:]
            if let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let bt = (root["SPBluetoothDataType"] as? [[String: Any]])?.first {
                for key in ["device_connected", "device_not_connected"] {
                    for entry in bt[key] as? [[String: Any]] ?? [] {
                        for (_, v) in entry {
                            guard let info = v as? [String: Any], let addr = info["device_address"] as? String else { continue }
                            let bat = (info["device_batteryLevelMain"] as? String).flatMap { Int($0.replacingOccurrences(of: "%", with: "")) }
                            let prof = (info["device_services"] as? String).flatMap { s -> String? in
                                guard let a = s.firstIndex(of: "<"), let b = s.firstIndex(of: ">") else { return nil }
                                return s[s.index(after: a)..<b].trimmingCharacters(in: .whitespaces)
                            }
                            out[addr.uppercased()] = GlassesStatus(battery: bat, firmware: info["device_firmwareVersion"] as? String, profiles: prof)
                        }
                    }
                }
            }
            let result = out
            await MainActor.run { self.byAddress = result }
        }
    }
}
