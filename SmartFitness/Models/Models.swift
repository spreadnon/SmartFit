import Foundation
import SwiftUI

extension Notification.Name {
    static let unauthorized = Notification.Name("apiUnauthorized")
}

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
    @Published var libraryInsertionTarget: LibraryInsertionTarget? = nil
    
    private let planKey = "saved_training_plan"
    private let manualPlanKey = "saved_manual_plan"
    private let recordsKey = "saved_training_records"
    private let userKey = "saved_user_data"
    
    init() {
        loadUser()
        loadPlan()
        loadRecords()
        
        NotificationCenter.default.addObserver(forName: .unauthorized, object: nil, queue: .main) { [weak self] _ in
            self?.handleUnauthorized()
        }
    }
    
    private func handleUnauthorized() {
        print("⚠️ 登录已过期，正在退出登录...")
        self.currentUser = nil
        resetPlan()
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
        guard !exercises.isEmpty else { return }

        if let target = libraryInsertionTarget {
            libraryInsertionTarget = nil
            if addExercises(exercises, to: target) {
                return
            }
        }

        if var plan = aiSmartPlan, !plan.days.isEmpty {
            let dayIndex = plan.days.firstIndex(where: { !$0.isCompleted }) ?? 0
            plan.days[dayIndex].exercises.append(contentsOf: exercises)
            plan.days[dayIndex].kind = .training
            self.aiSmartPlan = plan
            return
        }

        if var plan = manualPlan,
           !isManualSession(plan),
           !plan.days.isEmpty {
            let currentWeekday = Calendar.current.component(.weekday, from: Date())
            let dayIndex = plan.days.firstIndex(where: { $0.weekday == currentWeekday }) ??
                plan.days.firstIndex(where: { $0.kind == .training }) ??
                0
            plan.days[dayIndex].exercises.append(contentsOf: exercises)
            plan.days[dayIndex].kind = .training
            plan.days[dayIndex].focus = plan.days[dayIndex].focus ?? "自定义"
            self.manualPlan = plan
            return
        }

        if var plan = manualPlan, !plan.days.isEmpty, Calendar.current.isDate(plan.createdAt, inSameDayAs: Date()) {
            plan.days[0].exercises.append(contentsOf: exercises)
            plan.days[0].kind = .training
            self.manualPlan = plan
            return
        }

        self.manualPlan = TrainingPlan(
            trainingSplit: "自选训练",
            instructions: NSLocalizedString("CUSTOM SESSION", comment: ""),
            days: [TrainingDay(label: NSLocalizedString("TODAY", comment: ""), exercises: exercises)]
        )
        self.aiSmartPlan = nil
    }

    @discardableResult
    private func addExercises(_ exercises: [Exercise], to target: LibraryInsertionTarget) -> Bool {
        switch target.planType {
        case .ai:
            guard var plan = aiSmartPlan, plan.days.indices.contains(target.dayIndex) else { return false }
            plan.days[target.dayIndex].exercises.append(contentsOf: exercises)
            plan.days[target.dayIndex].kind = .training
            plan.days[target.dayIndex].focus = plan.days[target.dayIndex].focus ?? "自定义"
            self.aiSmartPlan = plan
            return true
        case .manual:
            guard var plan = manualPlan, plan.days.indices.contains(target.dayIndex) else { return false }
            plan.days[target.dayIndex].exercises.append(contentsOf: exercises)
            plan.days[target.dayIndex].kind = .training
            plan.days[target.dayIndex].focus = plan.days[target.dayIndex].focus ?? "自定义"
            self.manualPlan = plan
            return true
        }
    }

    var manualPlanForToday: TrainingPlan? {
        guard let manualPlan,
              Calendar.current.isDate(manualPlan.createdAt, inSameDayAs: Date()) else {
            return nil
        }
        return manualPlan
    }

    var manualWeeklyPlan: TrainingPlan? {
        guard let manualPlan,
              !isManualSession(manualPlan) else {
            return nil
        }
        return manualPlan
    }

    private func isManualSession(_ plan: TrainingPlan) -> Bool {
        plan.trainingSplit == "自选训练" || plan.trainingSplit == "MANUAL"
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
                primaryMuscles: lib.primaryMuscles,
                restTime: 90
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

    func removeExerciseFromToday(exerciseId: UUID) {
        if var plan = aiSmartPlan, !plan.days.isEmpty {
            let dayIndex = plan.days.firstIndex(where: { day in
                day.exercises.contains(where: { $0.id == exerciseId })
            }) ?? 0
            plan.days[dayIndex].exercises.removeAll { $0.id == exerciseId }
            self.aiSmartPlan = plan
            return
        }

        if var plan = manualPlan, !plan.days.isEmpty {
            if isManualSession(plan) {
                plan.days[0].exercises.removeAll { $0.id == exerciseId }
                self.manualPlan = plan
                return
            }

            if let dayIndex = plan.days.firstIndex(where: { day in
                day.exercises.contains(where: { $0.id == exerciseId })
            }) {
                plan.days[dayIndex].exercises.removeAll { $0.id == exerciseId }
                self.manualPlan = plan
            }
        }
    }

    func clearTodayTraining() {
        if var plan = aiSmartPlan, !plan.days.isEmpty {
            let dayIndex = plan.days.firstIndex(where: { !$0.isCompleted }) ?? 0
            plan.days[dayIndex].exercises.removeAll()
            self.aiSmartPlan = plan
            return
        }

        if let manualPlan, Calendar.current.isDate(manualPlan.createdAt, inSameDayAs: Date()) {
            self.manualPlan = nil
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
    
    func updateRecord(_ record: TrainingRecord) {
        if let index = records.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: record.date) }) {
            records[index] = record
        } else {
            records.append(record)
        }
        // records is @Published, so UI will update
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
            if var decoded = try? JSONDecoder().decode(TrainingPlan.self, from: data) {
                decoded.applyDefaultWeeklyMetadata()
                self.aiSmartPlan = decoded
            }
        }
        
        if let data = UserDefaults.standard.data(forKey: manualPlanKey) {
            if var decoded = try? JSONDecoder().decode(TrainingPlan.self, from: data) {
                decoded.applyDefaultWeeklyMetadata()
                self.manualPlan = decoded
            }
        }
    }
}

