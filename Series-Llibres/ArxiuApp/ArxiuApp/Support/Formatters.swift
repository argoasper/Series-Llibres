import Foundation

enum Formatters {
    /// Format demanat per a la data d'acabament: 2026/08.
    static let yearMonth: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy/MM"
        return f
    }()

    static func yearMonthString(_ date: Date?) -> String? {
        guard let date else { return nil }
        return yearMonth.string(from: date)
    }

    /// Converteix "2026/08" en una data (dia 1 d'aquell mes).
    static func date(fromYearMonth text: String) -> Date? {
        yearMonth.date(from: text.trimmingCharacters(in: .whitespaces))
    }
}
