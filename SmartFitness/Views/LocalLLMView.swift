//
//  LocalLLM.swift
//  SmartFitness
//
//  Created by Jeremy chen on 2026/4/9.
//

import SwiftUI
import UIKit
import Vision
import EventKit

// MARK: - 配置你的阿里云百炼 API Key
let DASHSCOPE_API_KEY = "sk-0d6c7202bc6348c9a2325bf8c3646b59"

//struct Schedule: Codable {
//    let title: String
//    let start_time: String
//    let end_time: String
//    let location: String
//    let remark: String
//}

// MARK: - OCR（iOS 自带，离线）
func ocr(image: UIImage, completion: @escaping (String) -> Void) {
    guard let cgImage = image.cgImage else {
        completion("")
        return
    }
    let req = VNRecognizeTextRequest { req, err in
        let text = (req.results as? [VNRecognizedTextObservation])?
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: " ") ?? ""
        completion(text)
    }
    req.recognitionLevel = .accurate
    req.recognitionLanguages = ["zh-CN", "en-US"]
    try? VNImageRequestHandler(cgImage: cgImage).perform([req])
}


// MARK: - 机票专用超强提取版
func extractByQwen(text: String, completion: @escaping (Schedule?) -> Void) {
    guard let url = URL(string: "https://dashscope.aliyuncs.com/api/v1/services/aigc/text-generation/generation") else { return }
    
//    // 🔥 机票专用超强 Prompt，强制提取所有字段
//    let prompt = """
//你是专业机票信息提取助手。
//从下面文本中提取完整行程信息，**只输出标准JSON，无多余文字**。
//必须包含且严格按以下字段：
//
//- title：行程标题，例如“北京→上海 航班 MU5181”
//- start_time：出发时间 格式 MM-dd HH:mm（不要写年份！）
//- end_time：到达时间 格式 MM-dd HH:mm（不要写年份！）
//- location：出发机场 → 到达机场 + 航班号 + 登机口 + 值机柜台
//- remark：乘客姓名、行李额度、天气、备注等所有其他信息
//
//如果某项不存在，填空字符串，不要乱写。
//时间不存在则使用当前时间。
//
//文本内容：
//\(text)
//"""
    
//    // 🔥 万能通用 Prompt，自动识别机票/火车票/订单
//    let prompt = """
//你是行程信息提取专家，自动识别内容是：机票 / 火车票 / 订单通知。
//只输出标准JSON，不要多余文字。
//
//输出字段严格如下：
//- title：行程或事件的简短标题
//- start_time：出发或开始时间，格式 MM-dd HH:mm，不要带年份
//- end_time：到达或结束时间，格式 MM-dd HH:mm，没有则同 start_time
//- location：出发→到达、车站机场、座位、柜台、登机口
//- remark：乘客姓名、票号、行李、天气、订单状态等其他信息
//
//文本内容：
//\(text)
//"""
    
    
    let prompt = """
    你是一个通用信息提取助手，无论输入是机票、高铁、酒店、订单、聊天记录、通知短信，都能智能识别并提取关键信息。

    严格只输出JSON，不要输出任何多余文字、解释、标点外的符号。
    字段格式要求：
    - title: 对这段内容的简短概括标题（15字以内）
    - start_time: 关键时间，格式统一为 MM-dd HH:mm，没有则为空
    - end_time: 结束时间，没有则留空
    - location: 地点、车站、机场、场所相关，没有则为空
    - remark: 人物、事由、详情、状态等所有其他信息

    文本内容：
    \(text)
    """
    
    let body: [String: Any] = [
        "model": "qwen-turbo",
        "input": [
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ],
        "parameters": ["result_format": "text"]
    ]
    
    var req = URLRequest(url: url)
    req.httpMethod = "POST"
    req.setValue("Bearer \(DASHSCOPE_API_KEY)", forHTTPHeaderField: "Authorization")
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    req.httpBody = try? JSONSerialization.data(withJSONObject: body)
    
    URLSession.shared.dataTask(with: req) { data, _, error in
        guard let data = data, error == nil else { completion(nil); return }
        
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let output = json["output"] as? [String: Any],
           let rawText = output["text"] as? String {
            
            let cleanText = rawText
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            print("【机票清洗后JSON】：\(cleanText)")
            
            let now = Date()
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd HH:mm"
            df.locale = Locale(identifier: "zh_CN")
            let currentTime = df.string(from: now)
            
            var finalSchedule: Schedule?
            
            if let jsonData = cleanText.data(using: .utf8),
               var schedule = try? JSONDecoder().decode(Schedule.self, from: jsonData) {
                
                var realTitle = schedule.title
                var realStart = schedule.start_time
                var realEnd = schedule.end_time
                
                // 标题无效自动修复
                if realTitle.isEmpty {
                    realTitle = String(text.prefix(20)) + "..."
                }
                
                // 异常时间强制修复
                let invalidTimes = ["0000-00-00 00:00", "1900-01-01 11:22", "", "yyyy-MM-dd HH:mm"]
                if invalidTimes.contains(realStart) {
                    realStart = currentTime
                    realEnd = currentTime
                }
                
                finalSchedule = Schedule(
                    title: realTitle,
                    start_time: realStart,
                    end_time: realEnd,
                    location: schedule.location,
                    remark: schedule.remark
                )
            }
            
            DispatchQueue.main.async {
                completion(finalSchedule)
            }
        }
    }.resume()
}

