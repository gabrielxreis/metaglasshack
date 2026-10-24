import SwiftUI
import AppKit
import CoreBluetooth
import CoreAudio

@main
struct WayfarerMacApp: App {
    @StateObject private var ble = BLEScanner()
    @StateObject private var classic = ClassicBluetooth()
    @StateObject private var media = MediaImporter()
    @StateObject private var pairer = ClassicPairer()
    @StateObject private var info = GlassesInfo()

    var body: some Scene {
        WindowGroup("Wayfarer Mac") {
            RootView()
                .environmentObject(ble)
                .environmentObject(classic)
                .environmentObject(media)
                .environmentObject(pairer)
                .environmentObject(info)
                .frame(minWidth: 980, minHeight: 680)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
    }
}

// MARK: - Design (base do Monitor de Visto)

enum FZ {
    static let bg = Color(hex: 0x070A18)
    static let texto = Color(hex: 0xEEF1FB)
    static let suave = Color(hex: 0x9AA3C8)
    static let acento = Color(hex: 0x5B86FF)
    static let vivo = Color(hex: 0x38BDF8)
    static let alerta = Color(hex: 0xEA3C3F)
    static let lima = Color(red: 0.55, green: 0.95, blue: 0.2)
    static let ambar = Color(hex: 0xF5B544)
    static let sobreLima = Color(hex: 0x0B1A00)
    static let card = Color.white.opacity(0.04)
    static let glassBorda = Color(red: 120 / 255, green: 150 / 255, blue: 1).opacity(0.16)
    static let gradiente = LinearGradient(colors: [acento, vivo], startPoint: .leading, endPoint: .trailing)
    static let gradienteAlerta = LinearGradient(colors: [alerta, Color(red: 1, green: 115 / 255, blue: 77 / 255)],
                                                startPoint: .leading, endPoint: .trailing)
    static let mola = Animation.timingCurve(0.22, 1, 0.36, 1, duration: 0.4)
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}

struct FundoJanela: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 14 / 255, green: 19 / 255, blue: 38 / 255), Color(red: 5 / 255, green: 6 / 255, blue: 15 / 255)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [FZ.acento.opacity(0.16), .clear], center: UnitPoint(x: 0.3, y: 0.12), startRadius: 0, endRadius: 520)
        }.ignoresSafeArea()
    }
}

struct Card<Content: View>: View {
    var brilho: Color? = nil
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(FZ.card)
            .background(.ultraThinMaterial.opacity(0.25))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(brilho?.opacity(0.55) ?? FZ.glassBorda, lineWidth: 1))
            .shadow(color: (brilho ?? .clear).opacity(0.35), radius: 18)
    }
}

struct Rotulo: View {
    let icone: String, texto: String
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icone).font(.system(size: 10, weight: .bold))
            Text(texto.uppercased()).font(.system(size: 10.5, weight: .bold)).tracking(1.2)
        }.foregroundStyle(FZ.suave).fixedSize()
    }
}

struct Chip: View {
    let texto: String
    var icone: String? = nil
    var cor: Color = FZ.acento
    var pulsando = false
    @State private var anim = false
    var body: some View {
        HStack(spacing: 6) {
            if pulsando {
                ZStack {
                    Circle().fill(cor.opacity(0.35)).frame(width: 7, height: 7)
                        .scaleEffect(anim ? 1.6 : 0.8).opacity(anim ? 0 : 1)
                    Circle().fill(cor).frame(width: 6, height: 6)
                }
                .onAppear { withAnimation(.easeOut(duration: 1.2).repeatForever(autoreverses: false)) { anim = true } }
            }
            if let i = icone { Image(systemName: i).font(.system(size: 10, weight: .bold)) }
            Text(texto).font(.system(size: 12, weight: .semibold)).contentTransition(.opacity)
        }
        .foregroundStyle(cor)
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(Capsule().fill(cor.opacity(0.13)))
        .overlay(Capsule().strokeBorder(cor.opacity(0.3), lineWidth: 1))
    }
}

struct PilulaSucesso: View {
    let texto: String
    var body: some View {
        Text(texto).font(.system(size: 11, weight: .heavy)).foregroundStyle(FZ.sobreLima)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Capsule().fill(FZ.lima)).shadow(color: FZ.lima.opacity(0.6), radius: 8).fixedSize()
    }
}

struct BotaoPrincipal: View {
    let titulo: String
    var icone: String? = nil
    var ativo = false
    var respirar = true
    let acao: () -> Void
    @State private var resp = false
    var body: some View {
        Button(action: acao) {
            HStack(spacing: 8) {
                if let i = icone { Image(systemName: i).font(.system(size: 13, weight: .heavy)) }
                Text(titulo.uppercased()).font(.system(size: 13, weight: .heavy)).tracking(0.8)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity).frame(height: 42)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(ativo ? FZ.gradienteAlerta : FZ.gradiente))
            .shadow(color: (ativo ? FZ.alerta : FZ.acento).opacity(resp ? 0.7 : 0.25), radius: resp ? 16 : 6)
            .scaleEffect(resp ? 1.015 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onAppear {
            guard respirar else { return }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { resp = true }
        }
    }
}

struct BotaoSecundario: ButtonStyle {
    var cor: Color? = nil
    var pequeno = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: pequeno ? 11.5 : 12.5, weight: .bold))
            .foregroundStyle(cor ?? FZ.texto)
            .padding(.horizontal, pequeno ? 10 : 14).padding(.vertical, pequeno ? 5 : 8)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(cor.map { $0.opacity(0.12) } ?? Color.white.opacity(0.08)))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(cor.map { $0.opacity(0.35) } ?? FZ.glassBorda, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.7 : 1)
            .contentShape(Rectangle())
    }
}

