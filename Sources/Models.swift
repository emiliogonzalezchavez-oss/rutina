import Foundation

// MARK: - Helpers

extension KeyedDecodingContainer {
    /// Lee un valor si existe; si no, usa el de default (así las actualizaciones no borran tus datos).
    func v<T: Decodable>(_ key: Key, _ fallback: T) -> T {
        (try? decodeIfPresent(T.self, forKey: key)) ?? fallback
    }
}

enum Fecha {
    static let keyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func key(_ d: Date) -> String { keyFormatter.string(from: d) }

    static func date(_ key: String) -> Date? { keyFormatter.date(from: key) }

    static func add(days: Int, to d: Date) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: d) ?? d
    }

    /// Fecha con la hora puesta a partir de minutos desde medianoche.
    static func at(_ minutes: Int, on d: Date) -> Date {
        let start = Calendar.current.startOfDay(for: d)
        return start.addingTimeInterval(TimeInterval(minutes * 60))
    }

    static func hora(_ minutes: Int) -> String {
        var h = (minutes / 60) % 24
        let m = minutes % 60
        let ampm = h >= 12 ? "pm" : "am"
        h = h % 12
        if h == 0 { h = 12 }
        return String(format: "%d:%02d %@", h, m, ampm)
    }

    static func minutes(of d: Date) -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: d)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    static func daysBetween(_ a: Date, _ b: Date) -> Int {
        let cal = Calendar.current
        return cal.dateComponents([.day], from: cal.startOfDay(for: a), to: cal.startOfDay(for: b)).day ?? 0
    }

    static let nombreDia: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_MX")
        f.dateFormat = "EEEE d 'de' MMMM"
        return f
    }()
}

// MARK: - Ajustes

struct AppSettings: Codable {
    // Horario de días con escuela (minutos desde medianoche)
    var wake = 6 * 60 + 50
    var breakfast = 7 * 60 + 10
    var snack = 10 * 60 + 30
    var lunch = 15 * 60
    var preWorkout = 17 * 60 + 30
    var workout = 18 * 60
    var dinner = 19 * 60 + 45
    var shower = 20 * 60 + 30
    var summary = 21 * 60
    var startBed = 23 * 60 + 30      // de donde arranca la hora de dormir
    var targetBed = 21 * 60 + 30     // meta final
    var rampStart = Date()           // día en que arrancó el ajuste de sueño

    // Horario de días libres (sin escuela, fines de semana y vacaciones)
    var fWake = 9 * 60 + 30
    var fBreakfast = 10 * 60
    var fSnack = 12 * 60 + 30
    var fLunch = 15 * 60
    var fPreWorkout = 16 * 60 + 30
    var fWorkout = 17 * 60
    var fDinner = 19 * 60 + 45
    var fShower = 20 * 60 + 30
    var fSummary = 21 * 60
    var freeBedExtra = 30            // minutos más tarde para dormir en días libres
    var freeAlarm = true             // alarma suave en días libres

    var schoolDays: [Int] = [2, 3, 4, 5, 6]   // Calendar weekday: 1 = domingo ... 7 = sábado
    var freeDates: [String] = []              // días entre semana marcados como libres
    var vacationOn = false
    var vacationStart = Date()
    var vacationEnd = Date()
    var skipDates: [String] = []              // (versión vieja, ya no se usa)
    var forceDates: [String] = []             // (versión vieja, ya no se usa)

    var strongShower = true
    var strongBed = true
    var restSeconds = 120
    var proteinGoal = 120
    var dessertsPerWeek = 3
    var setupDone = false
    var geminiKey = ""

    init() {}
}

