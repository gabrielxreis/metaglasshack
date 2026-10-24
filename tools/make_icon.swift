import AppKit
// Ícone: squircle escuro, halo azul, óculos com gradiente acento -> vivo (DESIGN_BASE seção 7)
let size: CGFloat = 1024
let img = NSImage(size: NSSize(width: size, height: size))
img.lockFocus()
let ctx = NSGraphicsContext.current!.cgContext
let inset: CGFloat = 100, r: CGFloat = 185
let rect = CGRect(x: inset, y: inset, width: size - 2 * inset, height: size - 2 * inset)
let path = CGPath(roundedRect: rect, cornerWidth: r, cornerHeight: r, transform: nil)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 30, color: NSColor.black.withAlphaComponent(0.5).cgColor)
ctx.addPath(path); ctx.setFillColor(NSColor.black.cgColor); ctx.fillPath()
ctx.restoreGState()
ctx.addPath(path); ctx.clip()
let cs = CGColorSpaceCreateDeviceRGB()
let bg = CGGradient(colorsSpace: cs, colors: [CGColor(red: 14/255, green: 19/255, blue: 38/255, alpha: 1), CGColor(red: 5/255, green: 6/255, blue: 15/255, alpha: 1)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(bg, start: CGPoint(x: rect.minX, y: rect.maxY), end: CGPoint(x: rect.maxX, y: rect.minY), options: [])
let halo = CGGradient(colorsSpace: cs, colors: [CGColor(red: 91/255, green: 134/255, blue: 1, alpha: 0.55), CGColor(red: 91/255, green: 134/255, blue: 1, alpha: 0)] as CFArray, locations: [0, 1])!
ctx.drawRadialGradient(halo, startCenter: CGPoint(x: size/2, y: size/2), startRadius: 0, endCenter: CGPoint(x: size/2, y: size/2), endRadius: 400, options: [])
// símbolo como máscara + gradiente
let cfg = NSImage.SymbolConfiguration(pointSize: 430, weight: .bold)
let sym = NSImage(systemSymbolName: "eyeglasses", accessibilityDescription: nil)!.withSymbolConfiguration(cfg)!
let sw = sym.size.width, sh = sym.size.height
let symRect = CGRect(x: (size - sw) / 2, y: (size - sh) / 2, width: sw, height: sh)
var proposed = symRect
let cg = sym.cgImage(forProposedRect: &proposed, context: nil, hints: nil)!
ctx.saveGState()
ctx.setShadow(offset: .zero, blur: 40, color: CGColor(red: 91/255, green: 134/255, blue: 1, alpha: 0.8))
ctx.clip(to: symRect, mask: cg)
let fg = CGGradient(colorsSpace: cs, colors: [CGColor(red: 91/255, green: 134/255, blue: 1, alpha: 1), CGColor(red: 56/255, green: 189/255, blue: 248/255, alpha: 1)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(fg, start: CGPoint(x: symRect.minX, y: 0), end: CGPoint(x: symRect.maxX, y: 0), options: [])
ctx.restoreGState()
img.unlockFocus()
let out = CommandLine.arguments[1]
let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