struct AvisoAmbar: View {
    let texto: String
    var icone = "exclamationmark.triangle.fill"
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icone).foregroundStyle(FZ.ambar).font(.system(size: 12, weight: .bold))
            Text(texto).font(.system(size: 12, weight: .medium)).foregroundStyle(FZ.texto.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(FZ.ambar.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(FZ.ambar.opacity(0.3), lineWidth: 1))
    }
}

struct Anel: View {
    let progresso: Double
    let centro: String
    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.06), lineWidth: 9)
            Circle().trim(from: 0, to: max(0.001, progresso))
                .stroke(FZ.gradiente, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: FZ.acento.opacity(0.6), radius: 6)
            Text(centro).font(.system(size: 24, weight: .heavy, design: .rounded)).monospacedDigit()
                .foregroundStyle(FZ.texto).contentTransition(.numericText())
        }
        .animation(FZ.mola, value: progresso)
    }
}

struct Toggle2: View {
    let titulo: String
    @Binding var valor: Bool
    var body: some View {
        Toggle(isOn: $valor) { Text(titulo).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(FZ.texto) }
            .toggleStyle(.switch).controlSize(.small).tint(FZ.acento)
    }
}

// MARK: - Estrutura

enum Pagina: String, CaseIterable, Identifiable {
    case oculos, midia, informacoes
    var id: String { rawValue }
    var titulo: String {
        switch self { case .oculos: "Óculos"; case .informacoes: "Informações BLE"; case .midia: "Fotos e vídeos" }
    }
    var icone: String {
        switch self { case .oculos: "eyeglasses"; case .informacoes: "antenna.radiowaves.left.and.right"; case .midia: "photo.on.rectangle.angled" }
    }
}

struct RootView: View {
    @EnvironmentObject var classic: ClassicBluetooth
    @EnvironmentObject var info: GlassesInfo
    @State private var pagina: Pagina = .oculos

    var body: some View {
        HStack(spacing: 0) {
            Sidebar(pagina: $pagina)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    switch pagina {
                    case .oculos: OculosView()
                    case .informacoes: ScannerView()
                    case .midia: MediaView()
                    }
                }
                .padding(.horizontal, 24).padding(.top, 30).padding(.bottom, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.opacity)
                .id(pagina)
            }
        }
        .background(FundoJanela())
        .foregroundStyle(FZ.texto)
        .animation(FZ.mola, value: pagina)
    }
}

struct Sidebar: View {
    @Binding var pagina: Pagina
    @EnvironmentObject var classic: ClassicBluetooth
    @EnvironmentObject var info: GlassesInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 10, style: .continuous).fill(FZ.gradiente)
                    .frame(width: 34, height: 34)
                    .overlay(Image(systemName: "eyeglasses").font(.system(size: 15, weight: .bold)).foregroundStyle(.white))
                    .shadow(color: FZ.acento.opacity(0.5), radius: 8)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Wayfarer").font(.system(size: 14, weight: .heavy))
                    Text("Mac").font(.system(size: 11, weight: .semibold)).foregroundStyle(FZ.suave)
                }
            }
            .padding(.top, 38).padding(.bottom, 22).padding(.horizontal, 6)

            ForEach(Pagina.allCases) { p in
                Button { pagina = p } label: {
                    HStack(spacing: 10) {
                        Image(systemName: p.icone).font(.system(size: 13, weight: .bold)).frame(width: 20)
                        Text(p.titulo).font(.system(size: 13, weight: .semibold))
                        Spacer()
                    }
                    .foregroundStyle(pagina == p ? .white : FZ.suave)
                    .padding(.horizontal, 12).padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(pagina == p ? AnyShapeStyle(FZ.gradiente) : AnyShapeStyle(Color.clear))
                            .shadow(color: pagina == p ? FZ.acento.opacity(0.5) : .clear, radius: 8)
                    )
                    .contentShape(Rectangle())
                }.buttonStyle(.plain)
            }
            Spacer()
            if let g = classic.glasses.first {
                let st = info.status(for: g.address)
                VStack(alignment: .leading, spacing: 8) {
                    Rotulo(icone: "eyeglasses", texto: "Seus óculos")
                    Text(g.name).font(.system(size: 13, weight: .heavy))
                    HStack(spacing: 6) {
                        Chip(texto: g.connected ? "No Mac" : "Fora", cor: g.connected ? FZ.lima : FZ.suave, pulsando: g.connected)
                        if let b = st?.battery {
                            Chip(texto: "\(b)%", icone: bateriaIcone(b), cor: b <= 20 ? FZ.ambar : FZ.vivo)
                        }
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.05)))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(FZ.glassBorda, lineWidth: 1))
            }
        }
        .padding(14)
        .frame(width: 228)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(
            ZStack {
                Color(hex: 0x050812).opacity(0.97)
                LinearGradient(colors: [FZ.acento.opacity(0.08), .clear], startPoint: .top, endPoint: .bottom)
            }
            .shadow(color: .black.opacity(0.55), radius: 24)
            .ignoresSafeArea()
        )
    }
}

func bateriaIcone(_ b: Int) -> String {
    b >= 88 ? "battery.100" : b >= 63 ? "battery.75" : b >= 38 ? "battery.50" : b >= 13 ? "battery.25" : "battery.0"
}

struct Cabecalho: View {
    let icone: String, titulo: String, subtitulo: String
    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 12, style: .continuous).fill(FZ.gradiente)
                .frame(width: 44, height: 44)
                .overlay(Image(systemName: icone).font(.system(size: 20, weight: .bold)).foregroundStyle(.white))
                .shadow(color: FZ.acento.opacity(0.5), radius: 10)
            VStack(alignment: .leading, spacing: 3) {
                Text(titulo).font(.system(size: 22, weight: .heavy))
                Text(subtitulo).font(.system(size: 12, weight: .medium)).foregroundStyle(FZ.suave)
            }
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

// MARK: - Óculos (parear, conectar, áudio)

