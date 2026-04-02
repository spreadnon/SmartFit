import Foundation
import SwiftUI

// MARK: - App Global State
class AppData: ObservableObject {
    @Published var currentUser: User? {
        didSet {
            saveUser()
        }
    }
    
    var isLoggedIn: Bool {
        currentUser != nil
    }

    @Published var aiSmartPlan: TrainingPlan? {
        didSet {
            savePlan()
            if aiSmartPlan != nil {
                manualPlan = nil
            }
        }
    }
    @Published var manualPlan: TrainingPlan? {
        didSet {
            savePlan()
            if manualPlan != nil {
                aiSmartPlan = nil
            }
        }
    }
    @Published var records: [TrainingRecord] = [] {
        didSet {
            saveRecords()
        }
    }
    @Published var selectedTab: Int = 0
    @Published var replacementTargetId: UUID? = nil
    
    private let planKey = "saved_training_plan"
    private let manualPlanKey = "saved_manual_plan"
    private let recordsKey = "saved_training_records"
    private let userKey = "saved_user_data"
    
    init() {
        loadUser()
        loadPlan()
        loadRecords()
    }
    
    private func saveUser() {
        if let user = currentUser {
            if let encoded = try? JSONEncoder().encode(user) {
                UserDefaults.standard.set(encoded, forKey: userKey)
            }
        } else {
            UserDefaults.standard.removeObject(forKey: userKey)
        }
    }
    
    private func loadUser() {
        if let data = UserDefaults.standard.data(forKey: userKey) {
            if let decoded = try? JSONDecoder().decode(User.self, from: data) {
                self.currentUser = decoded
            }
        }
    }
    
    func addToToday(exercises: [Exercise]) {
        self.manualPlan = TrainingPlan(
            trainingSplit: "MANUAL",
            instructions: NSLocalizedString("CUSTOM SESSION", comment: ""),
            days: [TrainingDay(label: NSLocalizedString("TODAY", comment: ""), exercises: exercises)]
        )
        self.aiSmartPlan = nil
    }
    
    func convertLibraryExercises(_ libraryExercises: [LibraryExercise]) -> [Exercise] {
        return libraryExercises.enumerated().map { index, lib in
            Exercise(
                order: index + 1,
                exerciseName: lib.nameCN,
                sets: 3, // Default sets
                reps: "12", // Default reps
                equipment: lib.equipment ?? "None",
                difficulty: lib.level,
                images: lib.images,
                instructions: lib.instructions.joined(separator: "\n"),
                focusArea: lib.primaryMuscles.joined(separator: ", "),
                primaryMuscles: lib.primaryMuscles
            )
        }
    }
    
    func replaceExercise(targetId: UUID, with newLibEx: LibraryExercise) {
        let converted = convertLibraryExercises([newLibEx]).first!
        
        // 1. Check in current AI Plan
        if var plan = aiSmartPlan {
            var updated = false
            for dayIndex in 0..<plan.days.count {
                if let exIndex = plan.days[dayIndex].exercises.firstIndex(where: { $0.id == targetId }) {
                    plan.days[dayIndex].exercises[exIndex] = converted
                    updated = true
                    break
                }
            }
            if updated {
                self.aiSmartPlan = plan // Triggers didSet/save
                return
            }
        }
        
        // 2. Check in Today's Manual Exercises
        if var plan = manualPlan {
            var updated = false
            for dayIndex in 0..<plan.days.count {
                if let exIndex = plan.days[dayIndex].exercises.firstIndex(where: { $0.id == targetId }) {
                    plan.days[dayIndex].exercises[exIndex] = converted
                    updated = true
                    break
                }
            }
            if updated {
                self.manualPlan = plan // Triggers didSet/save
                return
            }
        }
    }
    
    func resetPlan() {
        self.aiSmartPlan = nil
        self.manualPlan = nil
        UserDefaults.standard.removeObject(forKey: planKey)
        UserDefaults.standard.removeObject(forKey: manualPlanKey)
    }
    
