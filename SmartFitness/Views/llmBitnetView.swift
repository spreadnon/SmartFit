//
//  llmBitnetView.swift
//  SmartFitness
//
//  Created by Jeremy chen on 2026/4/13.
//

//import SwiftUI
//import llama
//
//struct llmBitnetView: View {
//    @State private var output = "加载模型中..."
//    
//    init() {
//        runModel()
//    }
//    
//    func runModel() {
//        guard let url = Bundle.main.url(
//            forResource: "ggml-model-i2_s",
//            withExtension: "gguf"
//        ) else {
//            output = "模型不存在"
//            return
//        }
//        
//        Task {
//            let params = ModelParams(
//                path: url.path(),
//                contextLength: 2048,
//                threads: 6
//            )
//            let model = try! Model(params: params)
//            let sampler = try! Sampler(params: .init(temperature: 0.7))
//            let context = Context(model: model, sampler: sampler)
//            
//            let prompt = "Hello, explain BitNet briefly."
//            var text = ""
//            
//            let tokens = try! context.generate(prompt: prompt)
//            for await token in tokens {
//                text += token
//                DispatchQueue.main.async {
//                    self.output = text
//                }
//            }
//        }
//    }
//    
//    var body: some View {
//        ScrollView {
//            Text(output)
//                .font(.body)
//                .padding()
//        }
//    }
//}