extension AppSettings {
    init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        wake = c.v(.wake, wake)
        breakfast = c.v(.breakfast, breakfast)
        snack = c.v(.snack, snack)
        lunch = c.v(.lunch, lunch)
        preWorkout = c.v(.preWorkout, preWorkout)
        workout = c.v(.workout, workout)
        dinner = c.v(.dinner, dinner)
        shower = c.v(.shower, shower)
        summary = c.v(.summary, summary)
        startBed = c.v(.startBed, startBed)
        targetBed = c.v(.targetBed, targetBed)
        rampStart = c.v(.rampStart, rampStart)
        fWake = c.v(.fWake, fWake)
        fBreakfast = c.v(.fBreakfast, fBreakfast)
        fSnack = c.v(.fSnack, fSnack)
        fLunch = c.v(.fLunch, fLunch)
        fPreWorkout = c.v(.fPreWorkout, fPreWorkout)
        fWorkout = c.v(.fWorkout, fWorkout)
        fDinner = c.v(.fDinner, fDinner)
        fShower = c.v(.fShower, fShower)
        fSummary = c.v(.fSummary, fSummary)
        freeBedExtra = c.v(.freeBedExtra, freeBedExtra)
        freeAlarm = c.v(.freeAlarm, freeAlarm)
        schoolDays = c.v(.schoolDays, schoolDays)
        freeDates = c.v(.freeDates, freeDates)
        vacationOn = c.v(.vacationOn, vacationOn)
        vacationStart = c.v(.vacationStart, vacationStart)
        vacationEnd = c.v(.vacationEnd, vacationEnd)
        skipDates = c.v(.skipDates, skipDates)
        forceDates = c.v(.forceDates, forceDates)
        strongShower = c.v(.strongShower, strongShower)
        strongBed = c.v(.strongBed, strongBed)
        restSeconds = c.v(.restSeconds, restSeconds)
        proteinGoal = c.v(.proteinGoal, proteinGoal)
        dessertsPerWeek = c.v(.dessertsPerWeek, dessertsPerWeek)
        setupDone = c.v(.setupDone, setupDone)
        geminiKey = c.v(.geminiKey, geminiKey)
    }
}

// MARK: - Registro del día

struct SetLog: Codable, Identifiable, Hashable {
    var id = UUID()
    var exercise: String
    var weight: Double = 0
    var reps: Int = 0
    var seconds: Int = 0
    var date = Date()
}

enum Comida: String, CaseIterable, Codable, Identifiable {
    case desayuno, snack, comida, preentreno, cena
    var id: String { rawValue }
    var titulo: String {
        switch self {
        case .desayuno: return "Desayuno"
        case .snack: return "Snack"
        case .comida: return "Comida"
        case .preentreno: return "Snack antes de entrenar"
        case .cena: return "Cena"
        }
    }
    var emoji: String {
        switch self {
        case .desayuno: return "🍳"
        case .snack: return "🥪"
        case .comida: return "🍛"
        case .preentreno: return "🍌"
        case .cena: return "🌮"
        }
    }
}

struct DayLog: Codable, Identifiable {
    var id: String = ""
    var sleepHours: Double = 0          // 0 = no registrado
    var meals: [String: Bool] = [:]     // Comida.rawValue -> la comiste
    var protein: Int = 0
    var fruits: Int = 0
    var salad = false
    var trained = false
    var desserts = 0
    var shower = false
    var screensOff = false
    var elbowPain = false
    var closed = false
    var note = ""
    var sets: [SetLog] = []

    init(id: String = "") { self.id = id }

    var mealsEaten: Int { Comida.allCases.filter { meals[$0.rawValue] == true }.count }
}

extension DayLog {
    init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.v(.id, id)
        sleepHours = c.v(.sleepHours, sleepHours)
        meals = c.v(.meals, meals)
        protein = c.v(.protein, protein)
        fruits = c.v(.fruits, fruits)
        salad = c.v(.salad, salad)
        trained = c.v(.trained, trained)
        desserts = c.v(.desserts, desserts)
        shower = c.v(.shower, shower)
        screensOff = c.v(.screensOff, screensOff)
        elbowPain = c.v(.elbowPain, elbowPain)
        closed = c.v(.closed, closed)
        note = c.v(.note, note)
        sets = c.v(.sets, sets)
    }
}

// MARK: - Cuerpo

struct BodyEntry: Codable, Identifiable, Hashable {
    var id = UUID()
    var date = Date()
    var weightKg: Double
    var heightCm: Double
}

struct SaveData: Codable {
    var settings = AppSettings()
    var logs: [String: DayLog] = [:]
    var bodyEntries: [BodyEntry] = []

    init() {}
}

extension SaveData {
    init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        settings = c.v(.settings, settings)
        logs = c.v(.logs, logs)
        bodyEntries = c.v(.bodyEntries, bodyEntries)
    }
}