struct OculosView: View {
    @EnvironmentObject var classic: ClassicBluetooth
    @EnvironmentObject var pairer: ClassicPairer
    @EnvironmentObject var info: GlassesInfo
    @State private var audio: [AudioDev] = []
    @State private var outID: AudioDeviceID = 0
    @State private var inID: AudioDeviceID = 0
    @State private var parearOutro = false

    private var precisaParear: Bool { classic.glasses.isEmpty || parearOutro }

    var body: some View {
        Cabecalho(icone: "eyeglasses", titulo: "Seus óculos no Mac",
                  subtitulo: classic.glasses.isEmpty ? "Parear, conectar e usar como fone e microfone" : "Conectar e usar como fone e microfone")

        if let g = classic.glasses.first { heroi(g) } else { semOculos }

        HStack(alignment: .top, spacing: 16) {
            VStack(spacing: 16) {
                if precisaParear { cardParear.transition(.move(edge: .top).combined(with: .opacity)) }
                cardAudio
            }
            .animation(FZ.mola, value: precisaParear)
            cardPareados
        }

        if !classic.message.isEmpty || (precisaParear && !pairer.message.isEmpty) {
            Text(precisaParear && !pairer.message.isEmpty ? pairer.message : classic.message)
                .font(.system(size: 11)).foregroundStyle(FZ.suave)
        }
    }

