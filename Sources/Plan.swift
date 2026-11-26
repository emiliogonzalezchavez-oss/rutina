import Foundation

// MARK: - Ejercicios

enum Tipo: String, Codable {
    case lastre      // peso + reps
    case reps        // solo reps
    case hold        // segundos
}

struct Ejercicio: Identifiable, Hashable {
    var id: String { nombre }
    let nombre: String
    let series: Int
    let objetivo: String      // texto: "3–5", "8–12 s"
    let tipo: Tipo
    let minReps: Int
    let maxReps: Int          // al llegar aquí en todas las series → subir dificultad
    let descanso: Int         // segundos
    let nota: String
}

enum TipoDia {
    case calistenia, escalada, padel, descanso, opcional
}

struct DiaPlan {
    let titulo: String
    let emoji: String
    let tipo: TipoDia
    let ejercicios: [Ejercicio]
    let nota: String
}

enum Plan {
    static let movilidadCodo = Ejercicio(
        nombre: "Movilidad codo izquierdo", series: 3, objetivo: "30 s", tipo: .hold,
        minReps: 30, maxReps: 30, descanso: 20,
        nota: "Estira el codo suave hacia la extensión, sin dolor. Gira la muñeca palma arriba/abajo. Hazlo al inicio de cada sesión.")

    // Lunes: Tirón + Front lever (pesado)
    static let tiron: [Ejercicio] = [
        movilidadCodo,
        Ejercicio(nombre: "Dominadas lastradas", series: 4, objetivo: "3–5 reps", tipo: .lastre,
                  minReps: 3, maxReps: 5, descanso: 180,
                  nota: "Empieza con 15 kg. Cuando hagas 4×5, súbele 1–2 kg. Para cada serie a 1–2 reps del fallo."),
        Ejercicio(nombre: "Front lever (hold)", series: 5, objetivo: "8–12 s", tipo: .hold,
                  minReps: 8, maxReps: 15, descanso: 150,
                  nota: "Advanced tuck en tu tubo. Cuando aguantes 3×15 s → una pierna estirada → straddle → completo. Pon discos en la base de la torre."),
        Ejercicio(nombre: "Front lever raises", series: 3, objetivo: "5 reps", tipo: .reps,
                  minReps: 5, maxReps: 8, descanso: 120,
                  nota: "Sube lento y controlado desde colgado hasta la posición."),
        Ejercicio(nombre: "Negativas a un brazo", series: 4, objetivo: "1–2 por brazo", tipo: .hold,
                  minReps: 5, maxReps: 8, descanso: 150,
                  nota: "Anota los segundos que tardas en bajar (meta 6–8 s). Nunca al fallo. Si el codo izquierdo truena con dolor, para con ese brazo."),
        Ejercicio(nombre: "Lock-offs 90° y 120°", series: 3, objetivo: "5–8 s por ángulo", tipo: .hold,
                  minReps: 5, maxReps: 8, descanso: 120,
                  nota: "Por brazo. Son los ángulos donde te atoras en la dominada a un brazo."),
        Ejercicio(nombre: "Toes to bar", series: 3, objetivo: "10 reps", tipo: .reps,
                  minReps: 8, maxReps: 12, descanso: 90,
                  nota: "Sin balancearte (la torre se puede mover)."),
    ]

