import SwiftUI
import UIKit

enum FilmPackFamily: Hashable {
    case kodakGold, kodakRed, fujiGreen, fujiCyan, fujiGray, fujiRed
    case cineStill, visionCan, kodakBW, ilfordBW, fujiBW
}

struct FilmPackStyle: Hashable {
    var body: Color
    var band: Color
    var accent: Color
    var ink: Color
    var bandInk: Color
    var family: FilmPackFamily

    var mark: Color {
        switch family {
        case .visionCan, .cineStill: band
        case .kodakBW, .ilfordBW, .fujiBW: accent
        default: body
        }
    }

    static func resolved(id: String) -> FilmPackStyle {
        switch id {
        case "kodak_portra_160":
            gold(Color(red: 0.86, green: 0.74, blue: 0.48))
        case "kodak_portra_400":
            gold(Color(red: 0.82, green: 0.62, blue: 0.22))
        case "kodak_portra_800":
            gold(Color(red: 0.58, green: 0.34, blue: 0.14))
        case "kodak_portra_800_push1":
            gold(Color(red: 0.50, green: 0.28, blue: 0.12))
        case "kodak_portra_800_push2":
            gold(Color(red: 0.42, green: 0.22, blue: 0.10))
        case "kodak_gold_200":
            FilmPackStyle(
                body: Color(red: 0.96, green: 0.82, blue: 0.10),
                band: Color(red: 0.82, green: 0.12, blue: 0.10),
                accent: Color(red: 0.82, green: 0.12, blue: 0.10),
                ink: Color.black.opacity(0.82),
                bandInk: Color.white.opacity(0.94),
                family: .kodakGold
            )
        case "kodak_ektar_100":
            FilmPackStyle(
                body: Color(red: 0.86, green: 0.10, blue: 0.12),
                band: Color.white.opacity(0.94),
                accent: Color.white.opacity(0.94),
                ink: Color.white.opacity(0.94),
                bandInk: Color.black.opacity(0.82),
                family: .kodakRed
            )
        case "kodak_ultramax_400":
            FilmPackStyle(
                body: Color(red: 0.92, green: 0.48, blue: 0.10),
                band: Color(white: 0.08),
                accent: Color(white: 0.08),
                ink: Color.black.opacity(0.82),
                bandInk: Color.white.opacity(0.94),
                family: .kodakGold
            )
        case "fujifilm_xtra_400":
            FilmPackStyle(
                body: Color(red: 0.22, green: 0.62, blue: 0.22),
                band: Color.white.opacity(0.94),
                accent: Color(red: 0.12, green: 0.42, blue: 0.18),
                ink: Color.white.opacity(0.94),
                bandInk: Color.black.opacity(0.82),
                family: .fujiGreen
            )
        case "fujifilm_c200":
            FilmPackStyle(
                body: Color(red: 0.14, green: 0.48, blue: 0.78),
                band: Color.white.opacity(0.94),
                accent: Color(red: 0.08, green: 0.32, blue: 0.58),
                ink: Color.white.opacity(0.94),
                bandInk: Color.black.opacity(0.82),
                family: .fujiCyan
            )
        case "fujifilm_pro_400h":
            FilmPackStyle(
                body: Color(red: 0.12, green: 0.32, blue: 0.30),
                band: Color(white: 0.78),
                accent: Color(white: 0.55),
                ink: Color.white.opacity(0.92),
                bandInk: Color.black.opacity(0.82),
                family: .fujiGray
            )
        case "cinestill_800t":
            FilmPackStyle(
                body: Color(white: 0.08),
                band: Color(red: 0.78, green: 0.12, blue: 0.12),
                accent: Color(red: 0.78, green: 0.12, blue: 0.12),
                ink: Color.white.opacity(0.92),
                bandInk: Color.white.opacity(0.94),
                family: .cineStill
            )
        case "kodak_ektachrome_100":
            FilmPackStyle(
                body: Color(red: 0.96, green: 0.82, blue: 0.10),
                band: Color(red: 0.10, green: 0.52, blue: 0.70),
                accent: Color(red: 0.10, green: 0.52, blue: 0.70),
                ink: Color.black.opacity(0.82),
                bandInk: Color.white.opacity(0.94),
                family: .kodakGold
            )
        case "kodak_kodachrome_64":
            FilmPackStyle(
                body: Color(red: 0.78, green: 0.12, blue: 0.12),
                band: Color(red: 0.96, green: 0.80, blue: 0.12),
                accent: Color(red: 0.96, green: 0.80, blue: 0.12),
                ink: Color.white.opacity(0.94),
                bandInk: Color.black.opacity(0.82),
                family: .kodakRed
            )
        case "fujifilm_velvia_100":
            FilmPackStyle(
                body: Color(red: 0.72, green: 0.08, blue: 0.12),
                band: Color.white.opacity(0.94),
                accent: Color(red: 0.18, green: 0.52, blue: 0.22),
                ink: Color.white.opacity(0.94),
                bandInk: Color.black.opacity(0.82),
                family: .fujiRed
            )
        case "fujifilm_provia_100f":
            FilmPackStyle(
                body: Color(red: 0.62, green: 0.64, blue: 0.68),
                band: Color.white.opacity(0.94),
                accent: Color(red: 0.18, green: 0.38, blue: 0.62),
                ink: Color.black.opacity(0.78),
                bandInk: Color.black.opacity(0.82),
                family: .fujiGray
            )
        case "kodak_vision3_50d":
            vision(Color(red: 0.10, green: 0.42, blue: 0.48))
        case "kodak_vision3_250d":
            vision(Color(red: 0.12, green: 0.52, blue: 0.56))
        case "kodak_vision3_200t":
            vision(Color(red: 0.16, green: 0.32, blue: 0.62))
        case "kodak_vision3_500t":
            vision(Color(red: 0.28, green: 0.18, blue: 0.48))
        case "kodak_verita_200d":
            vision(Color(red: 0.14, green: 0.52, blue: 0.40))
        case "fujifilm_neopan_acros_100_ii":
            FilmPackStyle(
                body: Color(white: 0.08),
                band: Color.white.opacity(0.92),
                accent: Color(red: 0.18, green: 0.52, blue: 0.22),
                ink: Color.white.opacity(0.92),
                bandInk: Color.black.opacity(0.82),
                family: .fujiBW
            )
        case "kodak_tmax_100":
            FilmPackStyle(
                body: Color(white: 0.08),
                band: Color.white.opacity(0.92),
                accent: Color(red: 0.96, green: 0.80, blue: 0.12),
                ink: Color.white.opacity(0.92),
                bandInk: Color.black.opacity(0.82),
                family: .kodakBW
            )
        case "kodak_tri_x_400":
            FilmPackStyle(
                body: Color(white: 0.08),
                band: Color(red: 0.96, green: 0.80, blue: 0.12),
                accent: Color(red: 0.96, green: 0.80, blue: 0.12),
                ink: Color.white.opacity(0.92),
                bandInk: Color.black.opacity(0.82),
                family: .kodakBW
            )
        case "ilford_hp5_plus_400":
            FilmPackStyle(
                body: Color(white: 0.08),
                band: Color.white.opacity(0.92),
                accent: Color(red: 0.96, green: 0.80, blue: 0.12),
                ink: Color.white.opacity(0.92),
                bandInk: Color.black.opacity(0.82),
                family: .ilfordBW
            )
        default:
            gold(Color(red: 0.82, green: 0.62, blue: 0.22))
        }
    }

