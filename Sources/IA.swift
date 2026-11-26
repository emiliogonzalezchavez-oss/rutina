import SwiftUI
import PhotosUI
import UIKit

// MARK: - Datos

struct FoodEntry: Codable, Identifiable, Hashable {
    var id = UUID()
    var date = Date()
    var nombre: String
    var kcal: Int
    var proteina: Int
    var carbs: Int
    var grasas: Int
    var trans: Double
    var azucar: Int
    var esPostre: Bool
    var comida: String
    var comentario: String
}

struct AnalisisComida: Decodable {
    var nombre: String?
    var porcion: String?
    var calorias: Double?
    var proteina_g: Double?
    var carbohidratos_g: Double?
    var grasas_g: Double?
    var grasas_saturadas_g: Double?
    var grasas_trans_g: Double?
    var azucar_g: Double?
    var fibra_g: Double?
    var es_postre: Bool?
    var comida: String?
    var comentario: String?
}

@MainActor
final class FoodStore: ObservableObject {
    static let shared = FoodStore()
    @Published var porDia: [String: [FoodEntry]] = [:]

    private static var url: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("comidas.json")
    }

    init() {
        if let raw = try? Data(contentsOf: FoodStore.url),
           let d = try? JSONDecoder().decode([String: [FoodEntry]].self, from: raw) {
            porDia = d
        }
    }

    func save() {
        if let raw = try? JSONEncoder().encode(porDia) { try? raw.write(to: FoodStore.url, options: .atomic) }
    }

    func de(_ date: Date) -> [FoodEntry] { porDia[Fecha.key(date)] ?? [] }

    func agregar(_ e: FoodEntry, store: Store) {
        porDia[Fecha.key(e.date), default: []].append(e)
        save()
        var l = store.log(e.date)
        l.protein += e.proteina
        if e.esPostre { l.desserts += 1 }
        l.meals[e.comida] = true
        store.logs[l.id] = l
        store.save()
        store.reprogramarAvisos()
    }

    func borrar(_ e: FoodEntry, store: Store) {
        let k = Fecha.key(e.date)
        porDia[k]?.removeAll { $0.id == e.id }
        save()
        var l = store.log(e.date)
        l.protein = max(0, l.protein - e.proteina)
        if e.esPostre { l.desserts = max(0, l.desserts - 1) }
        store.logs[l.id] = l
        store.save()
    }
}

// MARK: - Gemini

enum Gemini {
    static let modelos = ["gemini-3.8-flash", "gemini-3.5-flash-lite", "gemini-flash-latest"]

    static func llamar(key: String, partes: [[String: Any]]) async throws -> String {
        var ultimo = "La IA no respondió."
        for m in modelos {
            guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(m):generateContent") else { continue }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.timeoutInterval = 60
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue(key, forHTTPHeaderField: "x-goog-api-key")
            req.httpBody = try JSONSerialization.data(withJSONObject: ["contents": [["parts": partes]]])
            let (data, resp) = try await URLSession.shared.data(for: req)
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
            if code == 200, let t = texto(data) { return t }
            let cuerpo = String(data: data, encoding: .utf8) ?? ""
            if code == 401 || code == 403 || cuerpo.contains("API_KEY_INVALID") || cuerpo.contains("API key not valid") {
                throw NSError(domain: "Gemini", code: code, userInfo: [NSLocalizedDescriptionKey: "Tu clave de Gemini no sirve. Toca \"Cambiar clave\" y pega una nueva."])
            }
            ultimo = "Error \(code): \(cuerpo.prefix(250))"
        }
        throw NSError(domain: "Gemini", code: 1, userInfo: [NSLocalizedDescriptionKey: ultimo])
    }

