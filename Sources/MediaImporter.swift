import Foundation
import Photos
import AVFoundation
import ImageIO
import AppKit

/// Foto ou vídeo dos óculos encontrado no Fotos (ainda não necessariamente no Mac).
struct GlassesAsset: Identifiable, Equatable {
    let id: String          // localIdentifier do Fotos
    let date: Date
    let isVideo: Bool
    let duration: Double
}

struct ImportedItem: Identifiable, Codable {
    var id: String { path }
    let path: String
    let date: Date
    let isVideo: Bool
    let origin: String
}

/// Puxa pro Mac as fotos e vídeos feitos pelos óculos.
/// Caminho: app Meta AI importa pro iPhone > Fotos do iCloud > este app separa o que é dos óculos e copia pra pasta.
@MainActor
final class MediaImporter: NSObject, ObservableObject, PHPhotoLibraryChangeObserver {
    @Published var auth: PHAuthorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    @Published var working = false
    @Published var status = ""
    @Published var progress: Double = 0
    @Published var scanDone = 0
    @Published var scanTotal = 0
    @Published var items: [ImportedItem] = []
    @Published var candidates: [GlassesAsset] = []
    @Published var importedIDs: [String: String] {   // localIdentifier -> caminho no Mac
        didSet { UserDefaults.standard.set(importedIDs, forKey: "importedIDs") }
    }
    @Published var importingIDs: Set<String> = []
    // iPhone pelo cabo
    @Published var rollItems: [GlassesAsset] = []
    @Published var rollScanning = false
    @Published var rollConnected = false
    @Published var rollChecked = 0
    @Published var rollTotal = 0
    @Published var rollStatus = ""
    @Published var destination: URL {
        didSet { UserDefaults.standard.set(destination.path, forKey: "destination") }
    }
    @Published var days: Int {
        didSet { UserDefaults.standard.set(days, forKey: "days") }
    }
    @Published var autoWatch: Bool {
        didSet { UserDefaults.standard.set(autoWatch, forKey: "autoImport") }
    }
    /// Vídeos dos óculos muitas vezes vêm sem fabricante no metadado: aceita vídeo vertical 3:4 como pista.
    @Published var videoHeuristic: Bool {
        didSet { UserDefaults.standard.set(videoHeuristic, forKey: "videoHeuristic") }
    }

    private var checked: [String: Bool]   // localIdentifier -> é dos óculos?
    private var observing = false
    private let itemsURL: URL

    override init() {
        let d = UserDefaults.standard
        let base = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Pictures/Oculos Meta", isDirectory: true)
        destination = URL(fileURLWithPath: d.string(forKey: "destination") ?? base.path)
        days = d.object(forKey: "days") as? Int ?? 30
        autoWatch = d.object(forKey: "autoImport") as? Bool ?? false
        importedIDs = d.dictionary(forKey: "importedIDs") as? [String: String] ?? [:]
        videoHeuristic = d.object(forKey: "videoHeuristic") as? Bool ?? true
        checked = d.dictionary(forKey: "checked") as? [String: Bool] ?? [:]
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Wayfarer Mac", isDirectory: true)
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        itemsURL = support.appendingPathComponent("importados.json")
        super.init()
        if let data = try? Data(contentsOf: itemsURL),
           let saved = try? JSONDecoder().decode([ImportedItem].self, from: data) {
            items = saved
        }
        if auth == .authorized || auth == .limited {
            startObserving()
            Task { await self.scanPhotos() }   // abre já listando as miniaturas
        }
    }

    // MARK: Permissão

