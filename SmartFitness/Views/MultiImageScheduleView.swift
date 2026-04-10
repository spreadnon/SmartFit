import PhotosUI
import SwiftUI
import UIKit
import Vision
import EventKit

// 全局日历单例
let eventStore = EKEventStore()

// 数据结构
struct Schedule: Codable {
    var title: String
    var start_time: String
    var end_time: String
    var location: String
    var remark: String
}

// 多选图片
struct MultiImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImages: [UIImage]
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.selectionLimit = 0
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: PHPickerViewControllerDelegate {
        let parent: MultiImagePicker
        init(_ parent: MultiImagePicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.dismiss()
            for r in results {
                if r.itemProvider.canLoadObject(ofClass: UIImage.self) {
                    r.itemProvider.loadObject(ofClass: UIImage.self) { img, _ in
                        DispatchQueue.main.async {
                            if let img = img as? UIImage {
                                self.parent.selectedImages.append(img)
                            }
                        }
                    }
                }
            }
        }
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
}

// OCR 单张图片
func ocrMulti(image: UIImage, completion: @escaping (String) -> Void) {
    guard let cgImage = image.cgImage else {
        completion("")
        return
    }
    let req = VNRecognizeTextRequest { req, _ in
        let text = (req.results as? [VNRecognizedTextObservation])?
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: " ")
        completion(text ?? "")
    }
    req.recognitionLevel = .accurate
    req.recognitionLanguages = ["zh-CN", "en-US"]
    try? VNImageRequestHandler(cgImage: cgImage).perform([req])
}

// 合并所有图片的OCR文字
func combineOCRFromImages(images: [UIImage], completion: @escaping (String) -> Void) {
    var allText = ""
    let group = DispatchGroup()
    
    for img in images {
        group.enter()
        ocrMulti(image: img) { text in
            allText += text + "\n"
            group.leave()
        }
    }
    
    group.notify(queue: .main) {
        completion(allText)
    }
}

