#if canImport(SwiftUI)
    import Foundation
    import Testing

    @testable import Raincoat

    // The few words the components say to assistive technology, in each language they are
    // translated into. English is the fallback for every other language.

    private let languages = ["en", "vi", "zh-Hans", "zh-Hant", "ja", "ko"]

    /// The language folders in the built package. Some versions of SwiftPM write their names in
    /// lower case, so languages are compared without regard to case.
    private func languageFolders() throws -> [String: URL] {
        let folders = try #require(Bundle.module.urls(forResourcesWithExtension: "lproj", subdirectory: nil))
        return Dictionary(uniqueKeysWithValues: folders.map { ($0.deletingPathExtension().lastPathComponent.lowercased(), $0) })
    }

    private func translation(of key: String, in language: String) throws -> String {
        let folder = try #require(try languageFolders()[language.lowercased()], "no folder for \(language)")
        let bundle = try #require(Bundle(url: folder))
        return bundle.localizedString(forKey: key, value: "", table: nil)
    }

    @Test(arguments: languages)
    func theLoadingAnnouncementIsTranslated(language: String) throws {
        let words = try translation(of: "button.loading", in: language)
        #expect(!words.isEmpty)
        if language != "en" {
            #expect(try words != translation(of: "button.loading", in: "en"))
        }
    }

    @Test func noOtherLanguageIsShippedHalfTranslated() throws {
        #expect(try Set(languageFolders().keys) == Set(languages.map { $0.lowercased() }))
    }
#endif