    private func heroi(_ g: PairedDevice) -> some View {
        let st = info.status(for: g.address)
        return Card(brilho: g.connected ? FZ.lima : nil) {
            HStack(alignment: .center, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Rotulo(icone: "dot.radiowaves.left.and.right", texto: "Status")
                        if g.connected { PilulaSucesso(texto: "NO MAC") }
                        else { Chip(texto: "Desconectado", cor: FZ.suave) }
                    }.fixedSize()
                    Text(g.name)
                        .font(.system(size: 44, weight: .heavy, design: .rounded))
                        .foregroundStyle(LinearGradient(colors: [.white, FZ.vivo], startPoint: .leading, endPoint: .trailing))
                        .lineLimit(1).minimumScaleFactor(0.5)
                    Text(g.address.uppercased().replacingOccurrences(of: "-", with: ":"))
                        .font(.system(size: 11, design: .monospaced)).foregroundStyle(FZ.suave)
                }
                .layoutPriority(1)
                Spacer(minLength: 0)
                HStack(spacing: 18) {
                    metrica("Bateria", st?.battery.map { "\($0)%" } ?? "-", icone: st?.battery.map(bateriaIcone) ?? "battery.0",
                            cor: (st?.battery ?? 100) <= 20 ? FZ.ambar : FZ.texto)
                    metrica("Firmware", st?.firmware ?? "-", icone: "cpu")
                    metrica("Modo", modo(st?.profiles), icone: "waveform")
                }
                VStack(spacing: 8) {
                    if classic.busy == g.address { ProgressView().controlSize(.small) }
                    else if g.connected {
                        Button("Desconectar") { classic.disconnect(g) }.buttonStyle(BotaoSecundario(cor: FZ.alerta))
                    } else {
                        Button("Conectar") { classic.connect(g) }.buttonStyle(BotaoSecundario(cor: FZ.vivo))
                    }
                    Button("Atualizar") { classic.refresh(); info.refresh(); reloadAudio() }.buttonStyle(BotaoSecundario(pequeno: true))
                }.frame(width: 120)
            }
            if !g.connected {
                AvisoAmbar(texto: "Se não conectar, os óculos devem estar presos ao iPhone. Desligue o Bluetooth do celular e clique em Conectar.",
                           icone: "iphone.slash")
            }
        }
    }

    private func modo(_ p: String?) -> String {
        guard let p else { return "-" }
        if p.contains("HFP") && p.contains("A2DP") { return "Fone + mic" }
        if p.contains("A2DP") { return "Fone" }
        if p.contains("HFP") { return "Chamada" }
        return "BLE"
    }

    private func metrica(_ titulo: String, _ valor: String, icone: String, cor: Color = FZ.texto) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Rotulo(icone: icone, texto: titulo)
            Text(valor).font(.system(size: 20, weight: .heavy, design: .rounded)).foregroundStyle(cor)
                .contentTransition(.numericText()).lineLimit(1).fixedSize()
        }
    }

    private var semOculos: some View {
        Card {
            Rotulo(icone: "eyeglasses", texto: "Nenhum óculos pareado")
            Text("Coloque os óculos em modo de pareamento e clique em Procurar.")
                .font(.system(size: 13, weight: .medium)).foregroundStyle(FZ.suave)
        }
    }

    private var cardParear: some View {
        Card {
            Rotulo(icone: "link", texto: "Parear")
            VStack(alignment: .leading, spacing: 10) {
                passo(1, "Óculos no estojo aberto: segure o botão de trás do estojo por 5 a 8 s até a luz piscar azul.")
                passo(2, "Ou fora do estojo: hastes dobradas, segure o botão de captura por uns 12 s.")
                passo(3, "Com a luz azul piscando, clique em Procurar e depois em Parear.")
            }
            BotaoPrincipal(titulo: pairer.searching ? "Parar busca" : "Procurar para parear",
                           icone: pairer.searching ? "stop.fill" : "magnifyingglass",
                           ativo: pairer.searching, respirar: classic.glasses.isEmpty || pairer.searching) {
                pairer.searching ? pairer.stop() : pairer.search()
            }
            ForEach(pairer.nearby) { n in
                HStack(spacing: 10) {
                    Image(systemName: n.isGlasses ? "eyeglasses" : "dot.radiowaves.left.and.right")
                        .font(.system(size: 13, weight: .bold)).foregroundStyle(n.isGlasses ? FZ.vivo : FZ.suave)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(n.name).font(.system(size: 13, weight: n.isGlasses ? .heavy : .semibold))
                        Text(n.address).font(.system(size: 10.5, design: .monospaced)).foregroundStyle(FZ.suave)
                    }
                    Spacer()
                    if n.paired { Chip(texto: "Pareado", cor: FZ.lima) }
                    else if pairer.pairingAddress == n.address { ProgressView().controlSize(.small) }
                    else { Button("Parear") { pairer.pair(n) }.buttonStyle(BotaoSecundario(cor: FZ.vivo, pequeno: true)) }
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white.opacity(0.05)))
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            Button { ClassicBluetooth.openBluetoothSettings() } label: {
                Label("Abrir Ajustes de Bluetooth", systemImage: "gearshape")
            }.buttonStyle(BotaoSecundario(pequeno: true))
        }
    }

    private func passo(_ n: Int, _ t: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(n)").font(.system(size: 11, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                .frame(width: 20, height: 20).background(Circle().fill(FZ.gradiente))
            Text(t).font(.system(size: 12, weight: .medium)).foregroundStyle(FZ.texto.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var cardAudio: some View {
        Card {
            Rotulo(icone: "speaker.wave.2.fill", texto: "Áudio do Mac")
            HStack {
                Text("Saída").font(.system(size: 12.5, weight: .semibold)).frame(width: 70, alignment: .leading)
                Picker("", selection: $outID) {
                    ForEach(audio.filter { $0.outputs > 0 }) { Text($0.name).tag($0.id) }
                }.labelsHidden()
                .onChange(of: outID) { _, v in AudioRouting.setDefault(v, input: false) }
            }
            HStack {
                Text("Microfone").font(.system(size: 12.5, weight: .semibold)).frame(width: 70, alignment: .leading)
                Picker("", selection: $inID) {
                    ForEach(audio.filter { $0.inputs > 0 }) { Text($0.name).tag($0.id) }
                }.labelsHidden()
                .onChange(of: inID) { _, v in AudioRouting.setDefault(v, input: true) }
            }
            if let g = audio.first(where: { GlassesHints.matches(name: $0.name, manufacturer: nil, services: []) }) {
                HStack(spacing: 8) {
                    Button("Óculos como fone e microfone") {
                        if g.outputs > 0 { AudioRouting.setDefault(g.id, input: false) }
                        if g.inputs > 0 { AudioRouting.setDefault(g.id, input: true) }
                        reloadAudio()
                    }.buttonStyle(BotaoSecundario(cor: FZ.vivo, pequeno: true))
                    Button("Só fone (som melhor)") {
                        if g.outputs > 0 { AudioRouting.setDefault(g.id, input: false) }
                        if let mac = audio.first(where: { $0.inputs > 0 && $0.name.lowercased().contains("macbook") }) {
                            AudioRouting.setDefault(mac.id, input: true)
                        }
                        reloadAudio()
                    }.buttonStyle(BotaoSecundario(pequeno: true))
                }
                Text("Com o microfone dos óculos ligado, o macOS usa o perfil de chamada e a música perde qualidade.")
                    .font(.system(size: 11)).foregroundStyle(FZ.suave)
            }
        }
        .onAppear { reloadAudio(); pairer.onPaired = { classic.refresh(); info.refresh(); withAnimation(FZ.mola) { parearOutro = false } } }
        .onReceive(classic.$devices) { _ in reloadAudio() }
    }

    private var cardPareados: some View {
        Card {
            HStack {
                Rotulo(icone: "list.bullet", texto: "Aparelhos pareados")
                Spacer()
                Text("\(classic.devices.count)").font(.system(size: 11, weight: .heavy, design: .rounded)).foregroundStyle(FZ.suave)
            }
            if !classic.glasses.isEmpty {
                Button { withAnimation(FZ.mola) { parearOutro.toggle(); if !parearOutro { pairer.stop() } } } label: {
                    Label(parearOutro ? "Fechar pareamento" : "Parear outro aparelho", systemImage: parearOutro ? "xmark" : "plus")
                }.buttonStyle(BotaoSecundario(pequeno: true))
            }
            ForEach(classic.devices) { d in
                HStack(spacing: 10) {
                    ZStack {
                        Circle().fill(d.isGlasses ? AnyShapeStyle(FZ.gradiente) : AnyShapeStyle(Color.white.opacity(0.08)))
                            .frame(width: 32, height: 32)
                        Image(systemName: d.isGlasses ? "eyeglasses" : "dot.radiowaves.left.and.right")
                            .font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
                        if d.connected {
                            Circle().fill(FZ.lima).frame(width: 9, height: 9).shadow(color: FZ.lima, radius: 4)
                                .offset(x: 12, y: 12)
                        }
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(d.name).font(.system(size: 12.5, weight: d.isGlasses ? .heavy : .semibold)).lineLimit(1)
                        Text(d.connected ? "Conectado" : "Desconectado")
                            .font(.system(size: 10.5, weight: .semibold)).foregroundStyle(d.connected ? FZ.lima : FZ.suave)
                    }
                    Spacer()
                    if classic.busy == d.address { ProgressView().controlSize(.small) }
                    else if d.connected { Button("Desconectar") { classic.disconnect(d) }.buttonStyle(BotaoSecundario(pequeno: true)) }
                    else { Button("Conectar") { classic.connect(d) }.buttonStyle(BotaoSecundario(cor: FZ.vivo, pequeno: true)) }
                }
                .padding(.vertical, 4)
            }
        }
        .frame(width: 330)
    }

    private func reloadAudio() {
        audio = AudioRouting.all()
        outID = AudioRouting.current(input: false)
        inID = AudioRouting.current(input: true)
    }
}

// MARK: - Informações BLE

struct ScannerView: View {
    @EnvironmentObject var ble: BLEScanner
    @State private var logAberto = true

    var body: some View {
        Cabecalho(icone: "antenna.radiowaves.left.and.right", titulo: "Informações dos óculos",
                  subtitulo: "Conecta por Bluetooth LE e lê cada campo que os óculos expõem")

        HStack(spacing: 10) {
            Chip(texto: ble.stateText, cor: ble.state == .poweredOn ? FZ.lima : FZ.ambar, pulsando: ble.scanning)
            if ble.connectedID != nil { Chip(texto: ble.connectionStatus, icone: "link", cor: FZ.vivo) }
            Spacer()
            Toggle2(titulo: "Só óculos", valor: $ble.onlyGlasses).frame(width: 130)
        }

        HStack(alignment: .top, spacing: 16) {
            Card {
                Rotulo(icone: "dot.radiowaves.left.and.right", texto: "Aparelhos por perto")
                BotaoPrincipal(titulo: ble.scanning ? "Parar" : "Procurar", icone: ble.scanning ? "stop.fill" : "magnifyingglass",
                               ativo: ble.scanning, respirar: ble.devices.isEmpty) {
                    ble.scanning ? ble.stopScan() : ble.startScan()
                }.disabled(ble.state != .poweredOn)
                ForEach(ble.sortedDevices.prefix(40)) { d in
                    HStack(spacing: 10) {
                        Image(systemName: d.isLikelyGlasses ? "eyeglasses" : "circle.dotted")
                            .font(.system(size: 12, weight: .bold)).foregroundStyle(d.isLikelyGlasses ? FZ.vivo : FZ.suave)
                            .frame(width: 18)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(d.name).font(.system(size: 12.5, weight: d.isLikelyGlasses ? .heavy : .semibold)).lineLimit(1)
                            Text(detalhes(d)).font(.system(size: 10, design: .monospaced)).foregroundStyle(FZ.suave).lineLimit(1)
                        }
                        Spacer()
                        Text(d.rssi == 0 ? "ligado" : "\(d.rssi)").font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(FZ.suave).monospacedDigit()
                        Button(ble.connectedID == d.id ? "Ler" : "Conectar") { ble.connect(d) }
                            .buttonStyle(BotaoSecundario(cor: d.isLikelyGlasses ? FZ.vivo : nil, pequeno: true))
                    }
                    .padding(.vertical, 2)
                }
            }
            .frame(width: 360)

            Card(brilho: ble.services.isEmpty ? nil : FZ.acento) {
                HStack {
                    Rotulo(icone: "square.stack.3d.up", texto: "Serviços e campos")
                    Spacer()
                    if ble.connectedID != nil {
                        Button("Desconectar") { ble.disconnect() }.buttonStyle(BotaoSecundario(cor: FZ.alerta, pequeno: true))
                    }
                    Button("Salvar relatório") { salvar() }.buttonStyle(BotaoSecundario(pequeno: true))
                }
                if ble.services.isEmpty {
                    Text("Procure os óculos e clique em Conectar para ler o que eles expõem.")
                        .font(.system(size: 12, weight: .medium)).foregroundStyle(FZ.suave)
                }
                ForEach(ble.services) { s in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Text("\(s.uuid)").font(.system(size: 13, weight: .heavy))
                            Chip(texto: s.uuid.uuidString, cor: s.uuid.uuidString == "FD5F" ? FZ.vivo : FZ.suave)
                        }
                        ForEach(s.chars) { c in campo(c) }
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.04)))
                }
            }
        }

        VStack(alignment: .leading, spacing: 8) {
            Button { withAnimation(FZ.mola) { logAberto.toggle() } } label: {
                HStack {
                    Rotulo(icone: "terminal", texto: "Log (\(ble.log.count))")
                    Image(systemName: logAberto ? "chevron.up" : "chevron.down").font(.system(size: 10, weight: .bold)).foregroundStyle(FZ.suave)
                }
            }.buttonStyle(.plain)
            if logAberto {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(Array(ble.log.enumerated()), id: \.offset) { i, l in
                                Text(l).font(.system(size: 11, design: .monospaced)).foregroundStyle(FZ.texto.opacity(0.85))
                                    .textSelection(.enabled).id(i)
                            }
                        }.padding(12)
                    }
                    .frame(height: 170)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.black.opacity(0.25)))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(FZ.glassBorda, lineWidth: 1))
                    .onChange(of: ble.log.count) { _, n in proxy.scrollTo(n - 1) }
                }
            }
        }

        AvisoAmbar(texto: "Se os óculos estiverem conectados ao iPhone, podem nem aparecer ou recusar a leitura. Desligue o Bluetooth do celular por um minuto para testar.",
                   icone: "iphone")
    }

    private func campo(_ c: CharInfo) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text("\(c.uuid)").font(.system(size: 12, weight: .bold)).lineLimit(1).truncationMode(.middle)
                Spacer()
                Text(propText(c.properties)).font(.system(size: 10, weight: .semibold)).foregroundStyle(FZ.suave)
                if c.properties.contains(.read) {
                    Button("Ler") { ble.read(c) }.buttonStyle(BotaoSecundario(pequeno: true))
                }
                if c.properties.contains(.notify) || c.properties.contains(.indicate) {
                    Button(c.notifying ? "Parar" : "Escutar") { ble.toggleNotify(c) }
                        .buttonStyle(BotaoSecundario(cor: c.notifying ? FZ.alerta : FZ.vivo, pequeno: true))
                }
            }
            if let f = friendlyValue(c) {
                Text(f).font(.system(size: 13, weight: .heavy, design: .rounded)).foregroundStyle(FZ.vivo).textSelection(.enabled)
            }
            if let v = c.value {
                Text(hex(v)).font(.system(size: 10.5, design: .monospaced)).foregroundStyle(FZ.suave).textSelection(.enabled)
            }
        }
        .padding(.vertical, 4)
    }

    private func detalhes(_ d: DiscoveredDevice) -> String {
        var parts: [String] = []
        if let id = GlassesHints.companyID(d.manufacturer) {
            parts.append(String(format: "fab 0x%04X", id) + (GlassesHints.companyIDs[id].map { " \($0)" } ?? ""))
        }
        if !d.serviceUUIDs.isEmpty { parts.append(d.serviceUUIDs.map(\.uuidString).joined(separator: ",")) }
        return parts.isEmpty ? String(d.id.uuidString.prefix(8)) : parts.joined(separator: " · ")
    }

    private func salvar() {
        let p = NSSavePanel()
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd_HH-mm"
        p.nameFieldStringValue = "relatorio-ble-\(f.string(from: Date())).md"
        if p.runModal() == .OK, let u = p.url { try? ble.report().write(to: u, atomically: true, encoding: .utf8) }
    }
}

