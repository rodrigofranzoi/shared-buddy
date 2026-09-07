import Foundation
import SwiftUI

/// Localized strings shipped in the BuddyLocalization package catalog.
public enum BuddyL10n {
    public static var bundle: Bundle { .module }

    public static func string(_ key: String.LocalizationValue) -> String {
        String(localized: key, bundle: bundle)
    }

    /// Lookup by English key when the key is only known at runtime (e.g. settings titles).
    public static func string(key: String) -> String {
        String(localized: String.LocalizationValue(key), bundle: bundle)
    }

    public static func text(_ key: LocalizedStringKey) -> Text {
        Text(key, bundle: bundle)
    }
}
