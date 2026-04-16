import Foundation

let hostName = "http://10.108.2.95:8001"

class NetworkManager {
    static let shared = NetworkManager()
    private init() {}

    private func handleResponse<T: Decodable>(_ data: Data?, _ response: URLResponse?, _ error: Error?, completion: @escaping (Result<T, Error>) -> Void) {
        if let error = error {
            DispatchQueue.main.async { completion(.failure(error)) }
            return
        }

        guard let data = data else {
            DispatchQueue.main.async { completion(.failure(NSError(domain: "NetworkManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "No data received"]))) }
            return
        }

        // Check for business codes in JSON first
        if let base = try? JSONDecoder().decode(BaseResponse.self, from: data) {
            if base.code == 401 {
                print("🚨 401 Unauthorized detected in JSON code")
                NotificationCenter.default.post(name: .unauthorized, object: nil)
                DispatchQueue.main.async { completion(.failure(NSError(domain: "NetworkManager", code: 401, userInfo: [NSLocalizedDescriptionKey: base.msg ?? "登录已过期"]))) }
                return
            } else if base.code == 500 {
                print("🚨 500 Server Error detected in JSON code")
                DispatchQueue.main.async { completion(.failure(NSError(domain: "NetworkManager", code: 500, userInfo: [NSLocalizedDescriptionKey: base.msg ?? "服务器内部错误"]))) }
                return
            }
        }

        // Check HTTP status code
        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode == 401 {
                print("🚨 401 Unauthorized detected in HTTP status")
                NotificationCenter.default.post(name: .unauthorized, object: nil)
                DispatchQueue.main.async { completion(.failure(NSError(domain: "NetworkManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "登录已过期"]))) }
                return
            } else if (500...599).contains(httpResponse.statusCode) {
                print("🚨 \(httpResponse.statusCode) Server Error detected in HTTP status")
                DispatchQueue.main.async { completion(.failure(NSError(domain: "NetworkManager", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "服务器错误: \(httpResponse.statusCode)"]))) }
                return
            }
        }

        do {
            let decoded = try JSONDecoder().decode(T.self, from: data)
            DispatchQueue.main.async { completion(.success(decoded)) }
        } catch {
            print("❌ Decoding error: \(error)")
            DispatchQueue.main.async { completion(.failure(error)) }
        }
    }

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
            self.handleResponse(data, response, error) { (result: Result<PlanResponse, Error>) in
                switch result {
                case .success(let apiResponse):
                    completion(.success(apiResponse.toTrainingPlan()))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }.resume()
    }

    func saveTraining(record: TrainingRecord, token: String?, completion: @escaping (Result<Void, Error>) -> Void) {
        let urlString = hostName + "/api/training/savetraining"
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
            self.handleResponse(data, response, error) { (result: Result<BaseResponse, Error>) in
                switch result {
                case .success:
                    completion(.success(()))
                case .failure(let error):
                    completion(.failure(error))
                }
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
            // 特殊处理 404
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 404 {
                DispatchQueue.main.async { completion(.success(nil)) }
                return
            }

            self.handleResponse(data, response, error) { (result: Result<TrainingHistoryResponse, Error>) in
                switch result {
                case .success(let history):
                    if let historyList = history.data, let historyData = historyList.first {
                        // Map the new structured response to the internal TrainingRecord
                        let df = DateFormatter()
                        df.dateFormat = "yyyy-MM-dd"
                        let date = df.date(from: historyData.date) ?? Date()
                        
                        let exercises = historyData.exercises.map { hEx -> Exercise in
                            var exercise = Exercise(
                                order: 1,
                                exerciseName: hEx.exerciseName,
                                sets: hEx.sets,
                                reps: "\(hEx.detailedSets.first?.reps ?? 10)",
                                equipment: "",
                                difficulty: ""
                            )
                            // In the new API, maxWeight is provided per exercise
                            // The detailedSets contain the actual recorded sets
                            exercise.exerciseSets = hEx.detailedSets
                            return exercise
                        }
                        
                        let record = TrainingRecord(
                            date: date,
                            focusArea: historyData.summary.focusAreas.joined(separator: " / "),
                            exercises: exercises,
                            duration: historyData.summary.totalDuration,
                            isCompleted: true // If it's in history, it's generally considered completed
                        )
                        completion(.success(record))
                    } else {
                        completion(.success(nil))
                    }
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }.resume()
    }
}
