import Foundation

/// Aracin uzerinde hasar alabilen bolgeler. Cizimde vurgulanan parca budur.
enum CarPart: String, Equatable {
    case frontWingLeft, frontWingRight, rearWing, floor, diffuser, sidepod
    case gearBox, engine
    case tyreFL, tyreFR, tyreRL, tyreRR

    var title: String {
        switch self {
        case .frontWingLeft: return "ÖN KANAT SOL"
        case .frontWingRight: return "ÖN KANAT SAĞ"
        case .rearWing: return "ARKA KANAT"
        case .floor: return "ZEMİN"
        case .diffuser: return "DİFÜZÖR"
        case .sidepod: return "SIDEPOD"
        case .gearBox: return "ŞANZIMAN"
        case .engine: return "MOTOR"
        case .tyreFL: return "LASTİK FL"
        case .tyreFR: return "LASTİK FR"
        case .tyreRL: return "LASTİK RL"
        case .tyreRR: return "LASTİK RR"
        }
    }
}

/// Yeni alinan hasar. Ekranda kisa sure gorunup kaybolur.
struct DamageAlert: Equatable {
    let part: CarPart
    /// Parcanin guncel toplam hasari (yuzde)
    let total: Int
    /// Bu darbede eklenen hasar (yuzde)
    let delta: Int
    let date: Date

    var isSevere: Bool { delta >= 10 || total >= 40 }
}
