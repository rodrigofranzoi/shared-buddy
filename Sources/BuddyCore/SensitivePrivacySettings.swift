import Foundation

/// Shared UserDefaults-backed privacy toggles for sensitive content.
public enum SensitivePrivacySettings {
    /// Legacy blur flag (preview hide is gated by ``requireAuthSensitiveContent`` only).
    public static var blurSensitiveContent: Bool {
        get { bool(for: BuddySettingsKey.blurSensitiveContent, default: true) }
        set { UserDefaults.standard.set(newValue, forKey: BuddySettingsKey.blurSensitiveContent) }
    }

    /// Ask for Touch ID / Mac password before revealing sensitive content. Off by default.
    public static var requireAuthSensitiveContent: Bool {
        get { bool(for: BuddySettingsKey.requireAuthSensitiveContent, default: false) }
        set { UserDefaults.standard.set(newValue, forKey: BuddySettingsKey.requireAuthSensitiveContent) }
    }

    /// True when sensitive content should be visually obscured until unlocked.
    public static var shouldHideSensitiveContent: Bool {
        requireAuthSensitiveContent
    }

    /// Content types locked behind password / Touch ID in previews.
    /// Defaults to all known sensitive tags. Migrates once from legacy shared `autoBlurContentTags`.
    public static var protectedTags: Set<ContentTag> {
        get { tagSet(for: BuddySettingsKey.protectedContentTags, migrateFrom: BuddySettingsKey.autoBlurContentTags) }
        set { setTagSet(newValue, for: BuddySettingsKey.protectedContentTags) }
    }

    /// Content types detected by screenshot Auto-blur.
    /// Defaults to all known sensitive tags. Independent from ``protectedTags``.
    public static var autoBlurTags: Set<ContentTag> {
        get { tagSet(for: BuddySettingsKey.autoBlurContentTags, migrateFrom: nil) }
        set { setTagSet(newValue, for: BuddySettingsKey.autoBlurContentTags) }
    }

    public static func isProtected(_ tag: ContentTag) -> Bool {
        protectedTags.contains(tag)
    }

    public static func setProtected(_ enabled: Bool, for tag: ContentTag) {
        guard ContentTagger.sensitiveTags.contains(tag) else { return }
        var tags = protectedTags
        if enabled {
            tags.insert(tag)
        } else {
            tags.remove(tag)
        }
        protectedTags = tags
    }

    public static func isAutoBlurEnabled(for tag: ContentTag) -> Bool {
        autoBlurTags.contains(tag)
    }

    public static func setAutoBlurEnabled(_ enabled: Bool, for tag: ContentTag) {
        guard ContentTagger.sensitiveTags.contains(tag) else { return }
        var tags = autoBlurTags
        if enabled {
            tags.insert(tag)
        } else {
            tags.remove(tag)
        }
        autoBlurTags = tags
    }

    private static func bool(for key: String, default defaultValue: Bool) -> Bool {
        guard UserDefaults.standard.object(forKey: key) != nil else { return defaultValue }
        return UserDefaults.standard.bool(forKey: key)
    }

    private static func tagSet(for key: String, migrateFrom legacyKey: String?) -> Set<ContentTag> {
        let defaults = UserDefaults.standard
        if let raw = defaults.string(forKey: key) {
            if raw.isEmpty { return [] }
            return Set(raw.split(separator: ",").compactMap { ContentTag(rawValue: String($0)) })
                .intersection(ContentTagger.sensitiveTags)
        }
        if let array = defaults.array(forKey: key) as? [String] {
            let decoded = Set(array.compactMap(ContentTag.init(rawValue:))).intersection(ContentTagger.sensitiveTags)
            let result: Set<ContentTag> = array.isEmpty ? [] : (decoded.isEmpty ? ContentTagger.sensitiveTags : decoded)
            setTagSet(result, for: key)
            return result
        }
        if let legacyKey,
           defaults.object(forKey: key) == nil,
           let legacy = legacyTagSet(for: legacyKey) {
            setTagSet(legacy, for: key)
            return legacy
        }
        return ContentTagger.sensitiveTags
    }

    private static func legacyTagSet(for key: String) -> Set<ContentTag>? {
        let defaults = UserDefaults.standard
        if let raw = defaults.string(forKey: key) {
            if raw.isEmpty { return [] }
            return Set(raw.split(separator: ",").compactMap { ContentTag(rawValue: String($0)) })
                .intersection(ContentTagger.sensitiveTags)
        }
        if let array = defaults.array(forKey: key) as? [String] {
            let decoded = Set(array.compactMap(ContentTag.init(rawValue:))).intersection(ContentTagger.sensitiveTags)
            return array.isEmpty ? [] : (decoded.isEmpty ? ContentTagger.sensitiveTags : decoded)
        }
        return nil
    }

    private static func setTagSet(_ tags: Set<ContentTag>, for key: String) {
        let filtered = tags.intersection(ContentTagger.sensitiveTags)
        UserDefaults.standard.set(
            filtered.map(\.rawValue).sorted().joined(separator: ","),
            forKey: key
        )
    }
}