// MARK: - Fotos e vídeos

struct MediaView: View {
    @EnvironmentObject var media: MediaImporter
    @State private var mover = false


    @State private var configAberta = false
    @AppStorage("fonteMidia") private var fonte = 0   // 0 iPhone (cabo), 1 Fotos

    private var lista: [GlassesAsset] { fonte == 0 ? media.rollItems : media.candidates }

    var body: some View {
        HStack(alignment: .center) {
            Cabecalho(icone: "photo.on.rectangle.angled", titulo: "Fotos e vídeos",
                      subtitulo: "Tudo que os óculos gravam, organizado por dia no Mac")
            Spacer()
            Button { configAberta = true } label: {
                Image(systemName: "gearshape.fill").font(.system(size: 15, weight: .bold))
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(BotaoSecundario())
            .help("Configurações")
        }
        .sheet(isPresented: $configAberta) { configuracoes }

        HStack {
            Segmentado(opcoes: ["Do iPhone (cabo)", "Fotos do Mac"], selecao: $fonte)
            Spacer()
        }
        .task(id: fonte) { if fonte == 0 { await media.watchIPhone() } }

        if fonte == 0 {
            barraIPhone
            galeria
        } else if media.auth == .authorized || media.auth == .limited {
            barraBusca
            galeria
        } else {
            Card {
                Rotulo(icone: "lock.fill", texto: "Acesso ao Fotos")
                Text("Pra achar o que os óculos gravaram, o app precisa ver a sua biblioteca do Fotos.")
                    .font(.system(size: 12.5, weight: .medium)).foregroundStyle(FZ.suave)
                BotaoPrincipal(titulo: "Permitir acesso ao Fotos", icone: "lock.open.fill") { media.requestAccess() }
                if media.auth == .denied {
                    AvisoAmbar(texto: "Acesso negado. Libere em Ajustes do Sistema > Privacidade e Segurança > Fotos.")
                }
            }
        }
    }

    // MARK: Barra de busca

    private var barraBusca: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                if media.working {
                    Text(media.scanTotal > 0 ? "Conferindo \(media.scanDone) de \(media.scanTotal)" : "Procurando…")
                        .font(.system(size: 12.5, weight: .bold)).monospacedDigit()
                } else {
                    Text("Busca concluída").font(.system(size: 12.5, weight: .bold))
                }
                Text("·").foregroundStyle(FZ.suave)
                Text("\(media.candidates.count) encontrado\(media.candidates.count == 1 ? "" : "s")")
                    .font(.system(size: 12.5, weight: .heavy, design: .rounded)).foregroundStyle(FZ.lima)
                    .contentTransition(.numericText())
                Spacer()
                if media.working {
                    Text("\(Int(media.progress * 100))%").font(.system(size: 12, weight: .heavy, design: .rounded))
                        .monospacedDigit().foregroundStyle(FZ.vivo)
                } else {
                    Button { Task { await media.scanPhotos() } } label: {
                        Label("Buscar de novo", systemImage: "arrow.clockwise")
                    }.buttonStyle(BotaoSecundario(pequeno: true))
                }
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.06))
                    Capsule().fill(FZ.gradiente)
                        .frame(width: max(6, g.size.width * (media.working ? media.progress : 1)))
                        .shadow(color: FZ.acento.opacity(0.6), radius: 6)
                        .opacity(media.working || !media.candidates.isEmpty ? 1 : 0.35)
                }
            }
            .frame(height: 6)
            .animation(FZ.mola, value: media.progress)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(FZ.card))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(FZ.glassBorda, lineWidth: 1))
    }

    // MARK: Barra do iPhone

    private var barraIPhone: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "cable.connector").foregroundStyle(media.rollConnected ? FZ.lima : FZ.suave)
                if media.rollScanning {
                    Text(media.rollChecked > 0 ? "Lendo o iPhone · \(media.rollChecked) arquivos conferidos" : "Conectando no iPhone…")
                        .font(.system(size: 12.5, weight: .bold)).monospacedDigit()
                } else if media.working {
                    Text(media.rollStatus).font(.system(size: 12.5, weight: .bold))
                } else {
                    Text(media.rollConnected ? "iPhone lido" : (media.rollStatus.isEmpty ? "iPhone" : media.rollStatus))
                        .font(.system(size: 12.5, weight: .bold))
                }
                if media.rollConnected {
                    Text("·").foregroundStyle(FZ.suave)
                    Text("\(media.rollItems.count) dos óculos")
                        .font(.system(size: 12.5, weight: .heavy, design: .rounded)).foregroundStyle(FZ.lima)
                    Text("de \(media.rollTotal) no aparelho").font(.system(size: 12)).foregroundStyle(FZ.suave)
                }
                Spacer()
                if !media.rollScanning {
                    Button { Task { await media.scanIPhone() } } label: { Label("Ler de novo", systemImage: "arrow.clockwise") }
                        .buttonStyle(BotaoSecundario(pequeno: true)).disabled(media.working)
                }
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.06))
                    let p: Double = media.working ? media.progress : (media.rollScanning ? (media.rollTotal > 0 ? Double(media.rollChecked) / Double(media.rollTotal) : 0.15) : 1)
                    Capsule().fill(FZ.gradiente)
                        .frame(width: max(6, g.size.width * p))
                        .shadow(color: FZ.acento.opacity(0.6), radius: 6)
                        .opacity(media.rollConnected || media.rollScanning ? 1 : 0.3)
                }
            }
            .frame(height: 6)
            .animation(FZ.mola, value: media.rollChecked)
            if media.rollConnected && media.rollTotal < 50 {
                Text("Só aparece o que está guardado no iPhone. Se o Fotos do iPhone estiver com Otimizar Armazenamento, os mais antigos ficam só no iCloud.")
                    .font(.system(size: 11)).foregroundStyle(FZ.suave)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(FZ.card))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(FZ.glassBorda, lineWidth: 1))
    }

    // MARK: Configurações (engrenagem)

    private var configuracoes: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "gearshape.fill").font(.system(size: 16, weight: .bold)).foregroundStyle(FZ.vivo)
                Text("Configurações").font(.system(size: 20, weight: .heavy))
                Spacer()
                Button("Pronto") { configAberta = false }.buttonStyle(BotaoSecundario(cor: FZ.vivo))
                    .keyboardShortcut(.defaultAction)
            }

            Card {
                Rotulo(icone: "folder.fill", texto: "Pasta no Mac")
                HStack(spacing: 8) {
                    Text(media.destination.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                        .font(.system(size: 12, design: .monospaced)).lineLimit(1).truncationMode(.middle)
                    Spacer()
                    Button("Trocar") { escolherDestino() }.buttonStyle(BotaoSecundario(pequeno: true))
                    Button("Abrir") { media.openDestination() }.buttonStyle(BotaoSecundario(cor: FZ.vivo, pequeno: true))
                }
                Text("Os arquivos vão pra subpastas por dia (ex.: 2026-10-24).").font(.system(size: 11)).foregroundStyle(FZ.suave)
            }

            Card {
                Rotulo(icone: "magnifyingglass", texto: "Busca")
                HStack {
                    Text("Olhar os últimos").font(.system(size: 12.5, weight: .semibold))
                    Text("\(media.days) dias").font(.system(size: 12.5, weight: .heavy, design: .rounded)).foregroundStyle(FZ.vivo)
                    Stepper("", value: $media.days, in: 1...3650).labelsHidden()
                }
                Toggle2(titulo: "Passar pro Mac sozinho quando chegar coisa nova", valor: $media.autoWatch)
                Toggle2(titulo: "Aceitar vídeo vertical 3:4 sem metadado", valor: $media.videoHeuristic)
                Button { media.resetMemory(); configAberta = false; Task { await media.scanPhotos() } } label: {
                    Label("Conferir tudo de novo", systemImage: "arrow.counterclockwise")
                }.buttonStyle(BotaoSecundario(pequeno: true)).disabled(media.working)
            }

            Card {
                Rotulo(icone: "folder.badge.plus", texto: "Importar de uma pasta")
                Text("Para arquivos que chegaram por AirDrop, cartão ou Downloads.").font(.system(size: 11)).foregroundStyle(FZ.suave)
                Toggle2(titulo: "Mover em vez de copiar", valor: $mover)
                Button { configAberta = false; escolherPasta() } label: {
                    Label("Escolher pasta…", systemImage: "folder")
                }.buttonStyle(BotaoSecundario(pequeno: true)).disabled(media.working)
            }

            AvisoAmbar(texto: "Como chega: no app Meta AI do iPhone ligue Importar automaticamente; com o Fotos do iCloud ligado no iPhone e no Mac, o app acha aqui o que foi gravado pelos óculos.",
                       icone: "info.circle.fill")
        }
        .padding(24)
        .frame(width: 520)
        .background(FundoJanela())
        .foregroundStyle(FZ.texto)
        .preferredColorScheme(.dark)
    }

    // MARK: Galeria de miniaturas

    @State private var selecionados: Set<String> = []
    @State private var filtro = 0   // 0 todos, 1 novos, 2 no Mac

    private var visiveis: [GlassesAsset] {
        switch filtro {
        case 1: return lista.filter { !media.isImported($0.id) }
        case 2: return lista.filter { media.isImported($0.id) }
        default: return lista
        }
    }
    private var novos: [GlassesAsset] { lista.filter { !media.isImported($0.id) } }

    private var galeria: some View {
        Card {
            HStack(spacing: 10) {
                Rotulo(icone: "square.grid.3x3.fill", texto: "Nos óculos (via Fotos)")
                Chip(texto: "\(lista.count) no total", cor: FZ.suave)
                Chip(texto: "\(lista.count - novos.count) no Mac", icone: "checkmark", cor: FZ.lima)
                Spacer()
                Segmentado(opcoes: ["Todos", "Novos", "No Mac"], selecao: $filtro)
            }
            HStack(spacing: 8) {
                Button("Selecionar novos") { selecionados = Set(novos.map(\.id)) }
                    .buttonStyle(BotaoSecundario(pequeno: true)).disabled(novos.isEmpty)
                if !selecionados.isEmpty {
                    Button("Limpar seleção") { selecionados = [] }.buttonStyle(BotaoSecundario(pequeno: true))
                }
                Spacer()
                Button {
                    let ids = selecionados.isEmpty ? novos.map(\.id) : Array(selecionados)
                    selecionados = []
                    Task { await media.importAssets(ids) }
                } label: {
                    Label(selecionados.isEmpty ? "Passar todos os novos (\(novos.count))" : "Passar selecionados (\(selecionados.count))",
                          systemImage: "arrow.down.to.line")
                }
                .buttonStyle(BotaoSecundario(cor: FZ.vivo))
                .disabled(media.working || (selecionados.isEmpty && novos.isEmpty))
            }
            if lista.isEmpty {
                Text(media.working ? "Procurando o que foi gravado pelos óculos…" : "Nenhum arquivo dos óculos no Fotos nesse período. Clique em Buscar no Fotos agora.")
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(FZ.suave).padding(.vertical, 20)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 128, maximum: 170), spacing: 10)], spacing: 10) {
                ForEach(visiveis) { item in
                    Miniatura(item: item,
                              importado: media.isImported(item.id),
                              passando: media.importingIDs.contains(item.id),
                              selecionado: selecionados.contains(item.id))
                        .onTapGesture {
                            if media.isImported(item.id) { return }
                            if selecionados.contains(item.id) { selecionados.remove(item.id) } else { selecionados.insert(item.id) }
                        }
                        .onTapGesture(count: 2) {
                            if let p = media.path(for: item.id) { NSWorkspace.shared.open(URL(fileURLWithPath: p)) }
                        }
                        .contextMenu {
                            if let p = media.path(for: item.id) {
                                Button("Abrir") { NSWorkspace.shared.open(URL(fileURLWithPath: p)) }
                                Button("Mostrar no Finder") { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: p)]) }
                            } else {
                                Button("Passar pro Mac") { Task { await media.importAssets([item.id]) } }
                            }
                        }
                }
            }
            HStack(spacing: 14) {
                legenda(FZ.lima, "checkmark", "Já está no Mac")
                legenda(FZ.vivo, "circle", "Selecionado")
                Text("Clique para selecionar · duplo clique abre o que já passou · botão direito para mais")
                    .font(.system(size: 11)).foregroundStyle(FZ.suave)
            }
        }
    }

    private func legenda(_ cor: Color, _ icone: String, _ texto: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icone).font(.system(size: 9, weight: .heavy)).foregroundStyle(cor)
            Text(texto).font(.system(size: 11, weight: .semibold)).foregroundStyle(FZ.suave)
        }
    }

    private func escolherDestino() {
        let p = NSOpenPanel(); p.canChooseDirectories = true; p.canChooseFiles = false; p.canCreateDirectories = true
        if p.runModal() == .OK, let u = p.url { media.destination = u }
    }

    private func escolherPasta() {
        let p = NSOpenPanel(); p.canChooseDirectories = true; p.canChooseFiles = false
        if p.runModal() == .OK, let u = p.url { Task { await media.importFolder(u, move: mover) } }
    }
}


