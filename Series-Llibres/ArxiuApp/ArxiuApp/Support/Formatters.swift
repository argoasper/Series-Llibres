import Foundation

enum Formatters {
    /// Format demanat per a la data d'acabament: 2026/08.
    static let yearMonth: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy/MM"
        f.isLenient = false
        return f
    }()

    static func yearMonthString(_ date: Date?) -> String? {
        guard let date else { return nil }
        return yearMonth.string(from: date)
    }

    /// Converteix "2026/08" en una data (dia 1 d'aquell mes).
    /// Retorna `nil` si el text no és un any i un mes vàlids: qui la crida
    /// ha de tractar el `nil` com un error, mai substituir-lo per la data d'avui.
    static func date(fromYearMonth text: String) -> Date? {
        let clean = text.trimmingCharacters(in: .whitespaces)
        guard clean.count == 7, let date = yearMonth.date(from: clean) else { return nil }
        return date
    }

    /// Dates completes dins dels JSON de còpia de seguretat.
    static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    /// Marca de temps per als noms de les còpies automàtiques: 20260904-1613.
    static let fileStamp: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyyMMdd-HHmm"
        return f
    }()
}