    func saveSessionRecord(exercises: [Exercise], focusArea: String, duration: TimeInterval) {
        // 记录当天训练，如果已存在则更新并累加时长
        if let index = records.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: Date()) }) {
            let oldRecord = records[index]
            let updatedRecord = TrainingRecord(
                id: oldRecord.id,
                date: oldRecord.date,
                focusArea: focusArea, // Keep latest focus area or use old? Let's use focusArea which is passed
                exercises: exercises, // Use latest exercise states (sets/reps etc)
                duration: oldRecord.duration + duration,
                isCompleted: exercises.allSatisfy { $0.isCompleted }
            )
            records[index] = updatedRecord
        } else {
            let record = TrainingRecord(
                date: Date(),
                focusArea: focusArea,
                exercises: exercises,
                duration: duration,
                isCompleted: exercises.allSatisfy { $0.isCompleted }
            )
            records.append(record)
        }
    }
    
    private func saveRecords() {
        if let encoded = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(encoded, forKey: recordsKey)
        }
    }
    
    private func loadRecords() {
        if let data = UserDefaults.standard.data(forKey: recordsKey) {
            if let decoded = try? JSONDecoder().decode([TrainingRecord].self, from: data) {
                self.records = decoded
            }
        }
    }
    
    private func savePlan() {
        if let plan = aiSmartPlan {
            if let encoded = try? JSONEncoder().encode(plan) {
                UserDefaults.standard.set(encoded, forKey: planKey)
            }
        } else {
            UserDefaults.standard.removeObject(forKey: planKey)
        }
        
        if let plan = manualPlan {
            if let encoded = try? JSONEncoder().encode(plan) {
                UserDefaults.standard.set(encoded, forKey: manualPlanKey)
            }
        } else {
            UserDefaults.standard.removeObject(forKey: manualPlanKey)
        }
    }
    
    private func loadPlan() {
        if let data = UserDefaults.standard.data(forKey: planKey) {
            if let decoded = try? JSONDecoder().decode(TrainingPlan.self, from: data) {
                self.aiSmartPlan = decoded
            }
        }
        
        if let data = UserDefaults.standard.data(forKey: manualPlanKey) {
            if let decoded = try? JSONDecoder().decode(TrainingPlan.self, from: data) {
                self.manualPlan = decoded
            }
        }
    }
}

// MARK: - API Response Models
struct PlanResponse: Codable {
    let code: Int
    let msg: String
    let data: PlanData

    func toTrainingPlan() -> TrainingPlan {
        let days = data.dailyPlans.map { dailyPlan -> TrainingDay in
            let exercises = dailyPlan.exerciseList.map { exercise -> Exercise in
                // 处理图片字符串拆分
                let splitImages = exercise.images.flatMap { $0.components(separatedBy: ",") }
                
                return Exercise(
                    order: exercise.order,
                    exerciseName: exercise.exerciseName,
                    sets: exercise.sets,
                    reps: exercise.reps,
                    equipment: exercise.equipment,
                    difficulty: exercise.difficulty,
                    images: splitImages,
                    primaryMuscles: exercise.primaryMuscles
                )
            }
            return TrainingDay(label: dailyPlan.trainingDay, exercises: exercises)
        }
        
        return TrainingPlan(trainingSplit: data.training_split, instructions: NSLocalizedString("根据您的需求智能生成的个性化计划", comment: ""), days: days)
    }
}

struct PlanData: Codable {
    let training_split: String
    let dailyPlans: [DailyPlan]

    enum CodingKeys: String, CodingKey {
        case training_split = "training_split"
        case dailyPlans = "daily_plans"
    }
}

struct DailyPlan: Codable {
    let trainingDay: String
    let exerciseList: [APIExercise]

    enum CodingKeys: String, CodingKey {
        case trainingDay = "training_day"
        case exerciseList = "exercise_list"
    }
}