// MARK: - Miniatura

struct Miniatura: View {
    @EnvironmentObject var media: MediaImporter
    let item: GlassesAsset
    let importado: Bool
    let passando: Bool
    let selecionado: Bool
    @State private var img: NSImage?

    var body: some View {
        ZStack {
            Color.white.opacity(0.05)
            if let img {
                Image(nsImage: img).resizable().scaledToFill()
                    .transition(.opacity)
            } else {
                ProgressView().controlSize(.small)
            }
            LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .center, endPoint: .bottom)
            VStack {
                HStack {
                    if item.isVideo {
                        HStack(spacing: 3) {
                            Image(systemName: "video.fill").font(.system(size: 8, weight: .bold))
                            Text(tempo(item.duration)).font(.system(size: 10, weight: .heavy, design: .rounded)).monospacedDigit()
                        }
                        .foregroundStyle(.white).padding(.horizontal, 6).padding(.vertical, 3)
                        .background(Capsule().fill(.black.opacity(0.55)))
                    }
                    Spacer()
                    if passando {
                        ProgressView().controlSize(.small).padding(4).background(Circle().fill(.black.opacity(0.6)))
                    } else if importado {
                        Image(systemName: "checkmark").font(.system(size: 10, weight: .heavy)).foregroundStyle(FZ.sobreLima)
                            .frame(width: 22, height: 22).background(Circle().fill(FZ.lima))
                            .shadow(color: FZ.lima.opacity(0.7), radius: 6)
                    } else if selecionado {
                        Image(systemName: "checkmark").font(.system(size: 10, weight: .heavy)).foregroundStyle(.white)
                            .frame(width: 22, height: 22).background(Circle().fill(FZ.gradiente))
                    } else {
                        Circle().strokeBorder(.white.opacity(0.8), lineWidth: 1.5).frame(width: 20, height: 20)
                            .background(Circle().fill(.black.opacity(0.25)))
                    }
                }
                Spacer()
                HStack {
                    Text(item.date.formatted(.dateTime.day().month(.abbreviated).hour().minute()))
                        .font(.system(size: 10, weight: .semibold)).foregroundStyle(.white.opacity(0.9))
                    Spacer()
                    if importado {
                        Text("NO MAC").font(.system(size: 9, weight: .heavy)).foregroundStyle(FZ.sobreLima)
                            .padding(.horizontal, 6).padding(.vertical, 2).background(Capsule().fill(FZ.lima))
                    }
                }
            }
            .padding(7)
        }
        .aspectRatio(3 / 4, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(selecionado ? FZ.vivo : (importado ? FZ.lima.opacity(0.55) : FZ.glassBorda), lineWidth: selecionado ? 2.5 : 1)
        )
        .shadow(color: selecionado ? FZ.acento.opacity(0.5) : .clear, radius: 8)
        .opacity(importado && !selecionado ? 0.82 : 1)
        .animation(FZ.mola, value: selecionado)
        .animation(FZ.mola, value: importado)
        .contentShape(Rectangle())
        .task(id: item.id) {
            if img == nil { img = await media.thumbnail(item.id, side: 360) }
        }
    }

    private func tempo(_ s: Double) -> String {
        let t = Int(s.rounded()); return String(format: "%d:%02d", t / 60, t % 60)
    }
}

struct Segmentado: View {
    let opcoes: [String]
    @Binding var selecao: Int
    var body: some View {
        HStack(spacing: 2) {
            ForEach(opcoes.indices, id: \.self) { i in
                Button { withAnimation(FZ.mola) { selecao = i } } label: {
                    Text(opcoes[i]).font(.system(size: 12, weight: .bold))
                        .foregroundStyle(selecao == i ? .white : FZ.suave)
                        .padding(.horizontal, 12).padding(.vertical, 5)
                        .background(Capsule().fill(selecao == i ? AnyShapeStyle(FZ.gradiente) : AnyShapeStyle(Color.clear))
                            .shadow(color: selecao == i ? FZ.acento.opacity(0.5) : .clear, radius: 5))
                        .contentShape(Capsule())
                }.buttonStyle(.plain)
            }
        }
        .padding(3).background(Capsule().fill(Color.white.opacity(0.06)))
    }
}