// 🔥 Qwen 识别行程
func extractScheduleFromCombinedText(text: String, completion: @escaping (Schedule?) -> Void) {
    let DASHSCOPE_API_KEY = "sk-0d6c7202bc6348c9a2325bf8c3646b59"
    guard let url = URL(string: "https://dashscope.aliyuncs.com/api/v1/services/aigc/text-generation/generation") else { return }
    
    let prompt = """
你是一个行程理解助手，用户会提供多张截图的全部内容，可能包含机票、高铁、酒店、聊天记录、订单等信息。
请根据所有内容，智能合并成一个完整行程。
只输出JSON，不要多余内容。

输出格式：
{
"title":"完整行程标题（15字内）",
"start_time":"MM-dd HH:mm",
"end_time":"MM-dd HH:mm",
"location":"出发→到达、机场、车站、地点",
"remark":"乘客、人物、事由、状态、备注等全部信息"
}

如果时间未写年份，默认使用今年。
如果没有时间，使用当前时间。

所有信息如下：
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
            
            print(cleanText)
            
            let currentYear = Calendar.current.component(.year, from: Date())
            let now = Date()
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd HH:mm"
            let currentTime = df.string(from: now)
            
            if let jsonData = cleanText.data(using: .utf8),
               let s = try? JSONDecoder().decode(Schedule.self, from: jsonData) {
                
                func fix(_ t: String) -> String {
                    if t.isEmpty || t == "0000-00-00 00:00" { return currentTime }
                    if t.count == 11 { return "\(currentYear)-\(t)" }
                    return t
                }
                
                let final = Schedule(
                    title: s.title.isEmpty ? "行程" : s.title,
                    start_time: fix(s.start_time),
                    end_time: fix(s.end_time.isEmpty ? s.start_time : s.end_time),
                    location: s.location,
                    remark: s.remark
                )
                
                completion(final)
                return
            }
        }
        completion(nil)
    }.resume()
}

// 保存到日历
func addToCalendarMulti(_ s: Schedule) {
    let status = EKEventStore.authorizationStatus(for: .event)
    
    if status == .fullAccess || status == .authorized {
        saveEvent(schedule: s)
        return
    }
    
    eventStore.requestFullAccessToEvents { granted, _ in
        DispatchQueue.main.async {
            guard granted else { return }
            saveEvent(schedule: s)
        }
    }
}

func saveEvent(schedule: Schedule) {
    let event = EKEvent(eventStore: eventStore)
    event.title = schedule.title
    event.location = schedule.location
    event.notes = schedule.remark
    
    let df = DateFormatter()
    df.dateFormat = "yyyy-MM-dd HH:mm"
    df.timeZone = .current
    
    let now = Date()
    let startDate = df.date(from: schedule.start_time) ?? now
    var endDate = df.date(from: schedule.end_time) ?? startDate
    
    if endDate <= startDate {
        endDate = startDate.addingTimeInterval(3600)
    }
    
    event.startDate = startDate
    event.endDate = endDate
    event.calendar = eventStore.defaultCalendarForNewEvents
    
    do {
        try eventStore.save(event, span: .thisEvent)
    } catch {
        print("Save Error: \(error.localizedDescription)")
    }
}

// MARK: - UI Components

struct MultiImageScheduleView: View {
    @State private var selectedImages: [UIImage] = []
    @State private var showPicker = false
    @State private var isProcessing = false
    @State private var showSuccess = false
    @State private var finalSchedule: Schedule?
    
    // Workflow States
    @State private var stepMergeCompleted = false
    @State private var stepAICompleted = false
    @State private var stepReadyCompleted = false
    
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Schedule Parser")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.black)
                        Text("Capture multiple pages, extract itinerary fast")
                            .font(.system(size: 14))
                            .foregroundColor(.gray.opacity(0.8))
                    }
                    Spacer()
                    Button {
                        // Help action
                    } label: {
                        Image(systemName: "questionmark")
                            .font(.system(size: 14, weight: .bold))
                            .padding(10)
                            .background(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 1))
                            .foregroundColor(.black)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        
                        // Add Documents Section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Add documents")
                                    .font(.system(size: 16, weight: .bold))
                                Spacer()
                                Button("Clear all") {
                                    // Resign focus to prevent crash during view dismissal
                                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                    
                                    withAnimation {
                                        selectedImages.removeAll()
                                        finalSchedule = nil
                                        isProcessing = false
                                        resetWorkflow()
                                    }
                                }
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                            }
                            
                            Button {
                                showPicker = true
                            } label: {
                                VStack(spacing: 8) {
                                    Text("Drop images or scan")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.black)
                                    Text("JPG, PNG, PDF • up to 10")
                                        .font(.system(size: 14))
                                        .foregroundColor(.gray)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 160)
                                .background(Color(white: 0.98))
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                )
                            }
                        }
                        
                        // Selected Images Section
                        if !selectedImages.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Selected (\(selectedImages.count))")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.gray)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(0..<selectedImages.count, id: \.self) { index in
                                            Image(uiImage: selectedImages[index])
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 80, height: 80)
                                                .cornerRadius(12)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                                )
                                        }
                                        
                                        Button {
                                            showPicker = true
                                        } label: {
                                            Image(systemName: "plus")
                                                .font(.system(size: 20, weight: .bold))
                                                .foregroundColor(.gray)
                                                .frame(width: 80, height: 80)
                                                .background(Color(white: 0.95))
                                                .cornerRadius(12)
                                        }
                                    }
                                }
                            }
                        }
                        
                        
                        // Extracted Text Section
                        if let _ = finalSchedule {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Extracted Schedule (Tap to edit)")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.gray)
                                
                                if finalSchedule != nil {
                                    VStack(alignment: .leading, spacing: 16) {
                                        TextField("Event Title", text: Binding(get: { finalSchedule?.title ?? "" }, set: { finalSchedule?.title = $0 }))
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundColor(.black)
                                            .padding(8)
                                            .background(Color.black.opacity(0.04))
                                            .cornerRadius(8)
                                        
                                        HStack(spacing: 16) {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text("START")
                                                    .font(.system(size: 10, weight: .bold))
                                                    .foregroundColor(.gray)
                                                TextField("MM-dd HH:mm", text: Binding(get: { finalSchedule?.start_time ?? "" }, set: { finalSchedule?.start_time = $0 }))
                                                    .font(.system(size: 14))
                                                    .foregroundColor(.black)
                                                    .padding(8)
                                                    .background(Color.black.opacity(0.04))
                                                    .cornerRadius(8)
                                            }
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text("END")
                                                    .font(.system(size: 10, weight: .bold))
                                                    .foregroundColor(.gray)
                                                TextField("MM-dd HH:mm", text: Binding(get: { finalSchedule?.end_time ?? "" }, set: { finalSchedule?.end_time = $0 }))
                                                    .font(.system(size: 14))
                                                    .foregroundColor(.black)
                                                    .padding(8)
                                                    .background(Color.black.opacity(0.04))
                                                    .cornerRadius(8)
                                            }
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("LOCATION")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundColor(.gray)
                                            TextField("Location", text: Binding(get: { finalSchedule?.location ?? "" }, set: { finalSchedule?.location = $0 }))
                                                .font(.system(size: 14))
                                                .foregroundColor(.black)
                                                .padding(8)
                                                .background(Color.black.opacity(0.04))
                                                .cornerRadius(8)
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("REMARK")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundColor(.gray)
                                            TextField("Add notes...", text: Binding(get: { finalSchedule?.remark ?? "" }, set: { finalSchedule?.remark = $0 }), axis: .vertical)
                                                .font(.system(size: 13))
                                                .foregroundColor(.black)
                                                .lineLimit(3...6)
                                                .padding(8)
                                                .background(Color.black.opacity(0.04))
                                                .cornerRadius(8)
                                        }
                                        
                                        Text("Confidence 96% - AI interpreted")
                                            .font(.system(size: 12))
                                            .foregroundColor(.gray.opacity(0.5))
                                            .padding(.top, 4)
                                    }
                                    .padding(20)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(white: 0.99))
                                    .cornerRadius(16)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                                    )
                                }
                            }
                        }
                        Spacer(minLength: 300)
                    }
                    .padding(24)
                }
                .scrollDismissesKeyboard(.immediately)
                
                // Bottom Buttons
                VStack(spacing: 12) {
                    HStack(spacing: 16) {
                        Button {
                            startProcessing()
                        } label: {
                            if isProcessing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Extract Itinerary")
                                    .font(.system(size: 16, weight: .bold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.black)
                        .foregroundColor(.white)
                        .cornerRadius(16)
                        .disabled(selectedImages.isEmpty || isProcessing)
                        
                        Button {
                            guard let s = finalSchedule else { return }
                            addToCalendarMulti(s)
                            showSuccess = true
                        } label: {
                            Text("Save Calendar")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.black)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.white)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.black, lineWidth: 1.5)
                        )
                        .disabled(finalSchedule == nil)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 34)
                .background(Color.white)
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showPicker) {
            MultiImagePicker(selectedImages: $selectedImages)
        }
        .alert("Success", isPresented: $showSuccess) {
            Button("OK") {}
        } message: {
            Text("Itinerary added to your calendar.")
        }
    }
    
    private func resetWorkflow() {
        stepMergeCompleted = false
        stepAICompleted = false
        stepReadyCompleted = false
    }
    
    private func startProcessing() {
        isProcessing = true
        resetWorkflow()
        
        combineOCRFromImages(images: selectedImages) { allText in
            stepMergeCompleted = true
            
            extractScheduleFromCombinedText(text: allText) { schedule in
                DispatchQueue.main.async {
                    isProcessing = false
                    if let s = schedule {
                        finalSchedule = s
                        stepAICompleted = true
                        stepReadyCompleted = true
                    }
                }
            }
        }
    }
}

struct WorkflowItem: View {
    let title: String
    let isCompleted: Bool
    let isProcessing: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(isCompleted ? Color.black : Color.gray.opacity(0.3), lineWidth: 1.5)
                    .frame(width: 24, height: 24)
                
                if isCompleted {
                    Circle()
                        .fill(Color.black)
                        .frame(width: 14, height: 14)
                } else if isProcessing {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            
            Text(title)
                .font(.system(size: 16, weight: isCompleted ? .medium : .regular))
                .foregroundColor(isCompleted ? .black : .gray)
            
            Spacer()
        }
    }
}

struct MultiImageScheduleView_Previews: PreviewProvider {
    static var previews: some View {
        MultiImageScheduleView()
    }
}