    func requestAccess() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { s in
            Task { @MainActor in
                self.auth = s
                if s == .authorized || s == .limited { self.startObserving(); Task { await self.scanPhotos() } }
            }
        }
    }

    private func startObserving() {
        guard !observing else { return }
        PHPhotoLibrary.shared().register(self)
        observing = true
    }

    nonisolated func photoLibraryDidChange(_ changeInstance: PHChange) {
        Task { @MainActor in
            if !self.working { await self.scanPhotos() }
        }
    }

    func resetMemory() {
        checked = [:]
        UserDefaults.standard.removeObject(forKey: "checked")
        status = "Memória zerada: a próxima busca confere tudo de novo."
    }

    // MARK: Fotos do iCloud

    func scanPhotos() async {
        guard !working, auth == .authorized || auth == .limited else { return }
        working = true; progress = 0
        defer { working = false; saveState() }

        let opts = PHFetchOptions()
        opts.predicate = NSPredicate(format: "creationDate >= %@", Date().addingTimeInterval(-Double(days) * 86400) as NSDate)
        opts.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        let result = PHAsset.fetchAssets(with: opts)
        var assets: [PHAsset] = []
        result.enumerateObjects { a, _, _ in
            if (a.mediaType == .image || a.mediaType == .video) { assets.append(a) }
        }
        let pending = assets.filter { checked[$0.localIdentifier] == nil }
        rebuildCandidates(assets)
        if !pending.isEmpty { status = "Conferindo \(pending.count) itens novos dos últimos \(days) dias…" }
        // 1) Descarta na hora o que com certeza não é dos óculos (sem baixar nada)
        var suspeitos: [PHAsset] = []
        for a in pending {
            if quickReject(a) { checked[a.localIdentifier] = false } else { suspeitos.append(a) }
        }
        scanTotal = suspeitos.count; scanDone = 0
        status = "Conferindo \(suspeitos.count) possíveis arquivos dos óculos (de \(pending.count) novos)…"
        // 2) Confere o metadado só dos suspeitos, 4 de cada vez, com limite de tempo
        var feitos = 0
        var idx = 0
        while idx < suspeitos.count {
            let lote = Array(suspeitos[idx ..< min(idx + 4, suspeitos.count)])
            idx += lote.count
            await withTaskGroup(of: (String, Bool).self) { g in
                for a in lote {
                    g.addTask { @MainActor in (a.localIdentifier, await self.withTimeout(12) { await self.assetIsFromGlasses(a) } ?? false) }
                }
                for await (id, ok) in g { checked[id] = ok }
            }
            feitos += lote.count
            scanDone = feitos
            progress = Double(feitos) / Double(max(suspeitos.count, 1))
            rebuildCandidates(assets)
            if feitos % 20 == 0 { saveState() }
        }
        rebuildCandidates(assets)
        progress = 1
        // Confere se o que já foi passado ainda existe no Mac
        importedIDs = importedIDs.filter { FileManager.default.fileExists(atPath: $0.value) }
        let novos = candidates.filter { importedIDs[$0.id] == nil }
        status = "\(candidates.count) arquivo(s) dos óculos no Fotos · \(candidates.count - novos.count) já no Mac · \(novos.count) novo(s)"
        if autoWatch && !novos.isEmpty {
            working = false
            await importAssets(novos.map(\.id))
        }
    }

    private func rebuildCandidates(_ assets: [PHAsset]) {
        candidates = assets.filter { checked[$0.localIdentifier] == true }
            .map { GlassesAsset(id: $0.localIdentifier, date: $0.creationDate ?? Date(), isVideo: $0.mediaType == .video, duration: $0.duration) }
            .reversed()
    }

    func isImported(_ id: String) -> Bool { importedIDs[id] != nil }

    /// Passa pro Mac os itens escolhidos.
    func importAssets(_ ids: [String]) async {
        if ids.first?.hasPrefix("iphone:") == true { await importFromIPhone(ids); return }
        guard !working, !ids.isEmpty else { return }
        working = true; progress = 0
        defer { working = false; importingIDs = []; saveState() }
        let fetched = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
        var list: [PHAsset] = []
        fetched.enumerateObjects { a, _, _ in list.append(a) }
        importingIDs = Set(ids)
        var ok = 0
        for (i, a) in list.enumerated() {
            progress = Double(i) / Double(max(list.count, 1))
            status = "Passando \(i + 1) de \(list.count) pro Mac…"
            if await export(a) { ok += 1 }
            importingIDs.remove(a.localIdentifier)
        }
        progress = 1
        status = "Pronto: \(ok) de \(list.count) arquivo(s) passado(s) pro Mac."
    }

    /// Miniatura rápida do Fotos (não baixa o original).
    func thumbnail(_ id: String, side: CGFloat) async -> NSImage? {
        if id.hasPrefix("iphone:") { return await rollThumbnail(id, side: side) }
        guard let a = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject else { return nil }
        return await withCheckedContinuation { cont in
            let o = PHImageRequestOptions()
            o.isNetworkAccessAllowed = true
            o.deliveryMode = .highQualityFormat
            o.resizeMode = .fast
            PHImageManager.default().requestImage(for: a, targetSize: CGSize(width: side, height: side),
                                                  contentMode: .aspectFill, options: o) { img, _ in
                cont.resume(returning: img)
            }
        }
    }

    func path(for id: String) -> String? { importedIDs[id] }

    /// Filtro instantâneo: os óculos gravam sempre 3:4, nunca Live Photo, print ou panorâmica.
    private func quickReject(_ a: PHAsset) -> Bool {
        let st = a.mediaSubtypes
        if st.contains(.photoScreenshot) || st.contains(.photoLive) || st.contains(.photoPanorama)
            || st.contains(.photoDepthEffect) || st.contains(.videoHighFrameRate) || st.contains(.videoTimelapse)
            || st.contains(.videoScreenRecording) { return true }
        let w = Double(a.pixelWidth), h = Double(a.pixelHeight)
        guard w > 0, h > 0 else { return false }
        let r = min(w, h) / max(w, h)
        if abs(r - 0.75) > 0.01 { return true }          // não é 3:4
        if a.mediaType == .video && w > h { return true } // óculos gravam vídeo em pé
        return false
    }

    /// Devolve nil se a operação passar do prazo (a operação lenta segue em segundo plano e é ignorada).
    private func withTimeout<T>(_ seconds: Double, _ op: @escaping @MainActor () async -> T) async -> T? {
        let once = OnceFlag()
        return await withCheckedContinuation { (cont: CheckedContinuation<T?, Never>) in
            Task { @MainActor in
                let v = await op()
                if !once.done { once.done = true; cont.resume(returning: v) }
            }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(seconds))
                if !once.done { once.done = true; cont.resume(returning: nil) }
            }
        }
    }

    private func assetIsFromGlasses(_ a: PHAsset) async -> Bool {
        if a.mediaType == .image {
            let data: Data? = await withCheckedContinuation { cont in
                let o = PHImageRequestOptions()
                o.isNetworkAccessAllowed = true
                o.deliveryMode = .highQualityFormat
                o.version = .original
                PHImageManager.default().requestImageDataAndOrientation(for: a, options: o) { d, _, _, _ in
                    cont.resume(returning: d)
                }
            }
            guard let d = data, let src = CGImageSourceCreateWithData(d as CFData, nil) else { return false }
            return imageIsFromGlasses(src)
        } else {
            let asset: AVAsset? = await withCheckedContinuation { cont in
                let o = PHVideoRequestOptions()
                o.isNetworkAccessAllowed = true
                o.version = .original
                PHImageManager.default().requestAVAsset(forVideo: a, options: o) { av, _, _ in
                    cont.resume(returning: av)
                }
            }
            if let av = asset, await videoIsFromGlasses(av) { return true }
            return videoHeuristic && looksLikeGlassesVideo(width: a.pixelWidth, height: a.pixelHeight)
        }
    }

    private func export(_ a: PHAsset) async -> Bool {
        let resources = PHAssetResource.assetResources(for: a)
        guard let r = resources.first(where: { $0.type == .photo || $0.type == .video || $0.type == .fullSizeVideo })
                ?? resources.first else { return false }
        let date = a.creationDate ?? Date()
        let target = uniqueURL(in: dayFolder(date), name: r.originalFilename)
        let o = PHAssetResourceRequestOptions(); o.isNetworkAccessAllowed = true
        let ok: Bool = await withCheckedContinuation { cont in
            PHAssetResourceManager.default().writeData(for: r, toFile: target, options: o) { err in
                cont.resume(returning: err == nil)
            }
        }
        if ok {
            try? FileManager.default.setAttributes([.creationDate: date, .modificationDate: date], ofItemAtPath: target.path)
            items.insert(ImportedItem(path: target.path, date: date, isVideo: a.mediaType == .video, origin: "Fotos"), at: 0)
            importedIDs[a.localIdentifier] = target.path
        }
        return ok
    }

    // MARK: Pasta (AirDrop, cartão, Downloads)

    func importFolder(_ folder: URL, move: Bool) async {
        guard !working else { return }
        working = true; progress = 0
        defer { working = false; saveState() }
        let exts: Set<String> = ["jpg", "jpeg", "heic", "png", "mp4", "mov"]
        let fm = FileManager.default
        let files = (fm.enumerator(at: folder, includingPropertiesForKeys: [.creationDateKey])?.allObjects as? [URL] ?? [])
            .filter { exts.contains($0.pathExtension.lowercased()) }
        status = "Conferindo \(files.count) arquivos em \(folder.lastPathComponent)…"
        var found = 0
        for (i, f) in files.enumerated() {
            progress = Double(i) / Double(max(files.count, 1))
            let isVideo = ["mp4", "mov"].contains(f.pathExtension.lowercased())
            var ok = false
            if isVideo {
                let av = AVURLAsset(url: f)
                ok = await videoIsFromGlasses(av)
                if !ok && videoHeuristic, let t = try? await av.loadTracks(withMediaType: .video).first,
                   let size = try? await t.load(.naturalSize), let tf = try? await t.load(.preferredTransform) {
                    let s = size.applying(tf)
                    ok = looksLikeGlassesVideo(width: Int(abs(s.width)), height: Int(abs(s.height)))
                }
            } else if let src = CGImageSourceCreateWithURL(f as CFURL, nil) {
                ok = imageIsFromGlasses(src)
            }
            guard ok else { continue }
            let date = (try? f.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date()
            let target = uniqueURL(in: dayFolder(date), name: f.lastPathComponent)
            do {
                if move { try fm.moveItem(at: f, to: target) } else { try fm.copyItem(at: f, to: target) }
                items.insert(ImportedItem(path: target.path, date: date, isVideo: isVideo, origin: folder.lastPathComponent), at: 0)
                found += 1
            } catch {
                status = "Erro copiando \(f.lastPathComponent): \(error.localizedDescription)"
            }
        }
        progress = 1
        status = "Pronto: \(found) arquivo(s) dos óculos de \(files.count) conferido(s)."
    }

    // MARK: Detecção por metadado

    private static let keywords = ["ray-ban", "rayban", "meta", "stories", "oakley", "luxottica", "essilor"]

    private func hit(_ s: String?) -> Bool {
        guard let s = s?.lowercased() else { return false }
        return Self.keywords.contains(where: { s.contains($0) })
    }

    private func imageIsFromGlasses(_ src: CGImageSource) -> Bool {
        guard let p = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any] else { return false }
        let tiff = p[kCGImagePropertyTIFFDictionary] as? [CFString: Any] ?? [:]
        let exif = p[kCGImagePropertyExifDictionary] as? [CFString: Any] ?? [:]
        let candidates = [tiff[kCGImagePropertyTIFFMake], tiff[kCGImagePropertyTIFFModel], tiff[kCGImagePropertyTIFFSoftware],
                          exif[kCGImagePropertyExifLensMake], exif[kCGImagePropertyExifLensModel]]
        return candidates.contains { hit($0 as? String) }
    }

    private func videoIsFromGlasses(_ av: AVAsset) async -> Bool {
        var all: [AVMetadataItem] = []
        if let c = try? await av.load(.commonMetadata) { all += c }
        if let m = try? await av.load(.metadata) { all += m }
        for item in all {
            let key = (item.identifier?.rawValue ?? "").lowercased()
            guard key.contains("make") || key.contains("model") || key.contains("software") || key.contains("encoder") else { continue }
            if let v = try? await item.load(.stringValue), hit(v) { return true }
        }
        return false
    }

    private func looksLikeGlassesVideo(width: Int, height: Int) -> Bool {
        // Ray-Ban Meta grava vertical 3:4 (1440x1920, 1080x1440 e afins). iPhone grava 9:16.
        guard width > 0, height > width else { return false }
        return abs(Double(width) / Double(height) - 0.75) < 0.01
    }

    // MARK: Arquivos

    private func dayFolder(_ date: Date) -> URL {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        let u = destination.appendingPathComponent(f.string(from: date), isDirectory: true)
        try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }

    private func uniqueURL(in folder: URL, name: String) -> URL {
        var u = folder.appendingPathComponent(name)
        let base = u.deletingPathExtension().lastPathComponent, ext = u.pathExtension
        var n = 2
        while FileManager.default.fileExists(atPath: u.path) {
            u = folder.appendingPathComponent("\(base) \(n).\(ext)"); n += 1
        }
        return u
    }

    func saveStatePublic() { saveState() }
    func dayFolderPublic(_ d: Date) -> URL { dayFolder(d) }
    func uniqueURLPublic(in f: URL, name: String) -> URL { uniqueURL(in: f, name: name) }

    private func saveState() {
        UserDefaults.standard.set(checked, forKey: "checked")
        if let d = try? JSONEncoder().encode(Array(items.prefix(5000))) { try? d.write(to: itemsURL) }
    }

    func openDestination() {
        try? FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        NSWorkspace.shared.open(destination)
    }
}