// MARK: - API Response Models
struct BaseResponse: Codable {
    let code: Int?
    let msg: String?
}

struct PlanResponse: Codable {
    let code: Int
    let msg: String
    let data: PlanData

    func toTrainingPlan() -> TrainingPlan {
        let days = data.dailyPlans.enumerated().map { index, dailyPlan -> TrainingDay in
            let exercises = dailyPlan.exerciseList.map { exercise -> Exercise in
                // 处理图片字符串拆分
                let splitImages = (exercise.images ?? []).flatMap { $0.components(separatedBy: ",") }
                
                return Exercise(
                    backendId: exercise.id,
                    order: exercise.order,
                    exerciseName: exercise.exerciseName,
                    sets: exercise.sets,
                    reps: exercise.reps,
                    equipment: exercise.equipment,
                    difficulty: exercise.difficulty,
                    images: splitImages,
                    primaryMuscles: exercise.primaryMuscles ?? [],
                    restTime: 90
                )
            }
            let kind: TrainingDayKind = exercises.isEmpty ? .rest : .training
            return TrainingDay(
                label: dailyPlan.trainingDay,
                exercises: exercises,
                kind: kind,
                weekday: defaultWeekday(for: index),
                focus: kind == .training ? inferredFocus(label: dailyPlan.trainingDay, exercises: exercises) : nil
            )
        }
        
        return TrainingPlan(trainingSplit: data.training_split, instructions: NSLocalizedString("根据您的需求智能生成的个性化计划", comment: ""), days: days)
    }

    private func defaultWeekday(for index: Int) -> Int {
        let mondayFirstWeek = [2, 3, 4, 5, 6, 7, 1]
        return mondayFirstWeek[index % mondayFirstWeek.count]
    }