    static func texto(_ data: Data) -> String? {
        guard let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let c = (j["candidates"] as? [[String: Any]])?.first,
              let content = c["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]] else { return nil }
        let t = parts.compactMap { $0["text"] as? String }.joined()
        return t.isEmpty ? nil : t
    }

    static func extraerJSON(_ t: String) -> Data? {
        guard let a = t.firstIndex(of: "{"), let b = t.lastIndex(of: "}"), a < b else { return nil }
        return String(t[a...b]).data(using: .utf8)
    }

    static func promptFoto(contexto: String, nota: String) -> String {
        """
        Eres el nutriólogo deportivo de este chico. Analiza la foto de su comida.

        CONTEXTO:
        \(contexto)
        Nota del usuario sobre la foto: \(nota.isEmpty ? "ninguna" : nota)

        Responde SOLO con un objeto JSON válido, sin texto antes ni después y sin markdown, con estas claves:
        {"nombre": "texto", "porcion": "texto", "calorias": numero, "proteina_g": numero, "carbohidratos_g": numero, "grasas_g": numero, "grasas_saturadas_g": numero, "grasas_trans_g": numero, "azucar_g": numero, "fibra_g": numero, "es_postre": true o false, "comida": "desayuno" o "snack" o "comida" o "preentreno" o "cena", "comentario": "texto"}

        Reglas:
        - Estima la porción que se ve (o la que diga la nota) y da números realistas.
        - es_postre = true si es postre o algo dulce: pastel, helado, galletas, pan dulce, dulces, chocolate, refresco, jugo con mucha azúcar, etc.
        - comida = cuál de sus comidas del día es, según la hora y lo que ya comió.
        - comentario = 2 a 3 frases en español mexicano, directas y motivadoras, usando el contexto: si es postre dile cuántos le quedan esta semana (o si ya se pasó del límite); dile cuánta proteína le faltaría hoy después de esto y qué le conviene agregar de su menú. Nunca le sugieras saltarse comidas ni comer menos: está creciendo.
        - Si en la foto no hay comida, nombre = "No es comida" y todo en 0.
        """
    }
}

@MainActor
func contextoDelDia(_ store: Store, _ fs: FoodStore) -> String {
    let hoy = Date()
    let l = store.log(hoy)
    let p = store.perfil(hoy)
    let plan = Plan.dia(hoy)
    let medida = store.bodyEntries.max(by: { $0.date < $1.date })
    let cuerpo = medida.map { "pesa " + String(format: "%.1f", $0.weightKg) + " kg y mide " + String(format: "%.1f", $0.heightCm) + " cm (última medición)" } ?? "pesa 60 kg"
    let comidas = Comida.allCases.map { "\($0.titulo): \(l.meals[$0.rawValue] == true ? "sí" : "no")" }.joined(separator: ", ")
    let regs = fs.de(hoy).map { "\($0.nombre) (\($0.kcal) kcal, \($0.proteina) g proteína\($0.esPostre ? ", postre" : ""))" }.joined(separator: "; ")
    return """
    Usuario: chico nacido el 12/12/2010 (15 años), \(cuerpo), ~20% de grasa al empezar, en pleno crecimiento. Nivel: calistenia avanzada (15 dominadas, dominada con +20 kg, advanced tuck front lever), escala boulder 1–2 veces por semana y juega pádel los miércoles. Tiene una lesión vieja en el codo izquierdo (fibrosis). Metas: crecer al máximo en estatura y ganar músculo y fuerza (calistenia, escalada boulder y pádel). Come comida mexicana.
    Hora actual: \(Fecha.hora(Fecha.minutes(of: hoy))). Hoy es \(p.libre ? "día libre (sin escuela)" : "día de escuela"). Entreno de hoy: \(plan.titulo).
    Proteína registrada hoy: \(l.protein) de \(store.settings.proteinGoal) g.
    Postres esta semana: \(store.postresSemana()) de \(store.settings.dessertsPerWeek) permitidos (los refrescos cuentan como postre).
    Comidas marcadas hoy: \(comidas).
    Ya registró hoy con foto: \(regs.isEmpty ? "nada" : regs).
    Horario de hoy: desayuno \(Fecha.hora(p.breakfast)), snack \(Fecha.hora(p.snack)), comida \(Fecha.hora(p.lunch)), snack antes de entrenar \(Fecha.hora(p.preWorkout)), cena \(Fecha.hora(p.dinner)), dormir \(Fecha.hora(p.bed)).
    Alimentos que sí come: huevo, tortilla, arroz, pollo en pacholas, espagueti con queso, tacos de bistec, barbacoa y pastor, chilaquiles verdes, hot cakes, queso, panela, jamón de pavo, frijoles, leche, yogur, avena, cereal, pan, camarón, pescado empanizado, chuleta, quesadillas, fruta (plátano, manzana, pera, uvas, melón, sandía, papaya), lechuga, pepino, jitomate.
    """
}

extension UIImage {
    func reducida(_ lado: CGFloat) -> UIImage {
        let escala = Swift.min(1, lado / Swift.max(size.width, size.height))
        if escala >= 1 { return self }
        let nuevo = CGSize(width: size.width * escala, height: size.height * escala)
        return UIGraphicsImageRenderer(size: nuevo).image { _ in draw(in: CGRect(origin: .zero, size: nuevo)) }
    }
}

// MARK: - Sección en "Hoy"

struct ComidaHoySection: View {
    @EnvironmentObject var store: Store
    @ObservedObject var fs = FoodStore.shared
    let fecha: Date
    @State private var mostrarFoto = false
    @State private var consejo = ""
    @State private var pidiendo = false

