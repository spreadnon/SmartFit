import Foundation

struct LibraryExercise: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let nameCN: String
    let force: String?
    let level: String
    let mechanic: String?
    let equipment: String?
    let primaryMuscles: [String]
    let secondaryMuscles: [String]
    let instructions: [String]
    let category: String
    let images: [String]
    
    // Helper to get localized name
    var displayName: String {
        let locale = Locale.current.language.languageCode?.identifier ?? "en"
        return locale.contains("zh") ? nameCN : name
    }
    
    // Helper to get formatted primary muscles
    var muscleLabel: String {
        localizedMuscleNames.joined(separator: " / ").uppercased()
    }
    
    var localizedMuscleNames: [String] {
        let mapping: [String: String] = [
            "abdominals": "腹肌",
            "abductors": "外展肌",
            "adductors": "内收肌",
            "biceps": "肱二头肌",
            "calves": "小腿肌",
            "chest": "胸部",
            "forearms": "前臂",
            "glutes": "臀肌",
            "hamstrings": "腘绳肌",
            "lats": "背阔肌",
            "lower back": "下背",
            "middle back": "中背",
            "neck": "颈部",
            "quadriceps": "股四头肌",
            "shoulders": "肩部",
            "traps": "斜方肌",
            "triceps": "肱三头肌"
        ]
        
        return primaryMuscles.map { mapping[$0.lowercased()] ?? $0 }
    }
    
    // Helper to get the first image path
    var thumbnailPath: String? {
        images.first
    }
}

class ExerciseLibraryStore: ObservableObject {
    @Published var exercises: [LibraryExercise] = []
    @Published var isLoading = false
    
    static let shared = ExerciseLibraryStore()
    
    private init() {
        loadExercises()
    }
    
    func loadExercises() {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            // ✅ 修复：去掉 inDirectory: "dist"，直接从主Bundle读取
            guard let path = Bundle.main.path(forResource: "exercises", ofType: "json") else {
                print("❌ 无法找到 exercises.json 文件")
                DispatchQueue.main.async {
                    self.isLoading = false
                }
                return
            }
            self.loadFromPath(path)
        }
    }
        
    private func loadFromPath(_ path: String) {
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            let decoder = JSONDecoder()
            let decoded = try decoder.decode([LibraryExercise].self, from: data)
            DispatchQueue.main.async {
                self.exercises = decoded
                self.isLoading = false
                print("✅ 成功加载 exercises.json")
            }
        } catch {
            print("❌ 加载失败: \(error)")
            DispatchQueue.main.async {
                self.isLoading = false
            }
        }
    }
}
