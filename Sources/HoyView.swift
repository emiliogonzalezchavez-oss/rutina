import SwiftUI

struct HoyView: View {
    @EnvironmentObject var store: Store

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 60)) { ctx in
                let hoy = ctx.date
                let plan = Plan.dia(hoy)
                let l = store.log(hoy)
                let ahora = Fecha.minutes(of: hoy)
                let items = store.horario(hoy)
                let siguiente = items.first { $0.minutos >= ahora }
                let libre = store.esLibre(hoy)

                List {
                    Section {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(Fecha.nombreDia.string(from: hoy).capitalized)
                                .font(.subheadline).foregroundStyle(.secondary)
                            Text("\(plan.emoji) \(plan.titulo)")
                                .font(.title2.bold())
                            Text(libre ? (store.enVacaciones(hoy) ? "🏖️ Vacaciones · horario libre" : "🏖️ Día libre · horario libre") : "🏫 Día de escuela")
                                .font(.footnote.bold())
                                .foregroundStyle(libre ? .green : .orange)
                            Text(plan.nota).font(.footnote).foregroundStyle(.secondary)
                            if store.racha() > 0 {
                                Text("🔥 Racha: \(store.racha()) días").font(.footnote.bold()).foregroundStyle(.orange)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    if let s = siguiente {
                        Section("Ahora toca") {
                            HStack(alignment: .top) {
                                Text(s.emoji).font(.largeTitle)
                                VStack(alignment: .leading) {
                                    Text("\(Fecha.hora(s.minutos)) · \(s.titulo)").font(.headline)
                                    if !s.detalle.isEmpty {
                                        Text(s.detalle).font(.subheadline).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }

                    Section("Escuela esta semana") {
                        SemanaEscuela()
                        Toggle("🏖️ Modo vacaciones", isOn: $store.settings.vacationOn)
                        if store.settings.vacationOn {
                            DatePicker("Desde", selection: $store.settings.vacationStart, displayedComponents: .date)
                            DatePicker("Hasta", selection: $store.settings.vacationEnd, in: store.settings.vacationStart..., displayedComponents: .date)
                        }
                    }

                    Section("Proteína: \(l.protein) / \(store.settings.proteinGoal) g") {
                        ProgressView(value: min(Double(l.protein), Double(store.settings.proteinGoal)),
                                     total: Double(store.settings.proteinGoal))
                        ProteinaRapida(fecha: hoy)
                    }

                    Section("Esta semana") {
                        let p = store.postresSemana(hoy)
                        HStack {
                            Text("🍰 Postres")
                            Spacer()
                            Text("\(p) / \(store.settings.dessertsPerWeek)")
                                .foregroundStyle(p > store.settings.dessertsPerWeek ? .red : .primary)
                                .bold()
                        }
                        Button("➕ Me comí un postre (o refresco)") {
                            var x = store.log(hoy)
                            x.desserts += 1
                            store.logs[x.id] = x
                            store.save()
                        }
                    }

                    Section("Horario de hoy") {
                        ForEach(items) { it in
                            HStack(alignment: .top) {
                                Text(Fecha.hora(it.minutos))
                                    .font(.caption.monospacedDigit())
                                    .frame(width: 64, alignment: .leading)
                                    .foregroundStyle(it.minutos < ahora ? .secondary : .primary)
                                Text(it.emoji)
                                VStack(alignment: .leading) {
                                    Text(it.titulo).font(.subheadline.bold())
                                    if !it.detalle.isEmpty {
                                        Text(it.detalle).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .opacity(it.minutos < ahora ? 0.5 : 1)
                        }
                    }

                    if libre {
                        Section { Text(MenuPlan.finde).font(.footnote) }
                    }
                }
            }
            .navigationTitle("Hoy")
            .onChange(of: store.settings.vacationOn) { _, _ in store.save(); store.reprogramarTodo() }
            .onChange(of: store.settings.vacationStart) { _, nuevo in
                if store.settings.vacationEnd < nuevo { store.settings.vacationEnd = nuevo }
                store.save(); store.reprogramarTodo()
            }
            .onChange(of: store.settings.vacationEnd) { _, _ in store.save(); store.reprogramarTodo() }
        }
    }
}

struct SemanaEscuela: View {
    @EnvironmentObject var store: Store

    private func semana() -> [Date] {
        var cal = Calendar.current
        cal.firstWeekday = 2
        var base = Date()
        let w = cal.component(.weekday, from: base)
        if w == 7 { base = Fecha.add(days: 2, to: base) }
        if w == 1 { base = Fecha.add(days: 1, to: base) }
        let inicio = cal.dateInterval(of: .weekOfYear, for: base)?.start ?? base
        return (0..<5).map { Fecha.add(days: $0, to: inicio) }
    }

    private func letra(_ d: Date) -> String {
        switch Calendar.current.component(.weekday, from: d) {
        case 2: return "L"
        case 3: return "M"
        case 4: return "Mi"
        case 5: return "J"
        default: return "V"
        }
    }

    var body: some View {
        let dias = semana()
        HStack(spacing: 8) {
            ForEach(dias, id: \.self) { d in
                let libre = store.esLibre(d)
                let esHoy = Calendar.current.isDateInToday(d)
                let vac = store.enVacaciones(d)
                Button {
                    store.setEscuela(d, libre)
                } label: {
                    VStack(spacing: 2) {
                        Text(letra(d)).font(.caption.bold())
                        Text(libre ? "🏖️" : "🏫").font(.title3)
                        Text(Calendar.current.component(.day, from: d).description).font(.caption2).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 10).fill(libre ? Color.green.opacity(0.25) : Color.orange.opacity(0.25)))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(esHoy ? Color.primary : Color.clear, lineWidth: 2))
                }
                .buttonStyle(.plain)
                .disabled(vac)
            }
        }
        .padding(.vertical, 4)
        Text("Toca un día para cambiar entre escuela 🏫 y libre 🏖️. En días libres cambian los horarios (Ajustes → Días libres), pero el entreno sigue.")
            .font(.caption).foregroundStyle(.secondary)
    }
}

struct ProteinaRapida: View {
    @EnvironmentObject var store: Store
    let fecha: Date
    @State private var mostrarTodo = false

    var body: some View {
        let lista = mostrarTodo ? MenuPlan.proteinas : Array(MenuPlan.proteinas.prefix(8))
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: 8) {
            ForEach(lista.indices, id: \.self) { i in
                let item = lista[i]
                Button {
                    store.addProtein(item.1, fecha)
                } label: {
                    VStack(spacing: 2) {
                        Text(item.0).font(.caption).lineLimit(1)
                        Text("+\(item.1) g").font(.caption2).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 4)
        HStack {
            Button(mostrarTodo ? "Ver menos" : "Ver todas") { mostrarTodo.toggle() }
            Spacer()
            Button("−5 g (corregir)", role: .destructive) { store.addProtein(-5, fecha) }
        }
        .font(.footnote)
        .buttonStyle(.borderless)
    }
}