@MainActor final class OnceFlag { var done = false }

// MARK: - iPhone pelo cabo (rolo da câmera via AFC, sem Fotos e sem iCloud)

extension MediaImporter {
    nonisolated static var toolsDir: URL {
        // build/Wayfarer Mac.app -> pasta do projeto -> tools
        Bundle.main.bundleURL.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("tools")
    }

    nonisolated static var thumbCache: URL {
        let u = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("WayfarerMac/rolo", isDirectory: true)
        try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }

    /// Roda o leitor do rolo (Python + pymobiledevice3) e devolve as linhas de saída.
    nonisolated static func runRoll(_ args: [String], onLine: @escaping @Sendable (String) -> Void = { _ in }) async -> (Int32, String) {
        await withCheckedContinuation { cont in
            let p = Process()
            p.executableURL = toolsDir.appendingPathComponent("venv/bin/python")
            p.arguments = ["-I", toolsDir.appendingPathComponent("rolo_iphone.py").path] + args
            let out = Pipe(), err = Pipe()
            p.standardOutput = out; p.standardError = err
            var buffer = Data()
            var all = ""
            out.fileHandleForReading.readabilityHandler = { h in
                buffer.append(h.availableData)
                while let nl = buffer.firstIndex(of: 10) {
                    let line = String(data: buffer[buffer.startIndex..<nl], encoding: .utf8) ?? ""
                    buffer.removeSubrange(buffer.startIndex...nl)
                    all += line + "\n"
                    onLine(line)
                }
            }
            p.terminationHandler = { proc in
                out.fileHandleForReading.readabilityHandler = nil
                let e = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                cont.resume(returning: (proc.terminationStatus, proc.terminationStatus == 0 ? all : e))
            }
            do { try p.run() } catch { cont.resume(returning: (-1, error.localizedDescription)) }
        }
    }