    private static func gold(_ body: Color) -> FilmPackStyle {
        FilmPackStyle(
            body: body,
            band: Color(red: 0.28, green: 0.16, blue: 0.08),
            accent: Color(red: 0.28, green: 0.16, blue: 0.08),
            ink: Color.black.opacity(0.82),
            bandInk: Color.white.opacity(0.94),
            family: .kodakGold
        )
    }

    private static func vision(_ band: Color) -> FilmPackStyle {
        FilmPackStyle(
            body: Color(red: 0.12, green: 0.13, blue: 0.14),
            band: band,
            accent: Color(white: 0.62),
            ink: Color.white.opacity(0.92),
            bandInk: Color.white.opacity(0.94),
            family: .visionCan
        )
    }
}

struct FilmRecipe: Identifiable, Hashable {
    var id: String
    var name: String
    var subtitle: String
    var iso: Int
    var pack: Color
    var grainSize: Float
    var process: FilmProcess = .c41
    var group: FilmGroup = .color
    var papers: [String] = PaperCatalog.kodak
    var defaultPaperId: String = "kodak_portra_endura"

    var grain: GrainLevel {
        if grainSize < 0.45 { return .fine }
        if grainSize < 0.75 { return .medium }
        return .coarse
    }

    var packStyle: FilmPackStyle { FilmPackStyle.resolved(id: id) }

