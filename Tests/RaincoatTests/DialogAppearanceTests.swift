import RaincoatThemeBase
import RaincoatTokens
import Testing

@testable import Raincoat

// The dialog's tokens, and the decisions its layout makes: what scrolls, when the hairlines
// show, and where the footer's buttons go. Expected token values are looked up by token id. This
// file uses no SwiftUI and runs on Linux. The tokens are checked in every theme (allThemes, in
// Generated/Themes.swift).

@Suite struct DialogAppearanceTests {
    @Test(arguments: allThemes, ColorMode.allCases)
    func aDialogTakesItsColorsSpacesAndTextStylesFromItsTokens(theme: RaincoatTheme, mode: ColorMode) {
        for density in Density.allCases {
            checkTokens(theme.tokens(mode: mode, density: density))
        }
    }

    private func checkTokens(_ set: RaincoatTokenSet) {
        let source = set.flattened()
        let look = DialogAppearance(set)
        #expect(TokenFormat.string(look.background) == source["dialog.bg"], "background")
        #expect(TokenFormat.string(look.foreground) == source["dialog.fg"], "foreground")
        #expect(TokenFormat.string(look.divider) == source["dialog.divider"], "divider")
        #expect(TokenFormat.string(look.dividerWidth) == source["dialog.border.width"], "divider width")
        #expect(TokenFormat.string(look.padding) == source["dialog.padding"], "padding")
        #expect(TokenFormat.string(look.gap) == source["dialog.gap"], "gap")
        #expect(TokenFormat.string(look.footerGap) == source["dialog.footer.gap"], "footer gap")
        #expect(TokenFormat.string(look.titleGap) == source["space.2"], "title gap")
        #expect(TokenFormat.string(look.title) == source["dialog.title"], "title")
        #expect(TokenFormat.string(look.description) == source["dialog.description"], "description")
        #expect(look.halfGap * 2 == look.gap, "half the gap on each side of a line between sections")
    }

    @Test func theTitleIsHeadingMdAndTheDescriptionBodyMdAsTheTypographyComponentsSetThem() {
        // The header sets them with raincoatHeading and raincoatText, so the dialog's own text style
        // tokens must be the styles those use.
        let set = RaincoatTheme.base.tokens(mode: .light, density: .comfortable)
        let look = DialogAppearance(set)
        #expect(look.title == TextAppearance(set, variant: .headingMd, color: .default).style, "title")
        #expect(look.foreground == TextAppearance(set, variant: .headingMd, color: .default).color, "color")
        #expect(look.description == TextAppearance(set, variant: .bodyMd, color: .default).style, "description")
    }

    @Test func whenEverythingFitsTheDialogIsOneScrollingAreaThatDoesNotMove() {
        // Text that grows then goes into the scrolling area, not past the sheet's edge.
        let scrolling = DialogScrolling(
            available: 600, header: 100, body: 300, footer: 80, bodyLine: 24, bodySpace: 16
        )
        #expect(scrolling == .whole, "everything fits")
        let bodiless = DialogScrolling(available: 600, header: 100, body: 0, footer: 80, bodyLine: 24, bodySpace: 0)
        #expect(bodiless == .whole, "everything fits, with no body")
    }

    @Test func aLongBodyScrollsBetweenTheHeaderAndTheFooterWhileItHasRoomForThreeLines() {
        // 600 - 100 - 80 leaves 420 for the body, more than three lines and its space.
        let roomy = DialogScrolling(
            available: 600, header: 100, body: 2000, footer: 80, bodyLine: 24, bodySpace: 16
        )
        #expect(roomy == .body, "the body scrolls")
        // Exactly three lines and the space around them.
        let exact = DialogScrolling(
            available: 100 + 80 + 3 * 24 + 16, header: 100, body: 2000, footer: 80, bodyLine: 24, bodySpace: 16
        )
        #expect(exact == .body, "three lines fit exactly")
    }

    @Test func inAScreenTooShortForThreeLinesOfTheBodyTheWholeDialogScrolls() {
        let short = DialogScrolling(
            available: 100 + 80 + 3 * 24 + 16 - 2, header: 100, body: 2000, footer: 80, bodyLine: 24, bodySpace: 16
        )
        #expect(short == .whole, "less than three lines")
        // At the largest text sizes, the header and the footer alone can be taller than the screen.
        let tall = DialogScrolling(
            available: 300, header: 200, body: 2000, footer: 160, bodyLine: 60, bodySpace: 16
        )
        #expect(tall == .whole, "header and footer taller than the screen")
        // Without a body, a header and a footer that do not fit scroll as one.
        let bodiless = DialogScrolling(available: 300, header: 200, body: 0, footer: 160, bodyLine: 24, bodySpace: 0)
        #expect(bodiless == .whole, "no body")
    }

