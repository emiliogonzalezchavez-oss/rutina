import Foundation
import SwiftUI
import UserNotifications

enum Pestana: Hashable { case hoy, entreno, cierre, progreso, ajustes }

struct ItemHorario: Identifiable {
    let id = UUID()
    let minutos: Int
    let emoji: String
    let titulo: String
    let detalle: String
}

/// Horario que aplica a un día (escuela o libre).
struct Perfil {
    let libre: Bool
    let wake: Int
    let breakfast: Int
    let snack: Int
    let lunch: Int
    let preWorkout: Int
    let workout: Int
    let dinner: Int
    let shower: Int
    let summary: Int
    let bed: Int
    let alarma: Bool
}

@MainActor
final class Store: ObservableObject {
    static let shared = Store()

    @Published var settings: AppSettings
    @Published var logs: [String: DayLog]
    @Published var bodyEntries: [BodyEntry]
    @Published var tab: Pestana = .hoy

    // Temporizador de descanso
    @Published var restEnd: Date?
    @Published var restAlarmID: UUID?

    private var rebuildTask: Task<Void, Never>?

    private static var fileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("rutina.json")
    }

    init() {
        var data = SaveData()
        if let raw = try? Data(contentsOf: Store.fileURL),
           let decoded = try? JSONDecoder().decode(SaveData.self, from: raw) {
            data = decoded
        }
        settings = data.settings
        logs = data.logs
        bodyEntries = data.bodyEntries
    }

    func save() {
        var data = SaveData()
        data.settings = settings
        data.logs = logs
        data.bodyEntries = bodyEntries
        if let raw = try? JSONEncoder().encode(data) {
            try? raw.write(to: Store.fileURL, options: .atomic)
        }
    }

    // MARK: Registro

    func log(_ date: Date) -> DayLog {
        let k = Fecha.key(date)
        return logs[k] ?? DayLog(id: k)
    }

    func binding(_ date: Date) -> Binding<DayLog> {
        let k = Fecha.key(date)
        return Binding(
            get: { self.logs[k] ?? DayLog(id: k) },
            set: { self.logs[k] = $0; self.save() })
    }

    func addProtein(_ g: Int, _ date: Date = Date()) {
        var l = log(date)
        l.protein = max(0, l.protein + g)
        logs[l.id] = l
        save()
    }

    func addSet(_ s: SetLog) {
        var l = log(Date())
        l.sets.append(s)
        logs[l.id] = l
        save()
    }

    func deleteSet(_ s: SetLog) {
        var l = log(s.date)
        l.sets.removeAll { $0.id == s.id }
        logs[l.id] = l
        save()
    }

    /// Series de la última sesión anterior a hoy de ese ejercicio.
    func ultimaSesion(_ ejercicio: String) -> [SetLog] {
        let hoy = Fecha.key(Date())
        let keys = logs.keys.filter { $0 < hoy }.sorted(by: >)
        for k in keys {
            let s = logs[k]?.sets.filter { $0.exercise == ejercicio } ?? []
            if !s.isEmpty { return s }
        }
        return []
    }

    func seriesHoy(_ ejercicio: String) -> [SetLog] {
        log(Date()).sets.filter { $0.exercise == ejercicio }
    }

    func sugerenciaProgreso(_ e: Ejercicio) -> String? {
        let ult = ultimaSesion(e.nombre)
        guard !ult.isEmpty else { return nil }
        let completo = ult.count >= e.series
        switch e.tipo {
        case .lastre:
            if completo && ult.allSatisfy({ $0.reps >= e.maxReps }) {
                return "🔼 La vez pasada completaste todo. Súbele 1–2 kg."
            }
        case .reps:
            if completo && ult.allSatisfy({ $0.reps >= e.maxReps }) {
                return "🔼 Completaste el máximo. Pasa a una variante más difícil."
            }
        case .hold:
            if completo && ult.allSatisfy({ $0.seconds >= e.maxReps }) {
                return "🔼 Ya dominas este nivel. Pasa a la siguiente progresión."
            }
        }
        return nil
    }

    // MARK: Postres y rachas

    func postresSemana(_ date: Date = Date()) -> Int {
        var cal = Calendar.current
        cal.firstWeekday = 2
        guard let semana = cal.dateInterval(of: .weekOfYear, for: date) else { return 0 }
        var total = 0
        var d = semana.start
        while d < semana.end {
            total += log(d).desserts
            d = Fecha.add(days: 1, to: d)
        }
        return total
    }

    func puntaje(_ l: DayLog, _ date: Date) -> Int {
        var p = 0, t = 0
        t += 1; if l.sleepHours >= 8.5 { p += 1 }
        t += 1; if l.mealsEaten >= 4 { p += 1 }
        t += 1; if l.protein >= settings.proteinGoal - 10 { p += 1 }
        t += 1; if l.fruits >= 2 { p += 1 }
        t += 1; if l.salad { p += 1 }
        if Plan.esDiaDeEntreno(date) { t += 1; if l.trained { p += 1 } }
        return t == 0 ? 0 : Int(Double(p) / Double(t) * 100)
    }

    func racha() -> Int {
        var n = 0
        var d = Date()
        if !log(d).closed { d = Fecha.add(days: -1, to: d) }
        while true {
            let l = log(d)
            if l.closed && puntaje(l, d) >= 70 { n += 1 } else { break }
            d = Fecha.add(days: -1, to: d)
        }
        return n
    }

    // MARK: Sueño

    func horaDormir(_ date: Date) -> Int {
        let dias = max(0, Fecha.daysBetween(settings.rampStart, date))
        let escalones = dias / 4
        return max(settings.targetBed, settings.startBed - 30 * escalones)
    }

    func reiniciarSueno(desde minutos: Int) {
        settings.startBed = minutos
        settings.rampStart = Date()
        save()
        reprogramarTodo()
    }

    // MARK: Escuela, días libres y vacaciones

    func enVacaciones(_ date: Date) -> Bool {
        guard settings.vacationOn else { return false }
        let cal = Calendar.current
        let d = cal.startOfDay(for: date)
        return d >= cal.startOfDay(for: settings.vacationStart) && d <= cal.startOfDay(for: settings.vacationEnd)
    }

    func esLibre(_ date: Date) -> Bool {
        if enVacaciones(date) { return true }
        if settings.freeDates.contains(Fecha.key(date)) { return true }
        let w = Calendar.current.component(.weekday, from: date)
        return !settings.schoolDays.contains(w)
    }

    func perfil(_ date: Date) -> Perfil {
        let s = settings
        if esLibre(date) {
            return Perfil(libre: true, wake: s.fWake, breakfast: s.fBreakfast, snack: s.fSnack, lunch: s.fLunch,
                          preWorkout: s.fPreWorkout, workout: s.fWorkout, dinner: s.fDinner, shower: s.fShower,
                          summary: s.fSummary, bed: horaDormir(date) + s.freeBedExtra, alarma: s.freeAlarm)
        }
        return Perfil(libre: false, wake: s.wake, breakfast: s.breakfast, snack: s.snack, lunch: s.lunch,
                      preWorkout: s.preWorkout, workout: s.workout, dinner: s.dinner, shower: s.shower,
                      summary: s.summary, bed: horaDormir(date), alarma: true)
    }

    func hayAlarma(_ date: Date) -> Bool { perfil(date).alarma }

    func setEscuela(_ date: Date, _ escuela: Bool) {
        let k = Fecha.key(date)
        settings.freeDates.removeAll { $0 == k }
        if !escuela { settings.freeDates.append(k) }
        let viejo = Fecha.key(Fecha.add(days: -14, to: Date()))
        settings.freeDates.removeAll { $0 < viejo }
        save()
        reprogramarTodo()
    }

    /// Botones de la notificación de la noche: ¿mañana hay escuela?
    func alarmaManana(_ escuela: Bool) async {
        let k = Fecha.key(Fecha.add(days: 1, to: Date()))
        settings.freeDates.removeAll { $0 == k }
        if !escuela { settings.freeDates.append(k) }
        save()
        reprogramarAvisos()
        await reprogramarAlarmas()
    }

    // MARK: Horario del día

    func horario(_ date: Date) -> [ItemHorario] {
        let p = perfil(date)
        let plan = Plan.dia(date)
        var items: [ItemHorario] = []
        if p.alarma {
            items.append(.init(minutos: p.wake, emoji: p.libre ? "☀️" : "⏰", titulo: "Despertar",
                               detalle: p.libre ? "Día libre: alarma suave" : "Día de escuela"))
        }
        items.append(.init(minutos: p.breakfast, emoji: "🍳", titulo: "Desayuno", detalle: MenuPlan.de(.desayuno, date)))
        items.append(.init(minutos: p.snack, emoji: "🥪", titulo: "Snack", detalle: MenuPlan.de(.snack, date)))
        items.append(.init(minutos: p.lunch, emoji: "🍛", titulo: "Comida", detalle: MenuPlan.de(.comida, date)))
        if plan.tipo != .descanso {
            items.append(.init(minutos: p.preWorkout, emoji: "🍌", titulo: "Snack antes de entrenar", detalle: MenuPlan.de(.preentreno, date)))
            items.append(.init(minutos: p.workout, emoji: plan.emoji, titulo: plan.titulo, detalle: plan.nota))
        }
        items.append(.init(minutos: p.dinner, emoji: "🌮", titulo: "Cena", detalle: MenuPlan.de(.cena, date)))
        items.append(.init(minutos: p.shower, emoji: "🚿", titulo: "Baño", detalle: "Agua caliente: te ayuda a dormir más rápido"))
        items.append(.init(minutos: p.summary, emoji: "🌙", titulo: "Cierre del día", detalle: "Llena qué hiciste hoy"))
        items.append(.init(minutos: p.bed - 15, emoji: "📵", titulo: "Fuera pantallas", detalle: ""))
        items.append(.init(minutos: p.bed, emoji: "😴", titulo: "Dormir", detalle: "Meta final: \(Fecha.hora(settings.targetBed))"))
        return items.sorted { $0.minutos < $1.minutos }
    }

    // MARK: Sugerencias del cierre

    func sugerencias(_ date: Date) -> [String] {
        let l = log(date)
        var out: [String] = []
        let cama = perfil(date).bed
        if l.sleepHours > 0 && l.sleepHours < 8.5 {
            out.append("😴 Dormiste \(String(format: "%.1f", l.sleepHours)) h. Para crecer al máximo necesitas 9–10. Hoy acuéstate a las \(Fecha.hora(cama)) en punto.")
        } else if l.sleepHours > 11 {
            out.append("😴 Dormiste \(String(format: "%.1f", l.sleepHours)) h. Está bien descansar, pero despertarte muy tarde te desacomoda y luego no te duermes temprano. Usa la alarma suave.")
        } else if l.sleepHours == 0 {
            out.append("😴 No registraste tu sueño. Anótalo, es lo que más influye en tu estatura.")
        }
        let falta = settings.proteinGoal - l.protein
        if falta > 10 {
            out.append("🥩 Te faltaron ~\(falta) g de proteína. Mañana agrega un vaso de leche y 2 huevos extra, o un yogur antes de dormir.")
        }
        if l.mealsEaten < 4 {
            out.append("🍽️ Solo hiciste \(l.mealsEaten) comidas. Saltarte comidas frena tu crecimiento: mínimo 4–5 al día.")
        }
        if l.fruits < 2 { out.append("🍎 Comiste \(l.fruits) fruta(s). Meta: 2–3 (plátano, manzana, uvas, melón…).") }
        if !l.salad { out.append("🥗 Te faltó la ensalada de lechuga, pepino y jitomate.") }
        if Plan.esDiaDeEntreno(date) && !l.trained {
            out.append("💪 Hoy tocaba \(Plan.dia(date).titulo) y no lo marcaste. Si no pudiste, no lo repongas mañana: sigue el plan normal.")
        }
        if l.elbowPain {
            out.append("🦾 Molestia en el codo: la próxima sesión de empuje quita el lastre de fondos y usa rango corto. Si sigue 2 semanas, ve con un traumatólogo.")
        }
        let postres = postresSemana(date)
        if postres > settings.dessertsPerWeek {
            out.append("🍰 Llevas \(postres) postres esta semana (meta \(settings.dessertsPerWeek)). Ya no más hasta el lunes.")
        }
        if !l.shower { out.append("🚿 Báñate en la noche para no hacerlo en la mañana y dormir 15 min más.") }
        if out.isEmpty { out.append("🔥 Día perfecto. Así se crece. A dormir.") }
        return out
    }

    func resumenCorto(_ date: Date) -> String {
        let l = log(date)
        var partes: [String] = []
        if Plan.esDiaDeEntreno(date) { partes.append(l.trained ? "✅ Entreno" : "❌ Entreno") }
        partes.append(l.protein >= settings.proteinGoal - 10 ? "✅ Proteína \(l.protein) g" : "❌ Proteína \(l.protein)/\(settings.proteinGoal) g")
        partes.append(l.mealsEaten >= 4 ? "✅ \(l.mealsEaten) comidas" : "❌ \(l.mealsEaten) comidas")
        partes.append(l.fruits >= 2 ? "✅ Fruta" : "❌ Fruta")
        partes.append(l.salad ? "✅ Ensalada" : "❌ Ensalada")
        return partes.joined(separator: " · ")
    }

    // MARK: Programar avisos y alarmas

    func reprogramarTodo() {
        reprogramarAvisos()
        rebuildTask?.cancel()
        rebuildTask = Task { await self.reprogramarAlarmas() }
    }

    func reprogramarAvisos() {
        let s = settings
        Avisos.center.removeAllPendingNotificationRequests()

        // 6 días por adelantado (iOS permite máximo 64 avisos pendientes)
        for i in 0..<6 {
            let d = Fecha.add(days: i, to: Date())
            let k = Fecha.key(d)
            let p = perfil(d)
            let plan = Plan.dia(d)
            Avisos.una("desayuno-\(k)", Fecha.at(p.breakfast, on: d), "🍳 Desayuno", MenuPlan.de(.desayuno, d))
            Avisos.una("snack-\(k)", Fecha.at(p.snack, on: d), "🥪 Snack", MenuPlan.de(.snack, d))
            Avisos.una("comida-\(k)", Fecha.at(p.lunch, on: d), "🍛 Hora de comer", MenuPlan.de(.comida, d))
            if plan.tipo != .descanso {
                Avisos.una("pre-\(k)", Fecha.at(p.preWorkout, on: d), "🍌 Snack antes de entrenar", MenuPlan.de(.preentreno, d))
                Avisos.una("entreno-\(k)", Fecha.at(p.workout, on: d), "\(plan.emoji) Hoy: \(plan.titulo)", plan.nota)
            }
            Avisos.una("cena-\(k)", Fecha.at(p.dinner, on: d), "🌮 Hora de cenar", MenuPlan.de(.cena, d))
            if !s.strongShower {
                Avisos.una("bano-\(k)", Fecha.at(p.shower, on: d), "🚿 Hora de bañarte", "Agua caliente y luego a relajarte.")
            }
            Avisos.una("pantallas-\(k)", Fecha.at(p.bed - 15, on: d), "📵 Fuera pantallas", "En 15 min a dormir (\(Fecha.hora(p.bed))). Tu estatura se hace dormido.")
            if !s.strongBed {
                Avisos.una("dormir-\(k)", Fecha.at(p.bed, on: d), "😴 A dormir", "Ya. Apaga todo.")
            }

            // Cierre del día + pregunta de mañana
            let manana = Fecha.add(days: 1, to: d)
            let pm = perfil(manana)
            let pregunta: String
            if !pm.libre {
                pregunta = "🏫 Mañana hay escuela: alarma a las \(Fecha.hora(pm.wake)). ¿Sí hay escuela?"
            } else if pm.alarma {
                pregunta = "🏖️ Mañana es día libre (alarma suave \(Fecha.hora(pm.wake))). ¿O sí hay escuela?"
            } else {
                pregunta = "🏖️ Mañana es día libre, sin alarma. ¿O sí hay escuela?"
            }
            let resumen = i == 0 && log(d).closed ? resumenCorto(d) + "\n" : "Toca para llenar qué hiciste hoy.\n"
            Avisos.una("cierre-\(k)", Fecha.at(p.summary, on: d), "🌙 Cierre del día", resumen + pregunta,
                       categoria: "NIGHT_ALARM")
        }
    }

    func reprogramarAlarmas() async {
        guard Alarmas.autorizado else { return }
        Alarmas.cancelarTodas(excepto: restAlarmID)
        let s = settings
        for i in 0..<14 {
            let d = Fecha.add(days: i, to: Date())
            let p = perfil(d)
            if p.alarma {
                await Alarmas.programar(Fecha.at(p.wake, on: d),
                                        titulo: p.libre ? "☀️ Buenos días (día libre)" : "⏰ Buenos días, a crecer",
                                        color: .orange)
            }
            if i < 7 {
                if s.strongShower {
                    await Alarmas.programar(Fecha.at(p.shower, on: d), titulo: "🚿 Hora de bañarte", color: .blue)
                }
                if s.strongBed {
                    await Alarmas.programar(Fecha.at(p.bed, on: d), titulo: "😴 A dormir", color: .indigo)
                }
            }
        }
    }

    // MARK: Descanso entre series

    func iniciarDescanso(_ segundos: Int) {
        cancelarDescanso()
        let fin = Date().addingTimeInterval(TimeInterval(segundos))
        restEnd = fin
        Task {
            let id = await Alarmas.programar(fin, titulo: "⏱️ Siguiente serie", color: .green)
            self.restAlarmID = id
        }
    }

    func cancelarDescanso() {
        if let id = restAlarmID { Alarmas.cancelar(id) }
        restAlarmID = nil
        restEnd = nil
    }
}