    var body: some View {
        let lista = fs.de(fecha)
        Section("🍽️ Comida de hoy") {
            Button { mostrarFoto = true } label: {
                Label("Tomarle foto a mi comida", systemImage: "camera.fill").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .sheet(isPresented: $mostrarFoto) { FotoComidaView().environmentObject(store) }

            if !lista.isEmpty {
                let kcal = lista.reduce(0) { $0 + $1.kcal }
                let prot = lista.reduce(0) { $0 + $1.proteina }
                let gras = lista.reduce(0) { $0 + $1.grasas }
                Text(verbatim: "Total con foto: \(kcal) kcal · \(prot) g proteína · \(gras) g grasa")
                    .font(.footnote.bold())
                ForEach(lista) { e in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: "\(e.esPostre ? "🍰" : "🍽️") \(e.nombre)").font(.subheadline.bold())
                        Text(verbatim: "\(e.kcal) kcal · \(e.proteina) g prot · \(e.carbs) g carbs · \(e.grasas) g grasa · trans \(String(format: "%.1f", e.trans)) g")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .onDelete { idx in
                    let borrar = idx.map { lista[$0] }
                    for e in borrar { fs.borrar(e, store: store) }
                }
            }

            Button {
                Task { await pedirConsejo() }
            } label: {
                Label(pidiendo ? "Pensando…" : "Consejo de la IA sobre mi día", systemImage: "sparkles")
            }
            .disabled(pidiendo || store.settings.geminiKey.isEmpty)
            if !consejo.isEmpty {
                Text(LocalizedStringKey(consejo)).font(.callout)
            }
        }
    }

    func pedirConsejo() async {
        pidiendo = true
        defer { pidiendo = false }
        let prompt = contextoDelDia(store, fs)
            + "\nResumen del día: " + store.resumenCorto(Date())
            + "\nDame de 3 a 5 consejos cortos y concretos en español mexicano para lo que queda del día y para mañana, para crecer al máximo en estatura, músculo y fuerza (sueño, comida y entreno). Usa viñetas con emoji, sin títulos. Nunca sugieras comer menos ni saltarse comidas."
        do {
            consejo = try await Gemini.llamar(key: store.settings.geminiKey, partes: [["text": prompt]])
        } catch {
            consejo = "No se pudo: \(error.localizedDescription)"
        }
    }
}

// MARK: - Pantalla de foto

struct FotoComidaView: View {
    @EnvironmentObject var store: Store
    @ObservedObject var fs = FoodStore.shared
    @Environment(\.dismiss) private var dismiss

    @State private var imagen: UIImage?
    @State private var item: PhotosPickerItem?
    @State private var camara = false
    @State private var nota = ""
    @State private var cargando = false
    @State private var resultado: AnalisisComida?
    @State private var fallo = ""
    @State private var comidaSel: Comida = .comida
    @State private var esPostre = false
    @State private var clave = ""

