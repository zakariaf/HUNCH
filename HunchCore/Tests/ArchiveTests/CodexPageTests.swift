import Foundation
import Testing

import Archive
import Glyphs
import HunchTestSupport
import Laws

/// §11.1's premise — one law, one page, forever — and the one property that makes an archive
/// worth keeping: every field improves or holds, and nothing a later round does can make a page
/// worse.
@Suite("A Codex page", .tags(.unit, .presubmission))
struct CodexPageTests {

    private static let law = Law(.atom(.init(attribute: .shape, subset: Fixture.subset(0b0010))))
    private static let other = Law(
        .contextual(.init(current: .pips, comparator: .gt, previous: .pips)))
    private static let epoch = Date(timeIntervalSince1970: 1_700_000_000)

    private static func find(
        law: Law = law, mode: Mode = .probe, probes: UInt16 = 9, marks: UInt8 = 2,
        fractured: Bool = false, at: Double = 0
    ) -> CodexPage.Find {
        CodexPage.Find(
            law: law, band: .literal, skeleton: 3, mode: mode,
            at: epoch.addingTimeInterval(at), probes: probes, marks: marks,
            fractured: fractured)
    }

    /// Identity is the **extension**, so two spellings of one law are one page. That is §3.6's
    /// claim cashed: syntax is never compared.
    @Test("Identity is the extension, not the spelling")
    func oneLawOnePage() {
        let spelled = Law(.atom(.init(attribute: .shape, subset: Fixture.subset(0b0010))))
        #expect(
            CodexPage.mint(Self.find()).lawKey == CodexPage.mint(Self.find(law: spelled)).lawKey)
        #expect(
            CodexPage.mint(Self.find()).lawKey != CodexPage.mint(Self.find(law: Self.other)).lawKey)
    }

    @Test("A first find mints a page whose bests are that round's")
    func mintingIsTheFirstFind() {
        let page = CodexPage.mint(Self.find(mode: .drift, probes: 11, marks: 3))
        #expect(page.timesFound == 1)
        #expect(page.bestProbes == 11)
        #expect(page.bestMarks == 3)
        #expect(page.firstFoundMode == .drift)
        #expect(page.hasSeen(.drift))
        #expect(page.hasSeen(.probe) == false)
        #expect(page.unfractured)
        #expect(page.firstFoundAt == page.lastFoundAt)
    }

    /// The archive cannot degrade. A worse round never makes a page worse, because the page
    /// records what the player has **ever** done and an archive that could regress would punish
    /// practice.
    @Test("A worse round never makes a page worse")
    func fieldsOnlyImprove() {
        let first = CodexPage.mint(Self.find(probes: 8, marks: 3))
        let after = first.reinscribed(with: Self.find(probes: 20, marks: 1, at: 100))

        #expect(after.bestProbes == 8)
        #expect(after.bestMarks == 3)
        #expect(after.timesFound == 2)
        #expect(after.lastFoundAt > after.firstFoundAt)
        #expect(after.firstFoundAt == first.firstFoundAt)
        #expect(after.firstFoundMode == first.firstFoundMode)
    }

    /// §11.1's decision. Every other field improves; a permanent scar for one bad first
    /// encounter contradicts the improvement loop and makes early rounds feel like they damage
    /// the archive.
    @Test("Re-finding a fractured page clean heals the fracture, and it does not re-break")
    func fractureHeals() {
        let fractured = CodexPage.mint(Self.find(fractured: true))
        #expect(fractured.unfractured == false)

        let healed = fractured.reinscribed(with: Self.find(fractured: false, at: 100))
        #expect(healed.unfractured)

        let again = healed.reinscribed(with: Self.find(fractured: true, at: 200))
        #expect(again.unfractured)  // latched: it heals once and stays healed
    }

    @Test("modesSeen accumulates and is a set, not a counter", arguments: Mode.allCases)
    func modesAccumulate(_ mode: Mode) {
        var page = CodexPage.mint(Self.find(mode: .probe))
        page = page.reinscribed(with: Self.find(mode: mode, at: 10))
        #expect(page.hasSeen(.probe))
        #expect(page.hasSeen(mode))
        page = page.reinscribed(with: Self.find(mode: mode, at: 20))
        #expect(page.hasSeen(mode))
        #expect(page.timesFound == 3)
    }

    /// The DRIFT pair is **payload, never identity**, and it is written once. Folding it into
    /// `lawKey` would mint two pages for one law found behind two different dead laws; letting
    /// it be overwritten would make the reveal a page replays change under the player.
    @Test("The DRIFT partner is written on the first DRIFT find and never overwritten")
    func driftPairIsWriteOnce() {
        var find = Self.find(mode: .drift)
        find.driftPartner = Self.other.node
        find.driftHinge = 7
        var page = CodexPage.mint(find)
        #expect(page.driftPartner == Self.other.node)

        var second = Self.find(mode: .drift, at: 100)
        second.driftPartner = Self.law.node
        second.driftHinge = 12
        page = page.reinscribed(with: second)
        #expect(page.driftPartner == Self.other.node)
        #expect(page.driftHinge == 7)
    }

    @Test("Re-strike rings cap at five")
    func restrikeCap() {
        var page = CodexPage.mint(Self.find())
        for step in 1...8 { page = page.reinscribed(with: Self.find(at: Double(step))) }
        #expect(page.timesFound == 9)
        #expect(page.restrikeRings == 5)
    }

    @Test("A page round-trips through Codable")
    func pageIsCodable() throws {
        let page = CodexPage.mint(Self.find(mode: .echo, probes: 4, marks: 3))
        let data = try JSONEncoder().encode(page)
        #expect(try JSONDecoder().decode(CodexPage.self, from: data) == page)
    }
}
