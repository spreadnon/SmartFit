//
//  A2ASSEClient.swift
//  SmartFitness
//
//  Created by Jeremy chen on 2026/3/26.
//

import Foundation

// MARK: - A2A SSE 客户端
class A2ASSEClient {
    static let shared = A2ASSEClient()
    let baseURL = URL(string: "http://10.108.2.95:8001/a2a/v1/message")!
    private var activeSession: URLSession?
    private var activeDelegate: SSEDelegate?
    private var activeTask: URLSessionDataTask?
    
    var currentTaskID: String?
    
    // 发送流式请求 → 逐字接收
    func sendStreamRequest(
        prompt: String,
        onReceive: @escaping (String) -> Void,
        onComplete: @escaping () -> Void
    ) {
        let taskID = newID()
        currentTaskID = taskID
        
        let message: [String: Any] = [
            "a2a_version": "1.0",
            "message_id": UUID().uuidString,
            "session_id": "sess_stream",
            "sender": ["agent_id": "ios_app_agent"],
            "recipient": ["agent_id": "backend_agent"],
            "type": "request",
            "action": "chat_stream",
            "payload": ["prompt": prompt]
        ]
        
        var req = URLRequest(url: baseURL)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: message)
        
        // SSE 监听
        let delegate = SSEDelegate(onReceive: onReceive) { [weak self] in
            onComplete()
            self?.activeTask?.cancel()
            self?.activeTask = nil
            self?.activeSession?.invalidateAndCancel()
            self?.activeSession = nil
            self?.activeDelegate = nil
        }
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        activeSession = session
        activeDelegate = delegate
        
        let task = session.dataTask(with: req)
        activeTask = task
        task.resume()
    }
    
    // 中断当前流式任务（核心！）
    func stopCurrentStream() {
        guard let taskID = currentTaskID else { return }
        
        // 1. 本地断开
        activeTask?.cancel()
        activeTask = nil
        activeSession?.invalidateAndCancel()
        activeSession = nil
        activeDelegate = nil
        
        // 2. 通知后端停止
        let url = URL(string: "http://10.108.2.95:8001/a2a/v1/stream/stop/\(taskID)")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        URLSession.shared.dataTask(with: req).resume()
        
        currentTaskID = nil
        print("✅ 已中断流式输出")
    }
    
    private func newID() -> String {
        return String(UUID().uuidString.prefix(8))
    }
}

// MARK: - SSE 流解析
class SSEDelegate: NSObject, URLSessionDataDelegate {
    let onReceive: (String) -> Void
    let onComplete: () -> Void
    var buffer = Data()
    
    init(onReceive: @escaping (String) -> Void, onComplete: @escaping () -> Void) {
        self.onReceive = onReceive
        self.onComplete = onComplete
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        buffer.append(data)
        guard let str = String(data: buffer, encoding: .utf8) else { return }
        
        let lines = str.components(separatedBy: "\n")
        for line in lines {
            if line.starts(with: "data: "), line.count > 6 {
                let jsonStr = line.dropFirst(6)
                if let json = try? JSONSerialization.jsonObject(with: jsonStr.data(using: .utf8)!) as? [String: Any],
                   let payload = json["payload"] as? [String: Any],
                   let content = payload["content"] as? String {
                    DispatchQueue.main.async {
                        self.onReceive(content) // 逐字输出
                    }
                }
            }
        }
        buffer.removeAll()
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        DispatchQueue.main.async {
            self.onComplete()
        }
    }
}
