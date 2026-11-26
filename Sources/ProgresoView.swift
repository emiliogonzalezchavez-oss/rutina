import SwiftUI
import Charts

struct ProgresoView: View {
    @EnvironmentObject var store: Store
    @State private var peso: Double = 60
    @State private var estatura: Double = 170

    var body: some View {
        let ultimos7 = (0..<7).map { Fecha.add(days: -$0, to: Date()) }
        let suenos = ultimos7.map { store.log($0).sleepHours }.filter { $0 > 0 }
        let proteinas = ultimos7.map { store.log($0).protein }.filter { $0 > 0 }
        let entrada = store.bodyEntries.sorted { $0.date < $1.date }

        NavigationStack {
            List {
                Section("Últimos 7 días") {
                    fila("🔥 Racha", "\(store.racha()) días")
                    fila("😴 Sueño promedio", suenos.isEmpty ? "—" : String(format: "%.1f h", suenos.reduce(0, +) / Double(suenos.count)))
                    fila("🥩 Proteína promedio", proteinas.isEmpty ? "—" : "\(proteinas.reduce(0, +) / proteinas.count) g")
                    fila("🍰 Postres esta semana", "\(store.postresSemana()) / \(store.settings.dessertsPerWeek)")
                    fila("💪 Entrenos", "\(ultimos7.filter { store.log($0).trained }.count)")
                }

                Section("📏 Estatura") {
                    if entrada.count >= 2 {
                        Chart(entrada) { e in
                            LineMark(x: .value("Fecha", e.date), y: .value("cm", e.heightCm))
                            PointMark(x: .value("Fecha", e.date), y: .value("cm", e.heightCm))
                        }
                        .chartYScale(domain: .automatic(includesZero: false))
                        .frame(height: 160)
                        if let a = entrada.first, let b = entrada.last {
                            Text(verbatim: "Has crecido \(String(format: "%.1f", b.heightCm - a.heightCm)) cm")
                                .font(.footnote.bold())
                        }
                    } else {
                        Text("Mide tu estatura cada domingo (en la mañana, descalzo, pegado a la pared).")
                            .font(.footnote)
                    }
                }

                Section("⚖️ Peso") {
                    if entrada.count >= 2 {
                        Chart(entrada) { e in
                            LineMark(x: .value("Fecha", e.date), y: .value("kg", e.weightKg))
                            PointMark(x: .value("Fecha", e.date), y: .value("kg", e.weightKg))
                        }
                        .chartYScale(domain: .automatic(includesZero: false))
                        .frame(height: 160)
                    }
                    Text("Meta: subir de peso poco a poco (≈0.25 kg por semana). Si bajas, come más.")
                        .font(.footnote).foregroundStyle(.secondary)
                }

                Section("Agregar medición") {
                    Stepper("Peso: \(peso, specifier: "%.1f") kg", value: $peso, in: 30...120, step: 0.1)
                    Stepper("Estatura: \(estatura, specifier: "%.1f") cm", value: $estatura, in: 120...210, step: 0.1)
                    Button("Guardar medición") {
                        store.bodyEntries.append(BodyEntry(date: Date(), weightKg: peso, heightCm: estatura))
                        store.save()
                    }
                }

                if !entrada.isEmpty {
                    Section("Historial") {
                        ForEach(entrada.reversed()) { e in
                            HStack {
                                Text(e.date, style: .date)
                                Spacer()
                                Text(verbatim: String(format: "%.1f kg · %.1f cm", e.weightKg, e.heightCm))
                            }
                            .font(.callout)
                        }
                        .onDelete { idx in
                            let lista = Array(entrada.reversed())
                            let ids = idx.map { lista[$0].id }
                            store.bodyEntries.removeAll { ids.contains($0.id) }
                            store.save()
                        }
                    }
                }
            }
            .navigationTitle("Progreso")
            .onAppear {
                if let u = store.bodyEntries.max(by: { $0.date < $1.date }) {
                    peso = u.weightKg
                    estatura = u.heightCm
                }
            }
        }
    }

    func fila(_ a: String, _ b: String) -> some View {
        HStack { Text(a); Spacer(); Text(b).bold() }
    }
}
