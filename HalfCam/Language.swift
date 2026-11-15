import Foundation
import Observation

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case zhHans = "zh-Hans"
    case zhHant = "zh-Hant"
    case en
    case ja
    case ko

    var id: String { rawValue }

    var locale: Locale {
        switch self {
        case .system: Locale.autoupdatingCurrent
        case .zhHans: Locale(identifier: "zh-Hans")
        case .zhHant: Locale(identifier: "zh-Hant")
        case .en: Locale(identifier: "en")
        case .ja: Locale(identifier: "ja")
        case .ko: Locale(identifier: "ko")
        }
    }

    var menuTitle: String {
        switch self {
        case .system: L("跟随系统")
        case .zhHans: "简体中文"
        case .zhHant: "繁體中文"
        case .en: "English"
        case .ja: "日本語"
        case .ko: "한국어"
        }
    }

    var appleCode: String? {
        switch self {
        case .system: nil
        case .zhHans: "zh-Hans"
        case .zhHant: "zh-Hant"
        case .en: "en"
        case .ja: "ja"
        case .ko: "ko"
        }
    }
}

@Observable
final class L10n {
    static let shared = L10n()
    private static let key = "halfcam.language"

    var language: AppLanguage {
        didSet {
            guard language != oldValue else { return }
            persist()
        }
    }

    var locale: Locale { language.locale }

    var bundle: Bundle {
        guard let code = language.appleCode else { return .main }
        if let path = Bundle.main.path(forResource: code, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }
        return .main
    }

    private init() {
        language = AppLanguage(rawValue: UserDefaults.standard.string(forKey: Self.key) ?? "") ?? .system
        applyAppleLanguages()
    }

    private func persist() {
        if language == .system {
            UserDefaults.standard.removeObject(forKey: Self.key)
        } else {
            UserDefaults.standard.set(language.rawValue, forKey: Self.key)
        }
        applyAppleLanguages()
    }

    private func applyAppleLanguages() {
        if let code = language.appleCode {
            UserDefaults.standard.set([code], forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        }
    }
}

func L(_ value: String.LocalizationValue) -> String {
    String(localized: value, table: nil, bundle: L10n.shared.bundle, locale: L10n.shared.locale)
}

func LKey(_ key: String) -> String {
    String(localized: String.LocalizationValue(key), table: nil, bundle: L10n.shared.bundle, locale: L10n.shared.locale)
}