    // Martes: Empuje + piernas (cuidando el codo)
    static let empuje: [Ejercicio] = [
        movilidadCodo,
        Ejercicio(nombre: "Fondos en paralelas", series: 4, objetivo: "8–12 reps", tipo: .lastre,
                  minReps: 8, maxReps: 12, descanso: 150,
                  nota: "Rango cómodo, SIN bloquear el codo arriba. Lastre máx 5 kg y solo si no duele. Si truena con dolor, quita el lastre."),
        Ejercicio(nombre: "Pike push-ups / HSPU en pared", series: 4, objetivo: "5–8 reps", tipo: .reps,
                  minReps: 5, maxReps: 8, descanso: 120,
                  nota: "Rango parcial si el codo molesta. Usa las push-up bars para la muñeca."),
        Ejercicio(nombre: "Planche lean", series: 4, objetivo: "15–20 s", tipo: .hold,
                  minReps: 15, maxReps: 20, descanso: 90,
                  nota: "Manos giradas hacia afuera (más amable con el codo). Hombros adelante de las manos."),
        Ejercicio(nombre: "Flexiones en push-up bars", series: 3, objetivo: "12–15 reps", tipo: .reps,
                  minReps: 12, maxReps: 15, descanso: 90,
                  nota: "Para volumen y tamaño de pecho."),
        Ejercicio(nombre: "Sentadilla búlgara con mancuernas", series: 4, objetivo: "8 por pierna", tipo: .lastre,
                  minReps: 8, maxReps: 10, descanso: 120,
                  nota: "Pie de atrás en el banco. Sube peso cuando hagas 4×10."),
        Ejercicio(nombre: "Pistol squat", series: 3, objetivo: "5 por pierna", tipo: .reps,
                  minReps: 5, maxReps: 8, descanso: 90,
                  nota: "Agárrate de la torre si lo necesitas."),
        Ejercicio(nombre: "Saltos (cajón o largos)", series: 3, objetivo: "5", tipo: .reps,
                  minReps: 5, maxReps: 5, descanso: 90,
                  nota: "Explosivos, para el pádel y la escalada."),
        Ejercicio(nombre: "Dragon flag negativo", series: 3, objetivo: "5 reps", tipo: .reps,
                  minReps: 5, maxReps: 8, descanso: 90,
                  nota: "Bájalo en 5 segundos, agarrado del banco."),
    ]

    // Viernes: Front lever + tamaño (volumen)
    static let volumen: [Ejercicio] = [
        movilidadCodo,
        Ejercicio(nombre: "Front lever (hold)", series: 4, objetivo: "máx s", tipo: .hold,
                  minReps: 8, maxReps: 15, descanso: 150,
                  nota: "Misma progresión que el lunes, pero sin llegar al fallo."),
        Ejercicio(nombre: "Front lever negativas", series: 3, objetivo: "3 reps", tipo: .reps,
                  minReps: 3, maxReps: 5, descanso: 120,
                  nota: "Desde invertido, baja lento manteniendo el cuerpo recto."),
        Ejercicio(nombre: "Dominadas sin lastre", series: 3, objetivo: "8–12 reps", tipo: .reps,
                  minReps: 8, maxReps: 12, descanso: 120,
                  nota: "Las 2 primeras a 1–2 del fallo. La última sí al fallo."),
        Ejercicio(nombre: "Remo invertido", series: 3, objetivo: "10–12 reps", tipo: .reps,
                  minReps: 10, maxReps: 12, descanso: 90,
                  nota: "En el tubo bajo de la torre."),
        Ejercicio(nombre: "Curl martillo con mancuernas", series: 3, objetivo: "10–12 reps", tipo: .lastre,
                  minReps: 10, maxReps: 12, descanso: 75,
                  nota: "Para tamaño de brazo. Sube peso cuando hagas 3×12."),
        Ejercicio(nombre: "Elevaciones laterales", series: 3, objetivo: "12–15 reps", tipo: .lastre,
                  minReps: 12, maxReps: 15, descanso: 60,
                  nota: "Hombros más anchos. Peso ligero, controlado."),
        Ejercicio(nombre: "Flexiones", series: 3, objetivo: "máx (−2)", tipo: .reps,
                  minReps: 15, maxReps: 25, descanso: 90,
                  nota: "Deja 2 reps en reserva."),
        Ejercicio(nombre: "Gripper", series: 3, objetivo: "10 reps", tipo: .reps,
                  minReps: 10, maxReps: 15, descanso: 60,
                  nota: "Resistencia media, no al máximo. Tus dedos ya trabajan mucho escalando."),
    ]

    static func dia(_ date: Date) -> DiaPlan {
        let w = Calendar.current.component(.weekday, from: date)
        switch w {
        case 2: return DiaPlan(titulo: "Tirón + Front lever", emoji: "💪", tipo: .calistenia, ejercicios: tiron,
                               nota: "Día pesado. Prioridad #1: front lever.")
        case 3: return DiaPlan(titulo: "Empuje + Piernas", emoji: "🦵", tipo: .calistenia, ejercicios: empuje,
                               nota: "Cuida el codo izquierdo: rango cómodo, sin bloquear.")
        case 4: return DiaPlan(titulo: "Pádel", emoji: "🎾", tipo: .padel, ejercicios: [movilidadCodo],
                               nota: "Disfruta. Haz la movilidad del codo antes.")
        case 5: return DiaPlan(titulo: "Escalada (boulder)", emoji: "🧗", tipo: .escalada, ejercicios: [movilidadCodo],
                               nota: "Calienta 10 min en vías fáciles. Nada de hangboard ni campus. Si te duele un dedo o el codo, para.")
        case 6: return DiaPlan(titulo: "Front lever + Tamaño", emoji: "🔥", tipo: .calistenia, ejercicios: volumen,
                               nota: "Volumen para crecer músculo.")
        case 7: return DiaPlan(titulo: "Escalada opcional", emoji: "🧗", tipo: .opcional, ejercicios: [movilidadCodo],
                               nota: "Si puedes ir a escalar, ve. Si no, descansa.")
        default: return DiaPlan(titulo: "Descanso", emoji: "😴", tipo: .descanso, ejercicios: [],
                                nota: "Descanso total. Mide tu peso y estatura en Progreso.")
        }
    }