    @Test func theKeyboardCoversTheBottomOfADialogItIsDockedOver() {
        // A sheet from 300 to 866, on a screen 874 tall, and a keyboard from 538 to the bottom.
        let docked = KeyboardCover(dialogTop: 300, dialogBottom: 866, keyboardTop: 538, keyboardBottom: 874)
        #expect(docked.height == 328, "from the keyboard's top to the sheet's bottom")
        let whole = KeyboardCover(dialogTop: 700, dialogBottom: 866, keyboardTop: 538, keyboardBottom: 874)
        #expect(whole.height == 166, "a keyboard taller than the sheet covers all of it")
    }

    @Test func aKeyboardThatIsHiddenBelowOrElsewhereCoversNothing() {
        let hidden = KeyboardCover(dialogTop: 300, dialogBottom: 866, keyboardTop: nil, keyboardBottom: nil)
        #expect(hidden.height == 0, "no keyboard")
        // A sheet that has risen above the keyboard.
        let below = KeyboardCover(dialogTop: 100, dialogBottom: 530, keyboardTop: 538, keyboardBottom: 874)
        #expect(below.height == 0, "the keyboard below the sheet")
        // A keyboard floating in the middle of an iPad's screen.
        let floating = KeyboardCover(dialogTop: 200, dialogBottom: 1000, keyboardTop: 500, keyboardBottom: 800)
        #expect(floating.height == 0, "a floating keyboard")
    }

    @Test func theHairlinesShowWhileTheBodyHasContentBeneathThem() {
        let top = DialogDividers(offset: 0, viewport: 300, content: 1000)
        #expect(!top.underHeader && top.overFooter, "at the top, content is beneath the footer only")
        let middle = DialogDividers(offset: 200, viewport: 300, content: 1000)
        #expect(middle.underHeader && middle.overFooter, "in the middle, beneath both")
        let end = DialogDividers(offset: 700, viewport: 300, content: 1000)
        #expect(end.underHeader && !end.overFooter, "at the end, beneath the header only")
        let fits = DialogDividers(offset: 0, viewport: 300, content: 200)
        #expect(!fits.underHeader && !fits.overFooter, "content that fits has no hairline")
    }

    /// The height of a stacked button, which a row of buttons never asks for.
    private func unreachable(_: Int, _: Double) -> Double {
        Issue.record("a row of buttons does not ask for a stacked height")
        return 0
    }

    @Test func buttonsThatFitSitInARowAtTheTrailingEdgeThePrimaryLast() {
        let arrangement = FooterArrangement(
            sizes: [(width: 80, height: 40), (width: 120, height: 40)], available: 400, spacing: 8,
            heightAtWidth: unreachable
        )
        #expect(!arrangement.isStacked, "a row")
        #expect(arrangement.width == 400, "as wide as the footer")
        #expect(arrangement.height == 40, "as tall as a button")
        #expect(
            arrangement.frames == [
                .init(x: 192, y: 0, width: 80, height: 40),
                .init(x: 280, y: 0, width: 120, height: 40),
            ],
            "Cancel, then the primary action against the trailing edge"
        )
    }

    @Test func buttonsInARowAreCenteredOnTheTallest() {
        let arrangement = FooterArrangement(
            sizes: [(width: 80, height: 40), (width: 120, height: 60)], available: 400, spacing: 8,
            heightAtWidth: unreachable
        )
        #expect(arrangement.height == 60, "as tall as the tallest")
        #expect(arrangement.frames[0].y == 10, "the shorter one is centered")
    }

    @Test func buttonsThatDoNotFitStackThePrimaryFirstEachAsWideAsTheFooter() {
        let arrangement = FooterArrangement(
            sizes: [(width: 180, height: 40), (width: 240, height: 40)], available: 300, spacing: 8
        ) { index, width in
            #expect(width == 300, "each button is offered the footer's width")
            return index == 1 ? 64 : 40
        }
        #expect(arrangement.isStacked, "stacked")
        #expect(arrangement.width == 300, "as wide as the footer")
        #expect(
            arrangement.frames == [
                .init(x: 0, y: 72, width: 300, height: 40),
                .init(x: 0, y: 0, width: 300, height: 64),
            ],
            "the primary action on top, then Cancel"
        )
        #expect(arrangement.height == 112, "both, and the space between them")
    }

    @Test func aSingleButtonNeverStacks() {
        let arrangement = FooterArrangement(
            sizes: [(width: 500, height: 40)], available: 300, spacing: 8, heightAtWidth: unreachable
        )
        #expect(!arrangement.isStacked, "one button")
    }

    @Test func withoutALimitTheButtonsAreAsWideAsTheirRow() {
        let arrangement = FooterArrangement(
            sizes: [(width: 80, height: 40), (width: 120, height: 40)], available: nil, spacing: 8,
            heightAtWidth: unreachable
        )
        #expect(!arrangement.isStacked, "a row")
        #expect(arrangement.width == 208, "the row's own width")
    }
}