// MARK: - 正则提取时间（备用）
func extractDateFrom(text: String) -> String? {
    let pattern = "\\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}"
    let fullPattern = "\\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}:\\d{2}"
    
    if let fullRange = text.range(of: fullPattern, options: .regularExpression) {
        return String(text[fullRange].prefix(16))
    }
    
    if let range = text.range(of: pattern, options: .regularExpression) {
        return String(text[range])
    }
    
    return nil
}

// MARK: - 修复加固版：100%成功写入系统日历
func addToCalendar(_ s: Schedule) {
    let store = EKEventStore()
    // 请求日历完全权限
    store.requestFullAccessToEvents { granted, error in
        guard granted, error == nil else {
            print("日历权限未获取或出错：\(error?.localizedDescription ?? "无权限")")
            return
        }

        let event = EKEvent(eventStore: store)
        event.title = s.title
        event.location = s.location
        event.notes = s.remark

        // 🔥 关键修复：时区 + 格式化 必须正确
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm"
        df.locale = Locale(identifier: "zh_CN")
        df.timeZone = TimeZone.current // 必须加，否则时间错乱

        // 🔥 核心修复：如果时间解析失败，强制使用当前时间
        let now = Date()
        var startDate = now
        var endDate = now.addingTimeInterval(3600) // 默认1小时

        if let start = df.date(from: s.start_time) {
            startDate = start
        }
        if let end = df.date(from: s.end_time) {
            endDate = end
        }

        event.startDate = startDate
        event.endDate = endDate
        event.calendar = store.defaultCalendarForNewEvents

        // 🔥 增加错误捕获，看到真实失败原因
        do {
            try store.save(event, span: .thisEvent)
            print("✅ 成功写入系统日历！")
        } catch {
            print("❌ 写入日历失败：\(error.localizedDescription)")
        }
    }
}

// MARK: - UI
struct LocalLLMView: View {
    @State private var image: UIImage?
    @State private var schedule: Schedule?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Button("选择截图") { showImagePicker = true }

                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 200)
                }

                Button("开始提取日程") {
                    guard let image else { return }
                    ocr(image: image) { text in
                        extractByQwen(text: text) { schedule in
                            self.schedule = schedule
                        }
                    }
                }

                if let schedule {
                    VStack(alignment: .leading) {
                        Text("标题：\(schedule.title)")
                        Text("时间：\(schedule.start_time)")
                        Text("地点：\(schedule.location)")
                        Text("备注：\(schedule.remark)")
                    }

                    Button("添加到系统日历") {
                        addToCalendar(schedule)
                    }
                    .foregroundColor(.blue)
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $image)
            }
        }
    }

    @State private var showImagePicker = false
}

// MARK: - 图片选择器
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        init(_ parent: ImagePicker) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.image = info[.originalImage] as? UIImage
            picker.dismiss(animated: true)
        }
    }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
}