struct APIExercise: Codable {
    let exerciseName: String
    let sets: Int
    let reps: String
    let order: Int
    let equipment: String
    let difficulty: String
    let images: [String]
    let primaryMuscles: [String]

    enum CodingKeys: String, CodingKey {
        case exerciseName = "exercise_name"
        case sets, reps, order, equipment, difficulty, images
        case primaryMuscles = "primary_muscles"
    }
}


// MARK: - App Internal Models

enum TrainingLevel: String, CaseIterable, Codable {
    case novice = "novice"
    case intermediate = "intermediate"
    case advanced = "advanced"
    
    var localizedName: String {
        switch self {
        case .novice: return NSLocalizedString("新手", comment: "")
        case .intermediate: return NSLocalizedString("中级", comment: "")
        case .advanced: return NSLocalizedString("高手", comment: "")
        }
    }
    
    var description: String {
        switch self {
        case .novice: return NSLocalizedString("注重基础动作，较低强度", comment: "")
        case .intermediate: return NSLocalizedString("增加负荷，中等强度", comment: "")
        case .advanced: return NSLocalizedString("每组 6-8 次，4 组，高强度", comment: "")
        }
    }
}

enum TrainingFrequency: String, CaseIterable, Codable {
    case three = "three"
    case four = "four"
    case five = "five"
    case six = "six"
    
    var localizedName: String {
        switch self {
        case .three: return NSLocalizedString("每周 3 练", comment: "")
        case .four: return NSLocalizedString("每周 4 练", comment: "")
        case .five: return NSLocalizedString("每周 5 练", comment: "")
        case .six: return NSLocalizedString("每周 6 练", comment: "")
        }
    }
}

enum TrainingScene: String, CaseIterable, Codable {
    case gym = "gym"
    case home = "home"
    case outdoor = "outdoor"
    
    var localizedName: String {
        switch self {
        case .gym: return NSLocalizedString("健身房", comment: "")
        case .home: return NSLocalizedString("居家", comment: "")
        case .outdoor: return NSLocalizedString("户外", comment: "")
        }
    }
}

enum Injury: String, CaseIterable, Codable, Identifiable {
    case shoulder = "shoulder"
    case waist = "waist"
    case knee = "knee"
    case wrist = "wrist"
    case elbow = "elbow"
    case none = "none"
    
    var id: String { self.rawValue }
    
    var localizedName: String {
        switch self {
        case .shoulder: return NSLocalizedString("肩伤", comment: "")
        case .waist: return NSLocalizedString("腰伤", comment: "")
        case .knee: return NSLocalizedString("膝伤", comment: "")
        case .wrist: return NSLocalizedString("腕伤", comment: "")
        case .elbow: return NSLocalizedString("肘伤", comment: "")
        case .none: return NSLocalizedString("无", comment: "")
        }
    }
}

struct ExerciseSet: Identifiable, Codable, Equatable {
    let id: UUID
    var weight: Double
    var reps: Int
    var isCompleted: Bool
    
    init(id: UUID = UUID(), weight: Double = 0, reps: Int = 10, isCompleted: Bool = false) {
        self.id = id
        self.weight = weight
        self.reps = reps
        self.isCompleted = isCompleted
    }
}

struct Exercise: Identifiable, Codable, Equatable {
    let id: UUID
    let order: Int
    let exerciseName: String
    var sets: Int
    var reps: String
    let equipment: String
    let difficulty: String
    let images: [String]
    let instructions: String
    let focusArea: String
    let primaryMuscles: [String]
    var exerciseSets: [ExerciseSet]
    