    static func esDiaDeEntreno(_ date: Date) -> Bool {
        switch dia(date).tipo {
        case .calistenia, .escalada, .padel: return true
        default: return false
        }
    }
}

// MARK: - Comidas (con tu menú)

enum MenuPlan {
    static let desayunos = [
        "3 huevos + 2 tortillas + frijoles + vaso de leche",
        "Chilaquiles verdes con 2 huevos + vaso de leche",
        "Hot cakes + 2 huevos + vaso de leche",
        "Avena con leche y plátano + 2 huevos",
        "Cereal con leche + sándwich de jamón de pavo y panela",
        "Huevos con jamón + bolillo + vaso de leche",
        "Quesadillas con jamón + leche + fruta",
    ]
    static let snacks = [
        "Sándwich de pan de caja con jamón de pavo y panela + manzana",
        "Yogur + plátano + 2 quesadillas",
        "Torta de jamón y queso + pera",
        "Leche con chocolate + sándwich de jamón",
        "Sándwich de pavo y panela + uvas",
    ]
    static let comidas = [
        "Arroz + pacholas + frijoles + ensalada",
        "Tacos de bistec (4) + frijoles + ensalada",
        "Espagueti con queso + chuleta de cerdo + ensalada",
        "Pescado empanizado + arroz + ensalada",
        "Sopa de fideo + pacholas + tortillas",
        "Arroz + bistec + frijoles + ensalada",
        "Tacos de barbacoa (4) + frijoles + pepino",
    ]
    static let preentrenos = [
        "Plátano + yogur",
        "Manzana + vaso de leche",
        "Plátano + vaso de leche",
        "Pan de caja con panela + fruta",
    ]
    static let cenas = [
        "Quesadillas con jamón (3) + leche con chocolate",
        "Tacos al pastor (4) + fruta",
        "Huevos con jamón + tortillas + leche",
        "Tortas de papa + ensalada + vaso de leche",
        "Camarones + arroz + ensalada",
        "Hamburguesa + ensalada + fruta",
        "Tacos de bistec (3) + leche",
    ]
    static let finde = "Fin de semana: puedes meter sushi (California/Filadelfia con camarón), pizza, hot dogs o pez gato en alguna comida."

    static func opcion(_ lista: [String], _ date: Date, _ salto: Int = 0) -> String {
        let d = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 0
        return lista[(d + salto) % lista.count]
    }

    static func de(_ comida: Comida, _ date: Date) -> String {
        switch comida {
        case .desayuno: return opcion(desayunos, date)
        case .snack: return opcion(snacks, date, 2)
        case .comida: return opcion(comidas, date, 3)
        case .preentreno: return opcion(preentrenos, date, 1)
        case .cena: return opcion(cenas, date, 4)
        }
    }

    // Botones rápidos de proteína (gramos aproximados)
    static let proteinas: [(String, Int)] = [
        ("Huevo", 6), ("Vaso de leche", 8), ("Yogur", 8), ("Pacholas (porción)", 30),
        ("Bistec (porción)", 28), ("Tacos de bistec ×3", 24), ("Pastor ×3", 20), ("Barbacoa ×3", 24),
        ("Chuleta", 30), ("Jamón pavo 2 reb.", 8), ("Panela 50 g", 9), ("Queso 30 g", 7),
        ("Camarón (porción)", 22), ("Pescado empanizado", 20), ("Quesadilla", 8),
        ("Frijoles ½ taza", 7), ("Nuggets ×6", 14), ("Hamburguesa", 25),
        ("Pizza 2 reb.", 22), ("Sushi (rollo)", 12), ("Hot dog", 10), ("Hot cakes ×2", 6),
    ]
}