    var packInk: Color { packStyle.ink }

    var leaderColor: Color {
        switch process {
        case .c41: Color(red: 0.82, green: 0.55, blue: 0.18)
        case .e6: Color(red: 0.28, green: 0.12, blue: 0.08)
        case .cine: Color(red: 0.18, green: 0.52, blue: 0.58)
        case .bw: Color(white: 0.55)
        }
    }

    var silverCassette: Bool { process == .e6 }
}

enum FilmProcess {
    case c41, e6, cine, bw
}

enum FilmGroup: String, CaseIterable, Identifiable {
    case color, slide, cine, bw
    var id: String { rawValue }
    var title: String {
        switch self {
        case .color: L("彩色")
        case .slide: L("反转片")
        case .cine: L("电影")
        case .bw: L("黑白")
        }
    }
}

enum PaperCatalog {
    static let kodak = [
        "kodak_portra_endura",
        "kodak_endura_premier",
        "kodak_supra_endura",
        "kodak_ultra_endura",
        "kodak_ektacolor_edge"
    ]
    static let fuji = [
        "fujifilm_crystal_archive_typeii",
        "kodak_portra_endura"
    ]
    static let cine = [
        "kodak_2383",
        "kodak_2393"
    ]
    static let bw = [
        "ilford_multigrade_iv_rc"
    ]

    static func name(_ id: String) -> String {
        switch id {
        case "kodak_portra_endura": "Endura"
        case "kodak_endura_premier": "Premier"
        case "kodak_supra_endura": "Supra"
        case "kodak_ultra_endura": "Ultra"
        case "kodak_ektacolor_edge": "Edge"
        case "fujifilm_crystal_archive_typeii": "Crystal"
        case "kodak_2383": "2383"
        case "kodak_2393": "2393"
        case "ilford_multigrade_iv_rc": "MG IV"
        default: id
        }
    }

    static func blurb(_ id: String) -> String {
        switch id {
        case "kodak_portra_endura": L("柔和肤色 · 人像")
        case "kodak_endura_premier": L("通透 · 高光")
        case "kodak_supra_endura": L("硬调 · 饱和")
        case "kodak_ultra_endura": L("高反差 · 鲜艳")
        case "kodak_ektacolor_edge": L("日常 · 偏暖")
        case "fujifilm_crystal_archive_typeii": L("富士纸 · 青冷")
        case "kodak_2383": L("电影印片 · 低饱和")
        case "kodak_2393": L("电影印片 · 硬调")
        case "ilford_multigrade_iv_rc": L("中性 · 黑白")
        default: ""
        }
    }
}

enum CameraFilter: String, CaseIterable, Identifiable {
    case none = ""
    case yellow = "w8"
    case orange = "w21"
    case red = "w25"
    var id: String { rawValue }
    var title: String {
        switch self {
        case .none: L("无")
        case .yellow: L("黄")
        case .orange: L("橙")
        case .red: L("红")
        }
    }
}

enum FilmCatalog {
    static let aliases: [String: String] = [
        "provia": "fujifilm_provia_100f",
        "astia": "kodak_ektachrome_100",
        "velvia": "fujifilm_velvia_100",
        "classicChrome": "kodak_portra_160",
        "realaAce": "fujifilm_xtra_400",
        "proNegStd": "kodak_portra_400",
        "proNegHi": "kodak_portra_800",
        "nostalgicNeg": "kodak_gold_200",
        "eterna": "kodak_vision3_250d",
        "eternaBB": "cinestill_800t",
        "acros": "fujifilm_neopan_acros_100_ii",
        "superia400": "fujifilm_xtra_400",
        "pro400h": "kodak_portra_400",
        "velvia50": "fujifilm_velvia_100",
        "provia100f": "fujifilm_provia_100f",
        "astia100": "kodak_ektachrome_100",
        "classicNeg": "kodak_gold_200",
        "acros100": "fujifilm_neopan_acros_100_ii",
        "eterna250": "kodak_vision3_250d"
    ]