    init(id: UUID = UUID(), order: Int, exerciseName: String, sets: Int, reps: String, equipment: String, difficulty: String, images: [String] = [], instructions: String = "", focusArea: String = "", primaryMuscles: [String] = []) {
        self.id = id
        self.order = order
        self.exerciseName = exerciseName
        self.sets = sets
        self.reps = reps
        self.equipment = equipment
        self.difficulty = difficulty
        self.images = images
        self.instructions = instructions
        self.focusArea = focusArea
        self.primaryMuscles = primaryMuscles
        
        // 根据器械提供合理的初始重量
        let defaultWeight: Double = {
            let eq = equipment.lowercased()
            if eq.contains("barbell") || eq.contains("杠铃") { return 20.0 }
            if eq.contains("dumbbell") || eq.contains("哑铃") { return 10.0 }
            if eq.contains("machine") || eq.contains("器械") || eq.contains("cable") { return 15.0 }
            return 5.0 // 自重或其他默认值
        }()
        
        // Convert reps string to int if possible, default to 10
        let defaultReps = Int(reps.components(separatedBy: CharacterSet.decimalDigits.inverted).first ?? "10") ?? 10
        self.exerciseSets = (0..<sets).map { _ in ExerciseSet(weight: defaultWeight, reps: defaultReps) }
    }
    
    var totalVolume: Double {
        exerciseSets.filter { $0.isCompleted }.reduce(0) { $0 + ($1.weight * Double($1.reps)) }
    }
    
    var averageReps: Double {
        let completedSets = exerciseSets.filter { $0.isCompleted }
        guard !completedSets.isEmpty else { return 0.0 }
        let totalReps = completedSets.reduce(0) { $0 + $1.reps }
        return Double(totalReps) / Double(completedSets.count)
    }
    
    var isCompleted: Bool {
        !exerciseSets.isEmpty && exerciseSets.allSatisfy { $0.isCompleted }
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
}

struct TrainingDay: Identifiable, Codable {
    let id: UUID
    let label: String // A, B, C...
    var exercises: [Exercise]
    
    init(id: UUID = UUID(), label: String, exercises: [Exercise]) {
        self.id = id
        self.label = label
        self.exercises = exercises
    }
    
    var isCompleted: Bool {
        !exercises.isEmpty && exercises.allSatisfy { $0.isCompleted }
    }
}

struct TrainingPlan: Identifiable, Codable {
    let id: UUID
    let trainingSplit: String
    let instructions: String
    var days: [TrainingDay]
    let createdAt: Date
    
    init(id: UUID = UUID(), trainingSplit: String, instructions: String, days: [TrainingDay]) {
        self.id = id
        self.trainingSplit = trainingSplit
        self.instructions = instructions
        self.days = days
        self.createdAt = Date()
    }
}

struct TrainingRecord: Identifiable, Codable {
    let id: UUID
    let date: Date
    let focusArea: String
    let exercises: [Exercise]
    let duration: TimeInterval
    let isCompleted: Bool
    
    init(id: UUID = UUID(), date: Date, focusArea: String, exercises: [Exercise], duration: TimeInterval = 0, isCompleted: Bool) {
        self.id = id
        self.date = date
        self.focusArea = focusArea
        self.exercises = exercises
        self.duration = duration
        self.isCompleted = isCompleted
    }
}

struct User: Codable {
    let id: Int
    let appleSub: String?
    let email: String?
    let name: String?
    let token: String?
    
    enum CodingKeys: String, CodingKey {
        case id = "user_id"
        case appleSub = "apple_sub"
        case email, name, token
    }
}


/**
 abdominals - 腹肌
 abductors - 外展肌（髋外展肌群）
 adductors - 内收肌（髋内收肌群）
 biceps - 肱二头肌
 calves - 小腿肌
 chest - 胸部
 forearms - 前臂
 glutes - 臀肌
 hamstrings - 腘绳肌（大腿后侧）
 lats - 背阔肌
 lower back - 下背
 middle back - 中背
 neck - 颈部
 quadriceps - 股四头肌（大腿前侧）
 shoulders - 肩部
 traps - 斜方肌
 triceps - 肱三头肌
 */
