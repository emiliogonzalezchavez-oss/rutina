import SwiftUI

struct EntrenoView: View {
    @EnvironmentObject var store: Store
    @State private var offset = 0   // para ver otros días

    var body: some View {
        let fecha = Fecha.add(days: offset, to: Date())
        let plan = Plan.dia(fecha)
        NavigationStack {
            List {
                Section {
                    HStack {
                        Button { offset -= 1 } label: { Image(systemName: "chevron.left") }
                        Spacer()
                        VStack {
                            Text(offset == 0 ? "Hoy" : Fecha.nombreDia.string(from: fecha).capitalized)
                                .font(.caption).foregroundStyle(.secondary)
                            Text("\(plan.emoji) \(plan.titulo)").font(.headline)
                        }
                        Spacer()
                        Button { offset += 1 } label: { Image(systemName: "chevron.right") }
                    }
                    .buttonStyle(.borderless)
                    Text(plan.nota).font(.footnote).foregroundStyle(.secondary)
                }

                if plan.ejercicios.isEmpty {
                    Section { Text("Hoy no hay ejercicios. Descansa: el músculo y la estatura crecen descansando.") }
                } else {
                    Section("Ejercicios") {
                        ForEach(plan.ejercicios) { e in
                            NavigationLink {
                                EjercicioView(ejercicio: e)
                            } label: {
                                let hechas = offset == 0 ? store.seriesHoy(e.nombre).count : 0
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(e.nombre).font(.subheadline.bold())
                                        Text("\(e.series) × \(e.objetivo)").font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if offset == 0 {
                                        Text("\(hechas)/\(e.series)")
                                            .font(.caption.bold())
                                            .foregroundStyle(hechas >= e.series ? .green : .secondary)
                                    }
                                }
                            }
                        }
                    }
                }

                if offset == 0 && plan.tipo != .descanso {
                    Section {
                        let hecho = store.log(fecha).trained
                        Button {
                            var l = store.log(fecha)
                            l.trained.toggle()
                            store.logs[l.id] = l
                            store.save()
                        } label: {
                            Label(hecho ? "Entreno hecho ✅ (toca para desmarcar)" : "Terminé el entreno",
                                  systemImage: hecho ? "checkmark.seal.fill" : "flag.checkered")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(hecho ? .green : .orange)
                    }
                }
            }
            .navigationTitle("Entreno")
            .safeAreaInset(edge: .bottom) { DescansoBar() }
        }
    }
}

struct DescansoBar: View {
    @EnvironmentObject var store: Store

    var body: some View {
        if let fin = store.restEnd {
            TimelineView(.periodic(from: .now, by: 1)) { ctx in
                let resta = max(0, Int(fin.timeIntervalSince(ctx.date)))
                HStack {
                    Image(systemName: "timer")
                    Text(resta > 0 ? "Descanso: \(resta / 60):\(String(format: "%02d", resta % 60))" : "¡Siguiente serie!")
                        .font(.headline.monospacedDigit())
                    Spacer()
                    Button("+30 s") { store.iniciarDescanso(resta + 30) }
                    Button("Quitar") { store.cancelarDescanso() }
                }
                .buttonStyle(.bordered)
                .padding()
                .background(.ultraThinMaterial)
            }
        }
    }
}

struct EjercicioView: View {
    @EnvironmentObject var store: Store
    let ejercicio: Ejercicio

    @State private var peso: Double = 0
    @State private var reps: Int = 5
    @State private var segundos: Int = 10

    var body: some View {
        let ultima = store.ultimaSesion(ejercicio.nombre)
        let hoy = store.seriesHoy(ejercicio.nombre)
        Form {
            Section {
                Text("\(ejercicio.series) series × \(ejercicio.objetivo)").font(.headline)
                Text(ejercicio.nota).font(.footnote)
                Text("Descanso: \(ejercicio.descanso / 60):\(String(format: "%02d", ejercicio.descanso % 60)) min")
                    .font(.footnote).foregroundStyle(.secondary)
            }

            if let s = store.sugerenciaProgreso(ejercicio) {
                Section { Text(s).bold() }
            }

            if !ultima.isEmpty {
                Section("La vez pasada") {
                    ForEach(ultima) { s in Text(texto(s)).font(.callout) }
                }
            }

            Section("Anotar serie \(hoy.count + 1) de \(ejercicio.series)") {
                if ejercicio.tipo == .lastre {
                    Stepper("Lastre: \(peso, specifier: "%.1f") kg", value: $peso, in: 0...40, step: 0.5)
                }
                if ejercicio.tipo == .hold {
                    Stepper("Segundos: \(segundos)", value: $segundos, in: 1...120)
                } else {
                    Stepper("Reps: \(reps)", value: $reps, in: 1...50)
                }
                Button {
                    store.addSet(SetLog(exercise: ejercicio.nombre,
                                        weight: ejercicio.tipo == .lastre ? peso : 0,
                                        reps: ejercicio.tipo == .hold ? 0 : reps,
                                        seconds: ejercicio.tipo == .hold ? segundos : 0))
                    if hoy.count + 1 < ejercicio.series {
                        store.iniciarDescanso(ejercicio.descanso)
                    } else {
                        store.cancelarDescanso()
                    }
                } label: {
                    Label("Guardar serie y empezar descanso", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }

            if !hoy.isEmpty {
                Section("Hoy") {
                    ForEach(hoy) { s in Text(texto(s)) }
                        .onDelete { idx in idx.map { hoy[$0] }.forEach(store.deleteSet) }
                }
            }
        }
        .navigationTitle(ejercicio.nombre)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { DescansoBar() }
        .onAppear {
            if let u = ultima.last ?? hoy.last {
                peso = u.weight
                if u.reps > 0 { reps = u.reps }
                if u.seconds > 0 { segundos = u.seconds }
            } else {
                reps = ejercicio.minReps
                segundos = ejercicio.minReps
                if ejercicio.nombre == "Dominadas lastradas" { peso = 15 }
            }
        }
    }

    func texto(_ s: SetLog) -> String {
        switch ejercicio.tipo {
        case .lastre: return "\(String(format: "%.1f", s.weight)) kg × \(s.reps) reps"
        case .reps: return "\(s.reps) reps"
        case .hold: return "\(s.seconds) s"
        }
    }
}