    static let all: [FilmRecipe] = [
        stock(look.provia, id: "fujifilm_provia_100f", name: "PROVIA 100F", subtitle: "通透 · 万能", iso: 100,
              pack: Color(red: 0.55, green: 0.58, blue: 0.62), process: .e6, group: .slide, papers: [], paper: "kodak_portra_endura"),
        stock(look.astia, id: "kodak_ektachrome_100", name: "EKTACHROME 100", subtitle: "鲜明 · 通用", iso: 100,
              pack: Color(red: 0.92, green: 0.78, blue: 0.22), process: .e6, group: .slide, papers: [], paper: "kodak_portra_endura"),
        stock(look.velvia, id: "fujifilm_velvia_100", name: "VELVIA 100", subtitle: "浓彩 · 风景", iso: 100,
              pack: Color(red: 0.78, green: 0.12, blue: 0.16), process: .e6, group: .slide, papers: [], paper: "kodak_portra_endura"),
        stock(look.astia, id: "kodak_kodachrome_64", name: "KODACHROME 64", subtitle: "经典 · 暖调", iso: 64,
              pack: Color(red: 0.72, green: 0.18, blue: 0.16), process: .e6, group: .slide, papers: [], paper: "kodak_portra_endura"),

        stock(look.classicChrome, id: "kodak_portra_160", name: "PORTRA 160", subtitle: "柔和 · 人像", iso: 160,
              pack: Color(red: 0.78, green: 0.62, blue: 0.32), process: .c41, group: .color, papers: PaperCatalog.kodak, paper: "kodak_portra_endura"),
        stock(look.proNegStd, id: "kodak_portra_400", name: "PORTRA 400", subtitle: "低反差 · 人像", iso: 400,
              pack: Color(red: 0.72, green: 0.52, blue: 0.22), process: .c41, group: .color, papers: PaperCatalog.kodak, paper: "kodak_portra_endura"),
        stock(look.proNegHi, id: "kodak_portra_800", name: "PORTRA 800", subtitle: "低光 · 人像", iso: 800,
              pack: Color(red: 0.55, green: 0.32, blue: 0.14), process: .c41, group: .color, papers: PaperCatalog.kodak, paper: "kodak_portra_endura"),
        stock(look.proNegHi, id: "kodak_portra_800_push1", name: "PORTRA 800 +1", subtitle: "推一档", iso: 1600,
              pack: Color(red: 0.48, green: 0.26, blue: 0.12), process: .c41, group: .color, papers: PaperCatalog.kodak, paper: "kodak_portra_endura", grainSize: 0.70),
        stock(look.proNegHi, id: "kodak_portra_800_push2", name: "PORTRA 800 +2", subtitle: "推两档", iso: 3200,
              pack: Color(red: 0.40, green: 0.20, blue: 0.10), process: .c41, group: .color, papers: PaperCatalog.kodak, paper: "kodak_portra_endura", grainSize: 0.82),
        stock(look.nostalgicNeg, id: "kodak_gold_200", name: "GOLD 200", subtitle: "琥珀 · 日常", iso: 200,
              pack: Color(red: 0.90, green: 0.72, blue: 0.18), process: .c41, group: .color, papers: PaperCatalog.kodak, paper: "kodak_portra_endura"),
        stock(look.velvia, id: "kodak_ektar_100", name: "EKTAR 100", subtitle: "浓彩 · 细腻", iso: 100,
              pack: Color(red: 0.86, green: 0.22, blue: 0.16), process: .c41, group: .color, papers: PaperCatalog.kodak, paper: "kodak_portra_endura", grainSize: 0.36),
        stock(look.realaAce, id: "kodak_ultramax_400", name: "ULTRAMAX 400", subtitle: "饱和 · 日常", iso: 400,
              pack: Color(red: 0.88, green: 0.42, blue: 0.12), process: .c41, group: .color, papers: PaperCatalog.kodak, paper: "kodak_portra_endura", grainSize: 0.62),
        stock(look.realaAce, id: "fujifilm_xtra_400", name: "SUPERIA 400", subtitle: "青绿 · 日常", iso: 400,
              pack: Color(red: 0.42, green: 0.68, blue: 0.22), process: .c41, group: .color, papers: PaperCatalog.fuji, paper: "fujifilm_crystal_archive_typeii"),
        stock(look.nostalgicNeg, id: "fujifilm_c200", name: "C200", subtitle: "轻快 · 日常", iso: 200,
              pack: Color(red: 0.22, green: 0.52, blue: 0.78), process: .c41, group: .color, papers: PaperCatalog.fuji, paper: "fujifilm_crystal_archive_typeii", grainSize: 0.52),
        stock(look.proNegStd, id: "fujifilm_pro_400h", name: "PRO 400H", subtitle: "青冷 · 人像", iso: 400,
              pack: Color(red: 0.18, green: 0.42, blue: 0.38), process: .c41, group: .color, papers: PaperCatalog.fuji, paper: "fujifilm_crystal_archive_typeii"),
        stock(look.eternaBB, id: "cinestill_800t", name: "CINESTILL 800T", subtitle: "钨灯 · 夜色", iso: 800,
              pack: Color(red: 0.82, green: 0.28, blue: 0.12), process: .c41, group: .color, papers: PaperCatalog.cine, paper: "kodak_2383"),

        stock(look.eterna, id: "kodak_vision3_50d", name: "VISION3 50D", subtitle: "日光 · 细腻", iso: 50,
              pack: Color(red: 0.10, green: 0.34, blue: 0.42), process: .cine, group: .cine, papers: PaperCatalog.cine, paper: "kodak_2383", grainSize: 0.42),
        stock(look.eterna, id: "kodak_vision3_250d", name: "VISION3 250D", subtitle: "低反差 · 电影", iso: 250,
              pack: Color(red: 0.12, green: 0.42, blue: 0.48), process: .cine, group: .cine, papers: PaperCatalog.cine, paper: "kodak_2383"),
        stock(look.eterna, id: "kodak_vision3_200t", name: "VISION3 200T", subtitle: "钨灯 · 电影", iso: 200,
              pack: Color(red: 0.16, green: 0.28, blue: 0.46), process: .cine, group: .cine, papers: PaperCatalog.cine, paper: "kodak_2383", grainSize: 0.58),
        stock(look.eternaBB, id: "kodak_vision3_500t", name: "VISION3 500T", subtitle: "钨灯 · 夜戏", iso: 500,
              pack: Color(red: 0.22, green: 0.18, blue: 0.38), process: .cine, group: .cine, papers: PaperCatalog.cine, paper: "kodak_2383", grainSize: 0.72),
        stock(look.eterna, id: "kodak_verita_200d", name: "VERITA 200D", subtitle: "日光 · 电影", iso: 200,
              pack: Color(red: 0.14, green: 0.48, blue: 0.40), process: .cine, group: .cine, papers: PaperCatalog.cine, paper: "kodak_2383", grainSize: 0.54),

        stock(look.acros, id: "fujifilm_neopan_acros_100_ii", name: "ACROS 100 II", subtitle: "细腻 · 黑白", iso: 100,
              pack: Color(red: 0.12, green: 0.12, blue: 0.12), process: .bw, group: .bw, papers: PaperCatalog.bw, paper: "ilford_multigrade_iv_rc"),
        stock(look.acros, id: "kodak_tmax_100", name: "T-MAX 100", subtitle: "锐利 · 黑白", iso: 100,
              pack: Color(red: 0.18, green: 0.18, blue: 0.18), process: .bw, group: .bw, papers: PaperCatalog.bw, paper: "ilford_multigrade_iv_rc", grainSize: 0.38),
        stock(look.acros, id: "kodak_tri_x_400", name: "TRI-X 400", subtitle: "粗粒 · 街拍", iso: 400,
              pack: Color(red: 0.22, green: 0.16, blue: 0.10), process: .bw, group: .bw, papers: PaperCatalog.bw, paper: "ilford_multigrade_iv_rc", grainSize: 0.78),
        stock(look.acros, id: "ilford_hp5_plus_400", name: "HP5 PLUS 400", subtitle: "宽容 · 黑白", iso: 400,
              pack: Color(red: 0.16, green: 0.16, blue: 0.16), process: .bw, group: .bw, papers: PaperCatalog.bw, paper: "ilford_multigrade_iv_rc", grainSize: 0.70)
    ]

