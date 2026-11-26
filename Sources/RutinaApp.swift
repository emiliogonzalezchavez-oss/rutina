import SwiftUI

@main
struct RutinaApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @ObservedObject private var store = Store.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
                .tint(.orange)
        }
        .onChange(of: scenePhase) { _, fase in
            switch fase {
            case .active:
                if store.settings.setupDone { store.reprogramarTodo() }
            case .background:
                store.save()
                store.reprogramarAvisos()
            default:
                break
            }
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var store: Store
    @State private var mostrarInicio = false

    var body: some View {
        TabView(selection: $store.tab) {
            HoyView()
                .tabItem { Label("Hoy", systemImage: "sun.max.fill") }
                .tag(Pestana.hoy)
            EntrenoView()
                .tabItem { Label("Entreno", systemImage: "figure.strengthtraining.traditional") }
                .tag(Pestana.entreno)
            CierreView()
                .tabItem { Label("Cierre", systemImage: "moon.stars.fill") }
                .tag(Pestana.cierre)
            ProgresoView()
                .tabItem { Label("Progreso", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(Pestana.progreso)
            AjustesView()
                .tabItem { Label("Ajustes", systemImage: "gearshape.fill") }
                .tag(Pestana.ajustes)
        }
        .onAppear { mostrarInicio = !store.settings.setupDone }
        .sheet(isPresented: $mostrarInicio) { InicioView() }
    }
}

struct InicioView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var horaActual = Fecha.at(23 * 60 + 30, on: Date())
    @State private var trabajando = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Esta app te dice qué hacer cada día para crecer al máximo en estatura, fuerza y músculo, y te avisa de todo.")
                }
                Section("¿A qué hora te duermes normalmente hoy en día?") {
                    DatePicker("Hora actual de dormir", selection: $horaActual, displayedComponents: .hourAndMinute)
                    Text("La app la va a adelantar 30 min cada 4 días hasta llegar a las \(Fecha.hora(store.settings.targetBed)).")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section {
                    Button {
                        Task {
                            trabajando = true
                            _ = await Avisos.pedirPermiso()
                            _ = await Alarmas.autorizar()
                            var m = Fecha.minutes(of: horaActual)
                            if m < 12 * 60 { m += 24 * 60 } // después de medianoche
                            store.settings.startBed = min(max(m, store.settings.targetBed), 24 * 60 + 60)
                            store.settings.rampStart = Date()
                            store.settings.setupDone = true
                            store.save()
                            store.reprogramarTodo()
                            trabajando = false
                            dismiss()
                        }
                    } label: {
                        Label(trabajando ? "Activando…" : "Activar avisos y alarmas", systemImage: "bell.badge.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(trabajando)
                } footer: {
                    Text("Te va a pedir permiso para notificaciones y para alarmas. Acepta los dos.")
                }
            }
            .navigationTitle("Bienvenido 💪")
            .interactiveDismissDisabled()
        }
    }
}
