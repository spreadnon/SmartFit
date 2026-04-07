import Foundation

let hostName = "http://10.108.2.95:8001"

class NetworkManager {
    static let shared = NetworkManager()
    private init() {}

    func generatePlan(level: TrainingLevel, frequency: TrainingFrequency, scene: TrainingScene, injuries: Set<Injury>, token: String? = nil, completion: @escaping (Result<TrainingPlan, Error>) -> Void) {
        let urlString = hostName + "/generate-plan" // 请尝试替换为您的电脑局域网 IP
        print("🚀 发送请求到: \(urlString)")
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 300 // 增加到 60 秒，生成计划可能较慢
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = token {
            print("🚀 发送请求时添加 token: \(token)")
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let injuryString = injuries.contains(.none) ? "无" : injuries.map { $0.rawValue }.joined(separator: " + ")
        let userInput = "\(level.rawValue)，\(frequency.rawValue)，\(scene.rawValue)，\(injuryString)"
        let requestBody = ["user_input": userInput]

        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            completion(.failure(error))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(NSError(domain: "", code: -2, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }

            do {
                let apiResponse = try JSONDecoder().decode(PlanResponse.self, from: data)
                let trainingPlan = apiResponse.toTrainingPlan()
                DispatchQueue.main.async {
                    completion(.success(trainingPlan))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    func saveTraining(record: TrainingRecord, token: String?, completion: @escaping (Result<Void, Error>) -> Void) {
        let urlString = hostName + "/savetraining"
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = token {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            request.httpBody = try encoder.encode(record)
        } catch {
            completion(.failure(error))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            // Check status code
            if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                completion(.failure(NSError(domain: "", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error: \(httpResponse.statusCode)"])))
                return
            }

            DispatchQueue.main.async {
                completion(.success(()))
            }
        }.resume()
    }
    
    func getTraining(date: Date? = nil, token: String?, completion: @escaping (Result<TrainingRecord?, Error>) -> Void) {
        var components = URLComponents(string: hostName + "/api/training/gettraining")
        if let date = date {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            components?.queryItems = [URLQueryItem(name: "date", value: formatter.string(from: date))]
        }
        
        guard let url = components?.url else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        if let token = token {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.success(nil))
                return
            }
            
            if let jsonString = String(data: data, encoding: .utf8) {
                print("🚀 GET Training Response JSON: \(jsonString)")
            }
            
            // Check status code
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 404 {
                // Not found is a valid case (no record for that day)
                DispatchQueue.main.async {
                    completion(.success(nil))
                }
                return
            }

            do {
                // 后端返回的是一个数组，每个元素是一个动作日志
                struct WrappedRecordResponse: Codable {
                    let code: Int
                    let msg: String?
                    let data: [RemoteTrainingLog]?
                }
                
                let decoder = JSONDecoder()
                let wrapped = try decoder.decode(WrappedRecordResponse.self, from: data)
                
                if let logs = wrapped.data, !logs.isEmpty {
                    // 将服务器返回的打平后的日志数组转换回 TrainingRecord 结构
                    let dateString = logs.first?.logDate ?? ""
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                    let date = formatter.date(from: dateString) ?? Date()
                    
                    let exercises = logs.map { log -> Exercise in
                        // 为每个动作创建一个 Exercise 对象
                        var exercise = Exercise(
                            order: 1, // 顺序信息暂时不全，设为1
                            exerciseName: log.exerciseName,
                            sets: log.sets,
                            reps: log.reps,
                            equipment: "",
                            difficulty: ""
                        )
                        // 根据 weight 设置各组数据（假设各组重量一致）
                        let repsInt = Int(log.reps.components(separatedBy: CharacterSet.decimalDigits.inverted).first ?? "10") ?? 10
                        exercise.exerciseSets = (0..<log.sets).map { _ in
                            ExerciseSet(weight: log.weight, reps: repsInt, isCompleted: true)
                        }
                        return exercise
                    }
                    
                    let record = TrainingRecord(
                        date: date,
                        focusArea: "REMOTE SYNC",
                        exercises: exercises,
                        duration: 0, // 后端没存时长，设为0
                        isCompleted: true
                    )
                    
                    DispatchQueue.main.async {
                        completion(.success(record))
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(.success(nil))
                    }
                }
            } catch {
                print("Decoding failed for getTraining: \(error)")
                completion(.failure(error))
            }
        }.resume()
    }
}