    static func films(in group: FilmGroup) -> [FilmRecipe] {
        all.filter { $0.group == group }
    }

    static func recipe(id: String) -> FilmRecipe {
        let resolved = aliases[id] ?? id
        return all.first { $0.id == resolved } ?? all.first { $0.id == "kodak_portra_400" } ?? all[0]
    }

    static func spkFilm(id: String) -> String {
        recipe(id: id).id
    }

    static func spkPaper(id: String, paperId: String = "") -> String {
        let film = recipe(id: id)
        if !paperId.isEmpty, film.papers.contains(paperId) || film.papers.isEmpty {
            return paperId
        }
        return film.defaultPaperId
    }

    static func spkScanFilm(id: String) -> Bool {
        recipe(id: id).process == .e6
    }

    private static func stock(
        _ look: FilmRecipe,
        id: String,
        name: String,
        subtitle: String,
        iso: Int,
        pack _: Color,
        process: FilmProcess,
        group: FilmGroup,
        papers: [String],
        paper: String,
        grainSize: Float? = nil
    ) -> FilmRecipe {
        var rec = look
        rec.id = id
        rec.name = name
        rec.subtitle = subtitle
        rec.iso = iso
        rec.pack = FilmPackStyle.resolved(id: id).mark
        rec.process = process
        rec.group = group
        rec.papers = papers
        rec.defaultPaperId = paper
        if let grainSize { rec.grainSize = grainSize }
        return rec
    }

