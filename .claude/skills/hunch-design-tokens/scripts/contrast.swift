#!/usr/bin/env swift
//
//  contrast.swift — measure, never assert.
//
//  Usage:
//    swift contrast.swift                          print the full measured matrix
//    swift contrast.swift '#EFE3D0' '#0B0A08'      print one ratio and both luminances
//    swift contrast.swift '#E69F00' --vs-all       one colour against all three grounds
//
//  WCAG 2.1 relative luminance, sRGB. §13.2's ratios are sRGB; a Display P3 constructor
//  moves every one of them, which is why the SwiftUI adapter pins `.sRGB`.
//
//  This file holds no token value. Hexes come from the argument list, or — for the matrix —
//  are read out of references/palette.md at run time. A fourth copy of the palette living in
//  a helper script is exactly the drift this skill exists to prevent.

import Foundation

// MARK: - arithmetic

func channel(_ byte: Int) -> Double {
    let s = Double(byte) / 255
    return s <= 0.040_45 ? s / 12.92 : pow((s + 0.055) / 1.055, 2.4)
}

func luminance(_ hex: String) -> Double? {
    var h = hex.uppercased()
    if h.hasPrefix("#") { h.removeFirst() }
    guard h.count == 6, let v = Int(h, radix: 16) else { return nil }
    return 0.2126 * channel((v >> 16) & 0xFF)
        + 0.7152 * channel((v >> 8) & 0xFF)
        + 0.0722 * channel(v & 0xFF)
}

func ratio(_ a: String, _ b: String) -> Double? {
    guard let la = luminance(a), let lb = luminance(b) else { return nil }
    return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
}

func f(_ x: Double, _ places: Int = 2) -> String { String(format: "%.\(places)f", x) }

// MARK: - the matrix, read from palette.md rather than restated here

let themeNames = ["dark", "light", "highContrast"]

func firstHex(in text: String) -> String? {
    let chars = Array(text)
    for i in chars.indices where chars[i] == "#" {
        let tail = chars[(i + 1)...].prefix(6)
        if tail.count == 6, tail.allSatisfy({ $0.isHexDigit }) {
            return "#" + String(tail).uppercased()
        }
    }
    return nil
}

/// token → [dark, light, highContrast], in the order palette.md §1 lists them.
func readPalette() -> [(String, [String?])] {
    let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .deletingLastPathComponent().appendingPathComponent("references/palette.md")
    guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
    var rows: [(String, [String?])] = []
    var inTable = false
    for line in text.components(separatedBy: .newlines) {
        if line.hasPrefix("## 1. The table") { inTable = true; continue }
        if line.hasPrefix("## 2.") { break }
        guard inTable, line.hasPrefix("|"), line.hasSuffix("|") else { continue }
        let c = line.dropFirst().dropLast().components(separatedBy: "|").map {
            $0.replacingOccurrences(of: "*", with: "")
                .replacingOccurrences(of: "`", with: "")
                .trimmingCharacters(in: .whitespaces)
        }
        guard c.count == 9, c[0].contains("."), !c[0].contains(" ") else { continue }
        rows.append((c[0], [firstHex(in: c[2]), firstHex(in: c[4]), firstHex(in: c[6])]))
    }
    // `hue.*` under High Contrast is written `= stroke.primary`; resolve it.
    let primaryHC = rows.first { $0.0 == "stroke.primary" }?.1[2]
    return rows.map { row in
        row.0.hasPrefix("hue.") && row.1[2] == nil
            ? (row.0, [row.1[0], row.1[1], primaryHC]) : row
    }
}

// MARK: - output

let args = Array(CommandLine.arguments.dropFirst())

switch args.count {
case 2 where args[1] != "--vs-all":
    guard let r = ratio(args[0], args[1]),
        let la = luminance(args[0]), let lb = luminance(args[1])
    else {
        FileHandle.standardError.write(Data("not a 6-digit hex pair\n".utf8))
        exit(2)
    }
    print("\(args[0])  L \(f(la, 4))")
    print("\(args[1])  L \(f(lb, 4))")
    print("ratio       \(f(r)) : 1")

case 2:  // --vs-all
    let rows = readPalette()
    guard luminance(args[0]) != nil, let grounds = rows.first(where: { $0.0 == "ground.base" })?.1
    else {
        FileHandle.standardError.write(Data("not a hex, or palette.md is unreadable\n".utf8))
        exit(2)
    }
    for (i, name) in themeNames.enumerated() {
        guard let g = grounds[i] else { continue }
        print("\(args[0]) on \(name) \(g) = \(f(ratio(args[0], g)!)) : 1")
    }

case 0:
    let rows = readPalette()
    guard let grounds = rows.first(where: { $0.0 == "ground.base" })?.1, !rows.isEmpty else {
        FileHandle.standardError.write(Data("cannot read ../references/palette.md §1\n".utf8))
        exit(2)
    }
    func hex(_ token: String, _ t: Int) -> String? { rows.first { $0.0 == token }?.1[t] }

    print("token                dark          light         highContrast")
    print(String(repeating: "─", count: 66))
    for (token, hexes) in rows where token != "ground.base" {
        var line = token.padding(toLength: 20, withPad: " ", startingAt: 0)
        for t in 0..<3 {
            var cell = "—"
            if let h = hexes[t], let g = grounds[t] { cell = "\(h) \(f(ratio(h, g)!))" }
            line += cell.padding(toLength: 14, withPad: " ", startingAt: 0)
        }
        print(line)
    }

    if let keyline = hex("glyph.keyline", 1), let lightGround = grounds[1] {
        print("\nlight-theme keyline arithmetic — the numbers §13.2 asserts but never computes:")
        print("  keyline vs ground.base   \(f(ratio(keyline, lightGround)!)) : 1   (silhouette; must clear 3 : 1)")
        for n in ["amber", "teal", "frost", "rose"] {
            guard let h = hex("hue.\(n)", 1) else { continue }
            let label = n.padding(toLength: 6, withPad: " ", startingAt: 0)
            print("  hue.\(label) vs keyline   \(f(ratio(h, keyline)!)) : 1")
        }
    }

    if let brass = hex("accent.brass", 0), let amber = hex("hue.amber", 0),
        let cold = hex("accent.cold", 0), let frost = hex("hue.frost", 0)
    {
        print("\nregister adjacency, dark — §13.2 claims 1.36 : 1 for the first of these:")
        print("  accent.brass vs hue.amber   \(f(ratio(brass, amber)!)) : 1")
        print("  accent.cold  vs hue.frost   \(f(ratio(cold, frost)!)) : 1")
    }

default:
    print("usage: swift contrast.swift [ '#RRGGBB' '#RRGGBB' | '#RRGGBB' --vs-all ]")
    exit(1)
}
