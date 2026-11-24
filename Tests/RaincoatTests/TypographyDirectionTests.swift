#if canImport(CoreText)
    import CoreText
    import Foundation
    import Testing

    // Why the Typography guidelines ask an app to isolate a name inside a sentence. CoreText,
    // which lays out SwiftUI's text on Apple platforms, gives a paragraph the direction of its
    // first strong character. Inside a sentence, a name in another script takes the punctuation
    // and numbers after it into its own run, unless it is between U+2068 FIRST STRONG ISOLATE
    // and U+2069 POP DIRECTIONAL ISOLATE.

    @Suite struct TypographyDirectionTests {
        private let name = "مريم الحسيني"

        /// Where a line puts the name and the "2" after it, from the left: the caret offsets of
        /// the name's characters, and of the number.
        private func positions(_ text: String) throws -> (name: ClosedRange<CGFloat>, number: CGFloat) {
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: text))
            let string = text as NSString
            let nameRange = string.range(of: name)
            let offsets = (nameRange.location..<nameRange.location + nameRange.length).map {
                CTLineGetOffsetForStringIndex(line, $0, nil)
            }
            let number = CTLineGetOffsetForStringIndex(line, string.range(of: "2").location, nil)
            let left = try #require(offsets.min(), "the name is in \(text)")
            let right = try #require(offsets.max(), "the name is in \(text)")
            return (left...right, number)
        }

        @Test func typographyANameInASentenceKeepsItsDirectionOnlyWhenIsolated() throws {
            // Joined, as `Text("Message from \(name), 2 minutes ago")` builds it, the comma and
            // the number join the name's right-to-left run: "Message from 2 ,<name> minutes ago".
            // The 2 is drawn before the end of the name, not after it. (Where the run starts, the
            // caret offsets of the name and of what joined it overlap, so the 2 is not
            // necessarily before the name's first offset.)
            let joined = try positions("Message from \(name), 2 minutes ago")
            #expect(joined.number < joined.name.upperBound, "joined: the 2 at \(joined.number), the name at \(joined.name)")

            // Isolated, the sentence reads in order: the 2 is drawn after the whole name.
            let isolated = try positions("Message from \u{2068}\(name)\u{2069}, 2 minutes ago")
            #expect(
                isolated.number > isolated.name.upperBound,
                "isolated: the 2 at \(isolated.number), the name at \(isolated.name)"
            )
        }
    }
#endif