    private func inferredFocus(label: String, exercises: [Exercise]) -> String {
        let labelFocus = TrainingPlan.inferredFocus(from: [label])
        if let labelFocus { return labelFocus }

        let muscles = exercises.flatMap { $0.localizedMuscleNames.isEmpty ? $0.primaryMuscles : $0.localizedMuscleNames }
        return TrainingPlan.inferredFocus(from: muscles) ?? NSLocalizedString("全身", comment: "")
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
    let id: String?
    let exerciseName: String
    let sets: Int
    let reps: String
    let order: Int
    let equipment: String
    let difficulty: String
    let images: [String]?
    let primaryMuscles: [String]?

    enum CodingKeys: String, CodingKey {
        case id
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
    
    enum CodingKeys: String, CodingKey {
        case id, weight, reps
        case isCompleted = "is_completed"
    }
    
    init(id: UUID = UUID(), weight: Double = 0, reps: Int = 10, isCompleted: Bool = false) {
        self.id = id
        self.weight = weight
        self.reps = reps
        self.isCompleted = isCompleted
    }
}

struct Exercise: Identifiable, Codable, Equatable {
    let id: UUID
    let backendId: String?
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
    var restTime: Int
    var exerciseSets: [ExerciseSet]
    
    enum CodingKeys: String, CodingKey {
        case id, order, sets, reps, equipment, difficulty, images, instructions
        case backendId = "backend_id"
        case exerciseName = "exercise_name"
        case focusArea = "focus_area"
        case primaryMuscles = "primary_muscles"
        case exerciseSets = "exercise_sets"
        case restTime = "rest_time"
    }
    
    init(id: UUID = UUID(), backendId: String? = nil, order: Int, exerciseName: String, sets: Int, reps: String, equipment: String, difficulty: String, images: [String] = [], instructions: String = "", focusArea: String = "", primaryMuscles: [String] = [], restTime: Int = 90) {
        self.id = id
        self.backendId = backendId
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
        self.restTime = restTime
        
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

enum TrainingPlanType {
    case ai
    case manual
}

struct LibraryInsertionTarget {
    let planType: TrainingPlanType
    let dayIndex: Int
}

enum TrainingDayKind: String, Codable {
    case training
    case rest
    case recovery

    var localizedTitle: String {
        switch self {
        case .training: return "训练"
        case .rest: return "休息"
        case .recovery: return "恢复"
        }
    }
}

struct TrainingDay: Identifiable, Codable {
    let id: UUID
    let label: String // A, B, C...
    var exercises: [Exercise]
    var kind: TrainingDayKind
    var weekday: Int?
    var focus: String?

    enum CodingKeys: String, CodingKey {
        case id, label, exercises, kind, weekday, focus
    }

    init(id: UUID = UUID(), label: String, exercises: [Exercise], kind: TrainingDayKind = .training, weekday: Int? = nil, focus: String? = nil) {
        self.id = id
        self.label = label
        self.exercises = exercises
        self.kind = kind
        self.weekday = weekday
        self.focus = focus
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.label = try container.decode(String.self, forKey: .label)
        self.exercises = try container.decode([Exercise].self, forKey: .exercises)
        self.kind = try container.decodeIfPresent(TrainingDayKind.self, forKey: .kind) ?? .training
        self.weekday = try container.decodeIfPresent(Int.self, forKey: .weekday)
        self.focus = try container.decodeIfPresent(String.self, forKey: .focus)
    }
    
    var isCompleted: Bool {
        if kind != .training { return false }
        return !exercises.isEmpty && exercises.allSatisfy { $0.isCompleted }
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

extension TrainingPlan {
    mutating func applyDefaultWeeklyMetadata() {
        guard !days.isEmpty else { return }

        let mondayFirstWeek = [2, 3, 4, 5, 6, 7, 1]
        for index in days.indices {
            if days[index].weekday == nil {
                days[index].weekday = mondayFirstWeek[index % mondayFirstWeek.count]
            }

            if days[index].kind == .training, days[index].focus == nil {
                let text = [days[index].label] + days[index].exercises.flatMap {
                    $0.localizedMuscleNames.isEmpty ? $0.primaryMuscles : $0.localizedMuscleNames
                }
                days[index].focus = Self.inferredFocus(from: text)
            }
        }
    }

    static func inferredFocus(from values: [String]) -> String? {
        let text = values.joined(separator: " ").lowercased()
        if text.contains("胸") || text.contains("chest") { return "胸" }
        if text.contains("背") || text.contains("back") || text.contains("lats") { return "背" }
        if text.contains("肩") || text.contains("shoulder") { return "肩" }
        if text.contains("腿") || text.contains("leg") || text.contains("quad") || text.contains("hamstring") || text.contains("calf") { return "腿" }
        if text.contains("手臂") || text.contains("臂") || text.contains("arm") || text.contains("bicep") || text.contains("tricep") { return "手臂" }
        if text.contains("腹") || text.contains("core") || text.contains("ab") { return "腹部" }
        if text.contains("臀") || text.contains("glute") { return "臀部" }
        return nil
    }
}

struct TrainingRecord: Identifiable, Codable {
    let id: UUID
    let date: Date
    let focusArea: String
    let exercises: [Exercise]
    let duration: TimeInterval
    let isCompleted: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, date, exercises, duration
        case focusArea = "focus_area"
        case isCompleted = "is_completed"
    }
    
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

// MARK: - Server Response Models
// MARK: - Updated History Response Models
struct TrainingHistoryResponse: Codable {
    let code: Int
    let msg: String?
    let data: [TrainingHistoryData]?
}

struct TrainingHistoryData: Codable {
    let date: String
    let summary: TrainingHistorySummary
    let exercises: [TrainingHistoryExercise]
}

struct TrainingHistorySummary: Codable {
    let totalVolume: Double
    let totalDuration: TimeInterval
    let focusAreas: [String]
    
    enum CodingKeys: String, CodingKey {
        case totalVolume = "total_volume"
        case totalDuration = "total_duration"
        case focusAreas = "focus_areas"
    }
}

struct TrainingHistoryExercise: Codable, Identifiable {
    var id: String { exerciseName + "\(maxWeight)" }
    let exerciseName: String
    let maxWeight: Double
    let sets: Int
    let detailedSets: [ExerciseSet]
    
    enum CodingKeys: String, CodingKey {
        case exerciseName = "exercise_name"
        case maxWeight = "max_weight"
        case sets
        case detailedSets = "detailed_sets"
    }
}

struct RemoteTrainingLog: Codable {
    let id: Int
    let exerciseName: String
    let sets: Int
    let reps: String
    let weight: Double
    let logDate: String // "2026-04-03 11:16:57"
    
    enum CodingKeys: String, CodingKey {
        case id, sets, reps, weight
        case exerciseName = "exercise_name"
        case logDate = "log_date"
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
