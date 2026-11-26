import SwiftUI

struct AjustesView: View {
    @EnvironmentObject var store: Store
    @State private var mensaje = ""
    @State private var horaActual = Fecha.at(23 * 60 + 30, on: Date())

    private let dias: [(Int, String)] = [(2, "Lunes"), (3, "Martes"), (4, "Miércoles"), (5, "Jueves"), (6, "Viernes"), (7, "Sábado"), (1, "Domingo")]

    func hora(_ kp: WritableKeyPath<AppSettings, Int>) -> Binding<Date> {
        Binding(
            get: { Fecha.at(store.settings[keyPath: kp] % (24 * 60), on: Date()) },
            set: { d in
                store.settings[keyPath: kp] = Fecha.minutes(of: d)
                store.save()
            })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("⏰ Alarma de la mañana") {
                    DatePicker("Despertar", selection: hora(\.wake), displayedComponents: .hourAndMinute)
                    ForEach(dias.indices, id: \.self) { i in
                        let d = dias[i]
                        Toggle(d.1, isOn: Binding(
                            get: { store.settings.schoolDays.contains(d.0) },
                            set: { on in
                                store.settings.schoolDays.removeAll { $0 == d.0 }
                                if on { store.settings.schoolDays.append(d.0) }
                                store.save()
                            }))
                    }
                    Text("Días con escuela (suena la alarma). Cada noche te pregunta si mañana hay escuela.")
                        .font(.footnote).foregroundStyle(.secondary)
                }

                Section("🍽️ Comidas") {
                    DatePicker("Desayuno", selection: hora(\.breakfast), displayedComponents: .hourAndMinute)
                    DatePicker("Snack escuela", selection: hora(\.snack), displayedComponents: .hourAndMinute)
                    DatePicker("Comida", selection: hora(\.lunch), displayedComponents: .hourAndMinute)
                    DatePicker("Snack antes de entrenar", selection: hora(\.preWorkout), displayedComponents: .hourAndMinute)
                    DatePicker("Cena", selection: hora(\.dinner), displayedComponents: .hourAndMinute)
                    Stepper("Meta de proteína: \(store.settings.proteinGoal) g", value: $store.settings.proteinGoal, in: 60...200, step: 5)
                    Stepper("Postres por semana: \(store.settings.dessertsPerWeek)", value: $store.settings.dessertsPerWeek, in: 0...7)
                }

                Section("💪 Entreno y noche") {
                    DatePicker("Entreno", selection: hora(\.workout), displayedComponents: .hourAndMinute)
                    DatePicker("Baño", selection: hora(\.shower), displayedComponents: .hourAndMinute)
                    DatePicker("Cierre del día", selection: hora(\.summary), displayedComponents: .hourAndMinute)
                    Toggle("Baño como alarma fuerte", isOn: $store.settings.strongShower)
                    Toggle("Dormir como alarma fuerte", isOn: $store.settings.strongBed)
                    Text("Alarma fuerte = suena aunque tengas el cel en silencio. Si la apagas, llega como notificación normal.")
                        .font(.footnote).foregroundStyle(.secondary)
                }

                Section("😴 Hora de dormir") {
                    let cama = store.horaDormir(Date())
                    HStack { Text("Hoy"); Spacer(); Text(Fecha.hora(cama)).bold() }
                    HStack { Text("Meta"); Spacer(); Text(Fecha.hora(store.settings.targetBed)).bold() }
                    Text("Se adelanta 30 min cada 4 días hasta llegar a la meta.")
                        .font(.footnote).foregroundStyle(.secondary)
                    DatePicker("Me estoy durmiendo a las", selection: $horaActual, displayedComponents: .hourAndMinute)
                    Button("Reiniciar desde esa hora") {
                        var m = Fecha.minutes(of: horaActual)
                        if m < 12 * 60 { m += 24 * 60 }
                        store.reiniciarSueno(desde: max(m, store.settings.targetBed))
                        mensaje = "Listo, arranca desde \(Fecha.hora(m))."
                    }
                }

                Section {
                    Button("🔔 Reprogramar avisos y alarmas") {
                        store.save()
                        store.reprogramarTodo()
                        mensaje = "Avisos y alarmas reprogramados ✅"
                    }
                    Button("🔐 Pedir permisos otra vez") {
                        Task {
                            let n = await Avisos.pedirPermiso()
                            let a = await Alarmas.autorizar()
                            mensaje = "Notificaciones: \(n ? "✅" : "❌")  Alarmas: \(a ? "✅" : "❌")"
                            store.reprogramarTodo()
                        }
                    }
                    if !mensaje.isEmpty { Text(mensaje).font(.footnote) }
                } footer: {
                    Text("Si cambias horarios, toca \"Reprogramar\". También se reprograma solo cada vez que abres la app.")
                }
            }
            .navigationTitle("Ajustes")
            .onChange(of: store.settings.strongShower) { _, _ in store.save() }
            .onChange(of: store.settings.strongBed) { _, _ in store.save() }
            .onChange(of: store.settings.proteinGoal) { _, _ in store.save() }
            .onChange(of: store.settings.dessertsPerWeek) { _, _ in store.save() }
        }
    }
}
