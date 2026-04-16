import SwiftUI
import AVFoundation
import Vision
import Foundation

// MARK: - 饮料数据模型
struct Drink: Codable, Identifiable {
    let id: Int
    let type: String
    let brand: String
    let name: String
    let category: String
    let sugarPer100ml: Double
    let totalSugar: Double
    let source: String
}

// MARK: - 加载本地JSON数据库
func loadDrinkDB() -> [Drink] {
    guard let url = Bundle.main.url(forResource: "drinks", withExtension: "json"),
          let data = try? Data(contentsOf: url),
          let drinks = try? JSONDecoder().decode([Drink].self, from: data) else {
        print("JSON 加载失败")
        return []
    }
    return drinks
}

let drinkList = loadDrinkDB()

// MARK: - 主页面（手动输入 + 相机扫描）
struct DrinkOCRView: View {
    @State private var searchText = ""
    @State private var matchedDrink: Drink?
    @State private var showCamera = false
    @State private var resultText = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                
                // 1. 手动输入搜索
                TextField("输入饮料名称（如：可口可乐）", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
                
                Button("手动搜索") {
                    search()
                }
                .buttonStyle(.borderedProminent)
                
                // 2. 相机扫描按钮
                Button("📷 相机扫描识别（真机）") {
                    checkCameraPermission()
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                
                // 识别结果
                if !resultText.isEmpty {
                    Text("识别内容：\(resultText)")
                        .foregroundColor(.gray)
                }
                
                // 匹配到的饮料信息
                if let drink = matchedDrink {
                    VStack(spacing: 8) {
                        Text("✅ 匹配成功")
                            .font(.headline)
                            .foregroundColor(.green)
                        
                        Text("\(drink.brand) \(drink.name)")
                            .font(.title2)
                        
                        Text("类型：\(drink.type) | \(drink.category)")
                        Text("含糖量：\(drink.sugarPer100ml) g/100ml")
                            .font(.title3)
                            .bold()
                            .foregroundColor(.red)
                        
                        Text("整杯总糖：\(drink.totalSugar) g")
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
                } else {
                    Text("未匹配到饮料")
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .navigationTitle("饮料含糖查询")
            .sheet(isPresented: $showCamera) {
                CameraScanView { text in
                    resultText = text
                    searchText = text
                    search()
                    showCamera = false
                }
            }
        }
    }
    
    // 搜索匹配
    private func search() {
        let key = searchText.lowercased()
        matchedDrink = drinkList.first {
            $0.brand.lowercased().contains(key) || $0.name.lowercased().contains(key)
        }
    }
    
    // 相机权限
    private func checkCameraPermission() {
        #if targetEnvironment(simulator)
        print("⚠️ 模拟器不支持相机，请使用真机")
        return
        #endif
        
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            showCamera = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    DispatchQueue.main.async {
                        showCamera = true
                    }
                }
            }
        default:
            print("请开启相机权限")
        }
    }
}

// MARK: - 相机扫描 + OCR 识别
struct CameraScanView: UIViewControllerRepresentable {
    let onResult: (String) -> Void
    
    func makeUIViewController(context: Context) -> CameraOCRViewController {
        let vc = CameraOCRViewController()
        vc.onTextDetected = onResult
        return vc
    }
    
    func updateUIViewController(_ uiViewController: CameraOCRViewController, context: Context) {}
}

class CameraOCRViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    var onTextDetected: ((String) -> Void)?
    private let captureSession = AVCaptureSession()
    private let textRequest = VNRecognizeTextRequest()
    private var hasDetected = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
        setupOCR()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        captureSession.stopRunning()
    }
    
    private func setupCamera() {
        captureSession.sessionPreset = .medium
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else { return }
        
        do {
            let input = try AVCaptureDeviceInput(device: device)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            }
            
            let output = AVCaptureVideoDataOutput()
            output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "ocrQueue"))
            if captureSession.canAddOutput(output) {
                captureSession.addOutput(output)
            }
            
            let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            previewLayer.frame = view.bounds
            previewLayer.videoGravity = .resizeAspectFill
            view.layer.addSublayer(previewLayer)
            
            captureSession.startRunning()
        } catch {
            print("相机启动失败：\(error)")
        }
    }
    
    private func setupOCR() {
        textRequest.recognitionLevel = .accurate
        textRequest.recognitionLanguages = ["zh-Hans", "en-US"]
        textRequest.usesLanguageCorrection = true
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard !hasDetected,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right, options: [:])
        do {
            try handler.perform([textRequest])
            guard let results = textRequest.results as? [VNRecognizedTextObservation] else { return }
            
            let text = results.compactMap { $0.topCandidates(1).first?.string }.joined(separator: " ")
            
            if text.count > 2 {
                hasDetected = true
                DispatchQueue.main.async {
                    self.onTextDetected?(text)
                }
            }
        } catch {
            print("OCR 失败：\(error)")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        DrinkOCRView()
    }
}