    var body: some View {
        NavigationStack {
            Form {
                if store.settings.geminiKey.isEmpty {
                    Section("🔑 Primero: tu clave gratis de Gemini") {
                        Text("1. Toca el link de abajo (Google AI Studio).\n2. Entra con tu cuenta de Google.\n3. Toca \"Create API key\" y cópiala.\n4. Pégala aquí abajo y dale Guardar.")
                            .font(.footnote)
                        Link("Abrir Google AI Studio", destination: URL(string: "https://aistudio.google.com/apikey")!)
                        SecureField("Pega tu clave aquí", text: $clave)
                        Button("Guardar clave") {
                            store.settings.geminiKey = clave.trimmingCharacters(in: .whitespacesAndNewlines)
                            store.save()
                        }
                        .disabled(clave.isEmpty)
                    }
                } else {
                    Section {
                        if let img = imagen {
                            Image(uiImage: img).resizable().scaledToFit()
                                .frame(maxHeight: 260)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        HStack {
                            Button { camara = true } label: { Label("Cámara", systemImage: "camera") }
                                .buttonStyle(.bordered)
                            Spacer()
                            PhotosPicker(selection: $item, matching: .images) { Label("Galería", systemImage: "photo") }
                                .buttonStyle(.bordered)
                        }
                        TextField("Detalles (opcional): ej. 3 tacos con refresco", text: $nota, axis: .vertical)
                        Button {
                            Task { await analizar() }
                        } label: {
                            Label(cargando ? "Analizando…" : "Analizar con IA", systemImage: "sparkles").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(imagen == nil || cargando)
                        if !fallo.isEmpty { Text(fallo).font(.footnote).foregroundStyle(.red) }
                    }

                    if let r = resultado {
                        Section(r.nombre ?? "Resultado") {
                            if let p = r.porcion { Text(verbatim: "Porción: \(p)").font(.footnote) }
                            fila("🔥 Calorías", "\(Int(r.calorias ?? 0)) kcal")
                            fila("🥩 Proteína", g(r.proteina_g))
                            fila("🍚 Carbohidratos", g(r.carbohidratos_g))
                            fila("🧈 Grasas", g(r.grasas_g))
                            fila("    Saturadas", g(r.grasas_saturadas_g))
                            fila("    Trans", String(format: "%.1f g", r.grasas_trans_g ?? 0))
                            fila("🍬 Azúcar", g(r.azucar_g))
                            fila("🌾 Fibra", g(r.fibra_g))
                        }
                        if let c = r.comentario, !c.isEmpty {
                            Section("💬 La IA dice") { Text(c) }
                        }
                        Section("Guardar") {
                            Picker("Es mi…", selection: $comidaSel) {
                                ForEach(Comida.allCases) { c in Text("\(c.emoji) \(c.titulo)").tag(c) }
                            }
                            Toggle("🍰 Cuenta como postre", isOn: $esPostre)
                            Button { guardar(r) } label: {
                                Label("Agregar a mi día", systemImage: "plus.circle.fill").frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }

                    Section {
                        Button("Cambiar clave de Gemini", role: .destructive) {
                            store.settings.geminiKey = ""
                            store.save()
                        }
                    }
                }
            }
            .navigationTitle("📸 Mi comida")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cerrar") { dismiss() } }
            }
            .onChange(of: item) { _, nuevo in
                Task {
                    if let d = try? await nuevo?.loadTransferable(type: Data.self), let img = UIImage(data: d) {
                        imagen = img
                        resultado = nil
                    }
                }
            }
            .fullScreenCover(isPresented: $camara) {
                CamaraView(imagen: $imagen).ignoresSafeArea()
            }
        }
    }

    func fila(_ a: String, _ b: String) -> some View {
        HStack { Text(a); Spacer(); Text(b).bold() }
    }

    func g(_ v: Double?) -> String { "\(Int((v ?? 0).rounded())) g" }

    func analizar() async {
        guard let img = imagen else { return }
        cargando = true
        fallo = ""
        resultado = nil
        defer { cargando = false }
        guard let jpg = img.reducida(1024).jpegData(compressionQuality: 0.7) else {
            fallo = "No pude leer la foto."
            return
        }
        let prompt = Gemini.promptFoto(contexto: contextoDelDia(store, fs), nota: nota)
        do {
            let texto = try await Gemini.llamar(key: store.settings.geminiKey, partes: [
                ["text": prompt],
                ["inline_data": ["mime_type": "image/jpeg", "data": jpg.base64EncodedString()]]
            ])
            guard let data = Gemini.extraerJSON(texto),
                  let r = try? JSONDecoder().decode(AnalisisComida.self, from: data) else {
                fallo = "La IA respondió algo raro. Intenta otra vez."
                return
            }
            resultado = r
            esPostre = r.es_postre ?? false
            if let c = r.comida, let cc = Comida(rawValue: c) { comidaSel = cc }
        } catch {
            fallo = error.localizedDescription
        }
    }

    func guardar(_ r: AnalisisComida) {
        let e = FoodEntry(nombre: r.nombre ?? "Comida",
                          kcal: Int((r.calorias ?? 0).rounded()),
                          proteina: Int((r.proteina_g ?? 0).rounded()),
                          carbs: Int((r.carbohidratos_g ?? 0).rounded()),
                          grasas: Int((r.grasas_g ?? 0).rounded()),
                          trans: r.grasas_trans_g ?? 0,
                          azucar: Int((r.azucar_g ?? 0).rounded()),
                          esPostre: esPostre,
                          comida: comidaSel.rawValue,
                          comentario: r.comentario ?? "")
        fs.agregar(e, store: store)
        dismiss()
    }
}

// MARK: - Cámara

struct CamaraView: UIViewControllerRepresentable {
    @Binding var imagen: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coord { Coord(self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let p = UIImagePickerController()
        p.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        p.delegate = context.coordinator
        return p
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coord: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let padre: CamaraView
        init(_ p: CamaraView) { padre = p }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let img = info[.originalImage] as? UIImage { padre.imagen = img }
            padre.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            padre.dismiss()
        }
    }
}
