//
//  FoodCalorieView.swift
//  SmartFitness
//
//  Created by Jeremy chen on 2026/4/7.
//

import SwiftUI
import CoreML
import Vision
import HealthKit
import UIKit

// MARK: - 健康管理（写入热量）
class HealthManager: ObservableObject {
    let healthStore = HKHealthStore()
    let calorieType = HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed)!
    
    func requestAuthorization() {
        healthStore.requestAuthorization(toShare: [calorieType], read: nil) { success, error in
            print("健康授权：\(success)")
        }
    }
    
    func saveCalories(calories: Double) {
        let quantity = HKQuantity(unit: .kilocalorie(), doubleValue: calories)
        let sample = HKQuantitySample(
            type: calorieType,
            quantity: quantity,
            start: Date(),
            end: Date()
        )
        
        healthStore.save(sample) { success, error in
            DispatchQueue.main.async {
                print("写入健康：\(success)")
            }
        }
    }
}

// MARK: - Food101 本地识别
class FoodRecognizer: ObservableObject {
    @Published var foodName: String = ""
    @Published var calories: Double = 0
    
    func recognize(image: UIImage) {
        guard let model = try? VNCoreMLModel(for: food().model) else { return }
        
        let request = VNCoreMLRequest(model: model) { [weak self] req, err in
            guard let results = req.results as? [VNClassificationObservation],
                  let top = results.first else { return }
            
            DispatchQueue.main.async {
                self?.foodName = top.identifier
                self?.fetchCalories(name: top.identifier)
            }
        }
        
        guard let ci = CIImage(image: image) else { return }
        try? VNImageRequestHandler(ciImage: ci).perform([request])
    }
    
    // OpenFoodFacts 免费查热量
    func fetchCalories(name: String) {
        let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name
        let url = URL(string: "https://world.openfoodfacts.org/cgi/search.pl?search_terms=\(encoded)&json=1")!
        
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let products = json["products"] as? [[String: Any]],
                  let first = products.first,
                  let nutri = first["nutriments"] as? [String: Any],
                  let kcal = nutri["energy-kcal"] as? Double else {
                return
            }
            
            DispatchQueue.main.async {
                self?.calories = kcal
            }
        }.resume()
    }
}

// MARK: - SwiftUI 主界面
struct FoodCalorieView: View {
    @StateObject private var foodRec = FoodRecognizer()
    @StateObject private var healthMgr = HealthManager()
    @State private var showCamera = false
    @State private var foodImage: UIImage?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if let img = foodImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 250)
                        .cornerRadius(12)
                } else {
                    Rectangle()
                        .fill(.gray.opacity(0.2))
                        .frame(height: 250)
                        .overlay(Text("拍摄食物"))
                }
                
                Text("识别：\(foodRec.foodName)")
                    .font(.title)
                
                Text("热量：\(foodRec.calories) kcal / 100g")
                    .font(.title2)
                    .foregroundColor(.orange)
                
                Button("拍摄食物") {
                    showCamera = true
                }
                .buttonStyle(.borderedProminent)
                
                Button("写入健康App") {
                    healthMgr.saveCalories(calories: foodRec.calories)
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
            .padding()
            .navigationTitle("食物热量识别")
            .onAppear {
                healthMgr.requestAuthorization()
            }
            .sheet(isPresented: $showCamera) {
                CameraPicker(image: $foodImage)
                    .onDisappear {
                        if let img = foodImage {
                            foodRec.recognize(image: img)
                        }
                    }
            }
        }
    }
}

// MARK: - 相机选择器
struct CameraPicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        
        init(_ parent: CameraPicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            parent.image = info[.originalImage] as? UIImage
            picker.dismiss(animated: true)
        }
    }
}

#Preview {
    FoodCalorieView()
}

