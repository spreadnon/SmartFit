import Foundation
import SwiftUI

// MARK: - App Global State
class AppData: ObservableObject {
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
    @Published var records: [TrainingRecord] = []
    @Published var selectedTab: Int = 0
    @Published var replacementTargetId: UUID? = nil
    
    private let planKey = "saved_training_plan"
    private let manualPlanKey = "saved_manual_plan"
    
    init() {
        loadPlan()
    }
    
    func addToToday(exercises: [Exercise]) {
        self.manualPlan = TrainingPlan(
            trainingSplit: "MANUAL",
            instructions: "CUSTOM SESSION",
            days: [TrainingDay(label: "TODAY", exercises: exercises)]
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
                focusArea: lib.primaryMuscles.joined(separator: ", ")
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
                    images: splitImages
                )
            }
            return TrainingDay(label: dailyPlan.trainingDay, exercises: exercises)
        }
        
        return TrainingPlan(trainingSplit: data.training_split, instructions: "根据您的需求智能生成的个性化计划", days: days)
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

    enum CodingKeys: String, CodingKey {
        case exerciseName = "exercise_name"
        case sets, reps, order, equipment, difficulty, images
    }
}


// MARK: - App Internal Models

enum TrainingLevel: String, CaseIterable, Codable {
    case novice = "新手"
    case intermediate = "中级"
    case advanced = "高手"
    
    var description: String {
        switch self {
        case .novice: return "注重基础动作，较低强度"
        case .intermediate: return "增加负荷，中等强度"
        case .advanced: return "每组 6-8 次，4 组，高强度"
        }
    }
}

enum TrainingFrequency: String, CaseIterable, Codable {
    case three = "每周 3 练"
    case four = "每周 4 练"
    case five = "每周 5 练"
    case six = "每周 6 练"
}

enum TrainingScene: String, CaseIterable, Codable {
    case gym = "健身房"
    case home = "居家"
    case outdoor = "户外"
}

enum Injury: String, CaseIterable, Codable, Identifiable {
    case shoulder = "肩伤"
    case waist = "腰伤"
    case knee = "膝伤"
    case wrist = "腕伤"
    case elbow = "肘伤"
    case none = "无"
    
    var id: String { self.rawValue }
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
    var exerciseSets: [ExerciseSet]
    
    init(id: UUID = UUID(), order: Int, exerciseName: String, sets: Int, reps: String, equipment: String, difficulty: String, images: [String] = [], instructions: String = "", focusArea: String = "") {
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
    let isCompleted: Bool
    
    init(id: UUID = UUID(), date: Date, focusArea: String, isCompleted: Bool) {
        self.id = id
        self.date = date
        self.focusArea = focusArea
        self.isCompleted = isCompleted
    }
}
