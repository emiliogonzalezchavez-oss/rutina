import SwiftUI

struct CierreView: View {
    @EnvironmentObject var store: Store
    @State private var ayer = false

    var body: some View {
        let fecha = ayer ? Fecha.add(days: -1, to: Date()) : Date()
        let l = store.binding(fecha)
        let plan = Plan.dia(fecha)
        let manana = Fecha.add(days: 1, to: Date())

        NavigationStack {
            Form {
                Picker("Día", selection: $ayer) {
                    Text("Hoy").tag(false)
                    Text("Ayer").tag(true)
                }
                .pickerStyle(.segmented)

                Section("😴 Sueño (la noche anterior)") {
                    Stepper("Dormí \(l.wrappedValue.sleepHours, specifier: "%.1f") h",
                            value: l.sleepHours, in: 0...14, step: 0.5)
                }

                Section("🍽️ Comidas") {
                    ForEach(Comida.allCases) { c in
                        Toggle("\(c.emoji) \(c.titulo)", isOn: Binding(
                            get: { l.wrappedValue.meals[c.rawValue] ?? false },
                            set: { l.wrappedValue.meals[c.rawValue] = $0 }))
                    }
                    Stepper("🥩 Proteína: \(l.wrappedValue.protein) g", value: l.protein, in: 0...300, step: 5)
                    Stepper("🍎 Frutas: \(l.wrappedValue.fruits)", value: l.fruits, in: 0...10)
                    Toggle("🥗 Ensalada (lechuga, pepino, jitomate)", isOn: l.salad)
                    Stepper("🍰 Postres / refrescos: \(l.wrappedValue.desserts)", value: l.desserts, in: 0...10)
                }

                Section("💪 Entreno") {
                    Toggle("\(plan.emoji) \(plan.titulo)", isOn: l.trained)
                    Toggle("🦾 Molestia en el codo", isOn: l.elbowPain)
                }

                Section("🌙 Noche") {
                    Toggle("🚿 Me bañé", isOn: l.shower)
                    Toggle("📵 Apagué pantallas a tiempo", isOn: l.screensOff)
                }

                Section("📝 Nota") {
                    TextField("¿Algo que quieras recordar?", text: l.note, axis: .vertical)
                }

                if !ayer {
                    Section("⏰ Mañana") {
                        Toggle("Alarma a las \(Fecha.hora(store.settings.wake))", isOn: Binding(
                            get: { store.hayAlarma(manana) },
                            set: { on in Task { await store.alarmaManana(on) } }))
                        Text("Apágala si mañana no hay escuela.").font(.footnote).foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button {
                        l.wrappedValue.closed = true
                        store.reprogramarAvisos()
                    } label: {
                        Label(l.wrappedValue.closed ? "Día cerrado ✅ (actualizar)" : "Cerrar el día",
                              systemImage: "moon.zzz.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }

                if l.wrappedValue.closed {
                    Section {
                        Text(store.resumenCorto(fecha)).font(.footnote)
                    } header: {
                        Text(verbatim: "Tu día: \(store.puntaje(l.wrappedValue, fecha)) %")
                    }
                    Section("💡 Sugerencias") {
                        ForEach(store.sugerencias(fecha), id: \.self) { s in
                            Text(s).font(.callout)
                        }
                    }
                }
            }
            .navigationTitle("Cierre del día")
        }
    }
}
