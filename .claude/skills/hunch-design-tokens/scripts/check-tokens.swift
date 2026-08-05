#!/usr/bin/env swift
//
//  check-tokens.swift — the three-way divergence check.
//
//  Usage:  swift check-tokens.swift [repo-root]
//
//  Asserts, and names the offending row on failure:
//
//    A. Every ratio stated in references/palette.md is RECOMPUTED from its own hexes
//       and matches to ±0.05. A stated ratio nobody recomputes is how §13.2 came to
//       claim hue.amber is 9.5 : 1 when it is 8.79 : 1.
//    B. Every hex in references/palette.md appears in HunchCore/Sources/Tokens/Prim.swift,
//       once that file exists. Before it exists, palette.md is normative and B is skipped.
//    C. Every row marked **c** carries GAME_DESIGN.md §13.2's hex, verbatim, per theme.
//       Ratios are deliberately NOT compared to canon — nine of canon's are wrong and
//       palette.md §2 is the register of that.
//    D. hue.* in dark and light are Okabe-Ito verbatim; hue.* under High Contrast is
//       exactly stroke.primary.
//
//  Exit 0 clean, 1 on any divergence, 2 on a file it cannot read.

import Foundation

// MARK: - arithmetic (the same six lines as contrast.swift; duplicated deliberately so a
// script stays a single file with no import path)

func channel(_ byte: Int) -> Double {
    let s = Double(byte) / 255
    return s <= 0.040_45 ? s / 12.92 : pow((s + 0.055) / 1.055, 2.4)
}

func luminance(_ hex: String) -> Double? {
    var h = hex.uppercased()
    if h.hasPrefix("#") { h.removeFirst() }
    guard h.count == 6, let v = Int(h, radix: 16) else { return nil }
    return 0.2126 * channel((v >> 16) & 0xFF) + 0.7152 * channel((v >> 8) & 0xFF)
        + 0.0722 * channel(v & 0xFF)
}

func ratio(_ a: String, _ b: String) -> Double? {
    guard let la = luminance(a), let lb = luminance(b) else { return nil }
    return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
}

// MARK: - tiny parsers

/// The first `#RRGGBB` in a string, uppercased. No regex: this runs as a script and
/// bare-slash regex literals are not on in script mode.
func firstHex(in text: String) -> String? {
    let chars = Array(text)
    let isHex: (Character) -> Bool = { $0.isHexDigit }
    for i in chars.indices where chars[i] == "#" {
        let tail = chars[(i + 1)...].prefix(6)
        if tail.count == 6, tail.allSatisfy(isHex) { return "#" + String(tail).uppercased() }
    }
    return nil
}

/// A markdown table row's cells, trimmed, with emphasis stripped.
func cells(of line: String) -> [String]? {
    let t = line.trimmingCharacters(in: .whitespaces)
    guard t.hasPrefix("|"), t.hasSuffix("|") else { return nil }
    let parts = t.dropFirst().dropLast().components(separatedBy: "|")
    return parts.map {
        $0.replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "`", with: "")
            .trimmingCharacters(in: .whitespaces)
    }
}

func statedRatio(_ cell: String) -> Double? { Double(cell) }

func slice(_ text: String, from start: String, to end: String) -> [String] {
    let lines = text.components(separatedBy: .newlines)
    guard let a = lines.firstIndex(where: { $0.hasPrefix(start) }) else { return [] }
    let rest = lines[(a + 1)...]
    guard let b = rest.firstIndex(where: { $0.hasPrefix(end) }) else { return Array(rest) }
    return Array(rest[..<b])
}

// MARK: - locate the repo

let scriptDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
var root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "")
if CommandLine.arguments.count <= 1 {
    // scripts/ -> hunch-design-tokens/ -> skills/ -> .claude/ -> repo root
    root = scriptDir.deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
}

let paletteURL = scriptDir.deletingLastPathComponent()
    .appendingPathComponent("references/palette.md")
let gddURL = root.appendingPathComponent("GAME_DESIGN.md")
let primURL = root.appendingPathComponent("HunchCore/Sources/Tokens/Prim.swift")

guard let paletteText = try? String(contentsOf: paletteURL, encoding: .utf8) else {
    FileHandle.standardError.write(Data("cannot read \(paletteURL.path)\n".utf8))
    exit(2)
}

var failures: [String] = []
func fail(_ message: String) { failures.append(message) }

// MARK: - parse palette.md §1

struct Row {
    let token: String
    let isCanon: Bool
    /// index 0 dark, 1 light, 2 highContrast
    let hex: [String?]
    let stated: [Double?]
}

let themeNames = ["dark", "light", "highContrast"]
var rows: [Row] = []

for line in slice(paletteText, from: "## 1. The table", to: "## 2. Where canon is wrong") {
    guard let c = cells(of: line), c.count == 9 else { continue }
    guard c[0].contains("."), !c[0].contains(" ") else { continue }
    rows.append(
        Row(
            token: c[0],
            isCanon: c[1] == "c",
            hex: [firstHex(in: c[2]), firstHex(in: c[4]), firstHex(in: c[6])],
            stated: [statedRatio(c[3]), statedRatio(c[5]), statedRatio(c[7])]
        ))
}

