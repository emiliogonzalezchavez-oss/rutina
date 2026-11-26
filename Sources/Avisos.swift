import Foundation
import SwiftUI
import UserNotifications
import AlarmKit

// MARK: - Alarmas de verdad (AlarmKit: suenan aunque esté en silencio)

struct RutinaAlarmMeta: AlarmMetadata {}

enum Alarmas {
    static func autorizar() async -> Bool {
        let m = AlarmManager.shared
        switch m.authorizationState {
        case .authorized:
            return true
        case .denied:
            return false
        default:
            do {
                let estado = try await m.requestAuthorization()
                return estado == .authorized
            } catch {
                return false
            }
        }
    }

    static var autorizado: Bool { AlarmManager.shared.authorizationState == .authorized }

    @discardableResult
    static func programar(_ fecha: Date, titulo: String, color: Color) async -> UUID? {
        guard fecha > Date() else { return nil }
        let alert = AlarmPresentation.Alert(
            title: LocalizedStringResource(stringLiteral: titulo),
            secondaryButton: nil,
            secondaryButtonBehavior: nil)
        let attrs = AlarmAttributes<RutinaAlarmMeta>(
            presentation: AlarmPresentation(alert: alert),
            metadata: RutinaAlarmMeta(),
            tintColor: color)
        let config = AlarmManager.AlarmConfiguration<RutinaAlarmMeta>.alarm(
            schedule: .fixed(fecha),
            attributes: attrs,
            sound: .default)
        let id = UUID()
        do {
            _ = try await AlarmManager.shared.schedule(id: id, configuration: config)
            return id
        } catch {
            return nil
        }
    }

    static func cancelar(_ id: UUID) {
        try? AlarmManager.shared.cancel(id: id)
    }

    static func cancelarTodas(excepto keep: UUID?) {
        guard let lista = try? AlarmManager.shared.alarms else { return }
        for a in lista where a.id != keep {
            try? AlarmManager.shared.cancel(id: a.id)
        }
    }
}

// MARK: - Notificaciones

enum Avisos {
    static let center = UNUserNotificationCenter.current()

    static func pedirPermiso() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func registrarCategorias() {
        let abrir = UNNotificationAction(identifier: "OPEN_CLOSE", title: "📝 Llenar cierre del día", options: [.foreground])
        let si = UNNotificationAction(identifier: "SCHOOL_YES", title: "✅ Sí hay escuela", options: [])
        let no = UNNotificationAction(identifier: "SCHOOL_NO", title: "😴 No hay, apaga la alarma", options: [.destructive])
        let prender = UNNotificationAction(identifier: "ALARM_ON", title: "⏰ Sí ponla", options: [])
        let conAlarma = UNNotificationCategory(identifier: "NIGHT_ALARM", actions: [abrir, si, no], intentIdentifiers: [])
        let sinAlarma = UNNotificationCategory(identifier: "NIGHT_NOALARM", actions: [abrir, prender], intentIdentifiers: [])
        center.setNotificationCategories([conAlarma, sinAlarma])
    }

    static func una(_ id: String, _ fecha: Date, _ titulo: String, _ cuerpo: String, categoria: String? = nil) {
        guard fecha > Date() else { return }
        let c = UNMutableNotificationContent()
        c.title = titulo
        c.body = cuerpo
        c.sound = .default
        if let categoria { c.categoryIdentifier = categoria }
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fecha)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        center.add(UNNotificationRequest(identifier: id, content: c, trigger: trigger))
    }

    /// Se repite todos los días (o solo un día de la semana si pasas weekday).
    static func diaria(_ id: String, minutos: Int, weekday: Int? = nil, _ titulo: String, _ cuerpo: String) {
        let c = UNMutableNotificationContent()
        c.title = titulo
        c.body = cuerpo
        c.sound = .default
        var comps = DateComponents()
        comps.hour = minutos / 60
        comps.minute = minutos % 60
        if let weekday { comps.weekday = weekday }
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        center.add(UNNotificationRequest(identifier: id, content: c, trigger: trigger))
    }
}

// MARK: - Delegate (botones de las notificaciones)

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        Avisos.registrarCategorias()
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        let accion = response.actionIdentifier
        let categoria = response.notification.request.content.categoryIdentifier
        switch accion {
        case "SCHOOL_NO":
            await Store.shared.alarmaManana(false)
        case "SCHOOL_YES", "ALARM_ON":
            await Store.shared.alarmaManana(true)
        case "OPEN_CLOSE":
            await MainActor.run { Store.shared.tab = .cierre }
        case UNNotificationDefaultActionIdentifier:
            if categoria.hasPrefix("NIGHT") {
                await MainActor.run { Store.shared.tab = .cierre }
            }
        default:
            break
        }
    }
}