    func scanIPhone() async {
        guard !rollScanning else { return }
        rollScanning = true; rollStatus = "Lendo o iPhone pelo cabo…"; rollChecked = 0
        defer { rollScanning = false }
        let (code, out) = await Self.runRoll(["scan"]) { line in
            if line.hasPrefix("{\"progress\"") , let d = line.data(using: .utf8),
               let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any], let n = j["progress"] as? Int {
                Task { @MainActor in self.rollChecked = n }
            }
        }
        guard code == 0, let last = out.split(separator: "\n").last(where: { $0.contains("\"found\"") }),
              let d = last.data(using: .utf8),
              let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
              let found = j["found"] as? [[String: Any]] else {
            rollConnected = false
            rollItems = []
            rollStatus = out.contains("NoDeviceConnected") || out.lowercased().contains("no device")
                ? "Nenhum iPhone no cabo. Ligue o iPhone no Mac e desbloqueie."
                : "Não consegui ler o iPhone. Ele está desbloqueado e confiando neste Mac?"
            return
        }
        rollConnected = true
        rollTotal = j["total"] as? Int ?? 0
        rollItems = found.compactMap { f in
            guard let path = f["path"] as? String else { return nil }
            return GlassesAsset(id: "iphone:" + path,
                                date: Date(timeIntervalSince1970: f["date"] as? Double ?? 0),
                                isVideo: f["video"] as? Bool ?? false, duration: 0)
        }.sorted { $0.date > $1.date }
        rollStatus = "\(rollItems.count) dos óculos entre \(rollTotal) arquivos no iPhone"
        let novos = rollItems.filter { importedIDs[$0.id] == nil }.map(\.id)
        if autoWatch && !novos.isEmpty { await importFromIPhone(novos) }
    }

    /// Confere o iPhone de tempos em tempos enquanto a página está aberta (leitura leva < 1 s).
    func watchIPhone() async {
        while !Task.isCancelled {
            if !rollScanning && !working { await scanIPhone() }
            try? await Task.sleep(for: .seconds(rollConnected ? 20 : 8))
        }
    }

    /// Baixa (uma vez) o arquivo do iPhone para o cache local.
    func rollCachedFile(_ id: String) async -> URL? {
        let path = String(id.dropFirst("iphone:".count))
        let local = Self.thumbCache.appendingPathComponent(path.replacingOccurrences(of: "/", with: "_"))
        if FileManager.default.fileExists(atPath: local.path) { return local }
        let (code, _) = await Self.runRoll(["pull", path, local.path])
        return code == 0 ? local : nil
    }

    func rollThumbnail(_ id: String, side: CGFloat) async -> NSImage? {
        guard let url = await rollCachedFile(id) else { return nil }
        if id.lowercased().hasSuffix(".mov") || id.lowercased().hasSuffix(".mp4") {
            let gen = AVAssetImageGenerator(asset: AVURLAsset(url: url))
            gen.appliesPreferredTrackTransform = true
            gen.maximumSize = CGSize(width: side, height: side)
            if let cg = try? await gen.image(at: .zero).image { return NSImage(cgImage: cg, size: .zero) }
            return nil
        }
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: side] as CFDictionary) else { return nil }
        return NSImage(cgImage: cg, size: .zero)
    }

    func importFromIPhone(_ ids: [String]) async {
        guard !working else { return }
        working = true; progress = 0
        defer { working = false; importingIDs = []; saveStatePublic() }
        importingIDs = Set(ids)
        var ok = 0
        for (i, id) in ids.enumerated() {
            progress = Double(i) / Double(max(ids.count, 1))
            rollStatus = "Passando \(i + 1) de \(ids.count) pro Mac…"
            guard let item = rollItems.first(where: { $0.id == id }), let cached = await rollCachedFile(id) else { continue }
            let target = uniqueURLPublic(in: dayFolderPublic(item.date), name: (id as NSString).lastPathComponent)
            do {
                try FileManager.default.copyItem(at: cached, to: target)
                try? FileManager.default.setAttributes([.creationDate: item.date, .modificationDate: item.date], ofItemAtPath: target.path)
                importedIDs[id] = target.path
                items.insert(ImportedItem(path: target.path, date: item.date, isVideo: item.isVideo, origin: "iPhone"), at: 0)
                ok += 1
            } catch { rollStatus = "Erro: \(error.localizedDescription)" }
            importingIDs.remove(id)
        }
        progress = 1
        rollStatus = "Pronto: \(ok) de \(ids.count) arquivo(s) passado(s) pro Mac."
    }
}