guard !rows.isEmpty else {
    FileHandle.standardError.write(Data("parsed 0 rows from palette.md §1\n".utf8))
    exit(2)
}

// `hue.*` under High Contrast is written `= stroke.primary`; resolve it before checking.
let primaryHC = rows.first { $0.token == "stroke.primary" }?.hex[2]
rows = rows.map { r in
    guard r.token.hasPrefix("hue."), r.hex[2] == nil else { return r }
    return Row(token: r.token, isCanon: r.isCanon, hex: [r.hex[0], r.hex[1], primaryHC], stated: r.stated)
}

let grounds = rows.first { $0.token == "ground.base" }?.hex
guard let grounds, grounds.allSatisfy({ $0 != nil }) else {
    FileHandle.standardError.write(Data("palette.md §1 has no usable ground.base row\n".utf8))
    exit(2)
}

// MARK: - A. recompute every stated ratio

for r in rows where r.token != "ground.base" {
    for t in 0..<3 {
        guard let stated = r.stated[t] else { continue }
        guard let hex = r.hex[t], let ground = grounds[t] else {
            fail("A  \(r.token) [\(themeNames[t])]: a ratio is stated but no hex is")
            continue
        }
        guard let measured = ratio(hex, ground) else {
            fail("A  \(r.token) [\(themeNames[t])]: \(hex) is not a hex")
            continue
        }
        if abs(measured - stated) > 0.05 {
            fail(
                "A  \(r.token) [\(themeNames[t])]: states \(String(format: "%.2f", stated)), "
                    + "measures \(String(format: "%.2f", measured)) — fix palette.md, not the arithmetic")
        }
    }
}

// MARK: - B. every hex reaches Prim.swift

if let primText = try? String(contentsOf: primURL, encoding: .utf8) {
    var inPrim = Set<String>()
    var i = primText.startIndex
    while let r = primText.range(of: "RGB8(hex: 0x", range: i..<primText.endIndex) {
        let tail = primText[r.upperBound...].prefix(10)  // NN_NN_NN or NNNNNN
        let digits = tail.filter { $0.isHexDigit }.prefix(6)
        if digits.count == 6 { inPrim.insert("#" + digits.uppercased()) }
        i = r.upperBound
    }
    for r in rows {
        for t in 0..<3 {
            guard let hex = r.hex[t] else { continue }
            if !inPrim.contains(hex) {
                fail("B  \(r.token) [\(themeNames[t])]: \(hex) is in palette.md but not in Prim.swift")
            }
        }
    }
} else {
    print("B  skipped — \(primURL.path) does not exist yet; palette.md is normative until it does")
}

// MARK: - C. canon rows carry canon's hexes

if let gddText = try? String(contentsOf: gddURL, encoding: .utf8) {
    var canon: [String: [String?]] = [:]
    for line in slice(gddText, from: "### 13.2 Palette", to: "### 13.3") {
        guard let c = cells(of: line), c.count == 8 else { continue }
        guard !c[0].isEmpty, !c[0].contains(" ") else { continue }
        // §13.2 writes the bare `ground`; this skill renames it `ground.base` (a category
        // cannot also be a token). Everything else is spelled identically.
        let token = c[0] == "ground" ? "ground.base" : c[0]
        canon[token] = [firstHex(in: c[1]), firstHex(in: c[3]), firstHex(in: c[5])]
    }
    if canon.isEmpty { fail("C  parsed 0 rows from GAME_DESIGN.md §13.2") }
    for r in rows where r.isCanon {
        guard let c = canon[r.token] else {
            fail("C  \(r.token) is marked canon but §13.2 has no such row")
            continue
        }
        for t in 0..<3 {
            guard let mine = r.hex[t], let theirs = c[t] else { continue }
            if mine != theirs {
                fail("C  \(r.token) [\(themeNames[t])]: palette.md \(mine) vs §13.2 \(theirs)")
            }
        }
    }
} else {
    print("C  skipped — \(gddURL.path) not found; pass the repo root as argv[1]")
}

// MARK: - D. Okabe-Ito verbatim, and the High Contrast collapse

let okabeIto = ["hue.amber": "#E69F00", "hue.teal": "#009E73", "hue.frost": "#56B4E9", "hue.rose": "#CC79A7"]
for (token, expected) in okabeIto {
    guard let r = rows.first(where: { $0.token == token }) else {
        fail("D  \(token) is missing from palette.md §1")
        continue
    }
    for t in 0..<2 where r.hex[t] != expected {
        fail("D  \(token) [\(themeNames[t])]: \(r.hex[t] ?? "nil") — Okabe-Ito is verbatim, never re-lit")
    }
    if r.hex[2] != primaryHC {
        fail("D  \(token) [highContrast] must be exactly stroke.primary")
    }
}

// MARK: - report

if failures.isEmpty {
    print("check-tokens: clean — \(rows.count) rows, every stated ratio recomputed")
    exit(0)
}
FileHandle.standardError.write(Data("\ncheck-tokens: \(failures.count) divergence(s)\n\n".utf8))
for f in failures { FileHandle.standardError.write(Data("  \(f)\n".utf8)) }
FileHandle.standardError.write(Data("\n".utf8))
exit(1)
