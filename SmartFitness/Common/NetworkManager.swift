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
}