    private enum look {
        static let provia = FilmRecipe(
            id: "provia", name: "PROVIA 100F", subtitle: "通透 · 万能", iso: 100,
            pack: Color(red: 0.55, green: 0.58, blue: 0.62), grainSize: 0.40
        )
        static let astia = FilmRecipe(
            id: "astia", name: "EKTACHROME 100", subtitle: "鲜明 · 通用", iso: 100,
            pack: Color(red: 0.92, green: 0.78, blue: 0.22), grainSize: 0.40
        )
        static let velvia = FilmRecipe(
            id: "velvia", name: "VELVIA 100", subtitle: "浓彩 · 风景", iso: 100,
            pack: Color(red: 0.78, green: 0.12, blue: 0.16), grainSize: 0.32
        )
        static let classicChrome = FilmRecipe(
            id: "classicChrome", name: "PORTRA 160", subtitle: "柔和 · 人像", iso: 160,
            pack: Color(red: 0.78, green: 0.62, blue: 0.32), grainSize: 0.70
        )
        static let realaAce = FilmRecipe(
            id: "realaAce", name: "SUPERIA 400", subtitle: "青绿 · 日常", iso: 400,
            pack: Color(red: 0.42, green: 0.68, blue: 0.22), grainSize: 0.55
        )
        static let proNegStd = FilmRecipe(
            id: "proNegStd", name: "PORTRA 400", subtitle: "低反差 · 人像", iso: 400,
            pack: Color(red: 0.72, green: 0.52, blue: 0.22), grainSize: 0.48
        )
        static let proNegHi = FilmRecipe(
            id: "proNegHi", name: "PORTRA 800", subtitle: "低光 · 人像", iso: 800,
            pack: Color(red: 0.55, green: 0.32, blue: 0.14), grainSize: 0.62
        )
        static let nostalgicNeg = FilmRecipe(
            id: "nostalgicNeg", name: "GOLD 200", subtitle: "琥珀 · 日常", iso: 200,
            pack: Color(red: 0.90, green: 0.72, blue: 0.18), grainSize: 0.72
        )
        static let eterna = FilmRecipe(
            id: "eterna", name: "VISION3 250D", subtitle: "低反差 · 电影", iso: 250,
            pack: Color(red: 0.12, green: 0.42, blue: 0.48), grainSize: 0.62
        )
        static let eternaBB = FilmRecipe(
            id: "eternaBB", name: "CINESTILL 800T", subtitle: "钨灯 · 夜色", iso: 800,
            pack: Color(red: 0.82, green: 0.28, blue: 0.12), grainSize: 0.70
        )
        static let acros = FilmRecipe(
            id: "acros", name: "ACROS 100 II", subtitle: "细腻 · 黑白", iso: 100,
            pack: Color(red: 0.12, green: 0.12, blue: 0.12), grainSize: 0.34
        )
    }
}
