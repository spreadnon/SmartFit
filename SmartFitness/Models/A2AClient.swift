//
//  A2AClient.swift
//  SmartFitness
//
//  Created by Jeremy chen on 2026/3/26.
//

import Foundation

// MARK: - A2A 消息模型
struct AgentInfo: Codable {
    let agent_id: String
    let agent_name: String?
}

struct A2AMessage: Codable {
    let a2a_version: String
    let message_id: String
    let session_id: String
    let sender: AgentInfo
    let recipient: AgentInfo
    let type: String
    let action: String?
    let async: Bool?
    let payload: [String: AnyCodable]
}

// 支持任意 JSON 类型
struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self.value = NSNull()
        } else if let boolValue = try? container.decode(Bool.self) {
            self.value = boolValue
        } else if let intValue = try? container.decode(Int.self) {
            self.value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            self.value = doubleValue
        } else if let stringValue = try? container.decode(String.self) {
            self.value = stringValue
        } else if let arrayValue = try? container.decode([AnyCodable].self) {
            self.value = arrayValue.map(\.value)
        } else if let dictValue = try? container.decode([String: AnyCodable].self) {
            self.value = dictValue.mapValues(\.value)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "AnyCodable value cannot be decoded"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case is NSNull:
            try container.encodeNil()
        case let boolValue as Bool:
            try container.encode(boolValue)
        case let intValue as Int:
            try container.encode(intValue)
        case let doubleValue as Double:
            try container.encode(doubleValue)
        case let stringValue as String:
            try container.encode(stringValue)
        case let arrayValue as [Any]:
            try container.encode(arrayValue.map(AnyCodable.init))
        case let dictValue as [String: Any]:
            try container.encode(dictValue.mapValues(AnyCodable.init))
        default:
            throw EncodingError.invalidValue(
                value,
                .init(
                    codingPath: encoder.codingPath,
                    debugDescription: "AnyCodable value cannot be encoded"
                )
            )
        }
    }
}

// MARK: - A2A 通信客户端
class A2AClient {
    static let shared = A2AClient()
    //http://10.108.2.95:8001/generate-plan
    let baseURL = URL(string: hostName + "/a2a/v1/message")!
    
    // 发送同步请求
    func sendRequest(
        action: String,
        payload: [String: Any],
        completion: @escaping ([String: Any]?, Error?) -> Void
    ) {
        let msg: [String: Any] = [
            "a2a_version": "1.0",
            "message_id": UUID().uuidString,
            "session_id": "sess_test",
            "sender": [
                "agent_id": "ios_app_agent",
                "agent_name": "iOS智能体"
            ],
            "recipient": [
                "agent_id": "backend_agent"
            ],
            "type": "request",
            "action": action,
            "payload": payload
        ]
        
        var req = URLRequest(url: baseURL)
        req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: msg)
        
        URLSession.shared.dataTask(with: req) { data, _, err in
            guard let data = data, err == nil else {
                completion(nil, err)
                return
            }
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            completion(json, nil)
        }.resume()
    }
}


/**
 // 查询天气（同步）
 A2AClient.shared.sendRequest(action: "query_weather", payload: ["city": "北京"]) { res, err in
     print("返回：", res ?? "无数据")
 }

 // 生成文章（异步）
 A2AClient.shared.sendRequest(action: "generate_article", payload: ["topic": "AI 未来"]) { res, err in
     print("异步任务 ID：", res?["task_id"] ?? "")
 }
 */
