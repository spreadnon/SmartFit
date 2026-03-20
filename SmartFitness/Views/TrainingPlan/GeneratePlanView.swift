import SwiftUI

struct GeneratePlanView: View {
    @EnvironmentObject var appData: AppData
    @State private var selectedLevel: TrainingLevel = .novice
    @State private var selectedFrequency: TrainingFrequency = .three
    @State private var selectedScene: TrainingScene = .gym
    @State private var selectedInjuries: Set<Injury> = [.none]
    @State private var isGenerating = false
    
    @State private var isNavigationActive = false
    @State private var errorMessage: String? = nil

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            // 此时不需要 NavigationLink 了，因为 MainTabView 会根据 appData.currentPlan 自动切换视图
            // 但如果您想保留二级页面跳转感，也可以保留。这里为了逻辑一致性，我们让生成后直接更新全局状态。
            
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .padding()
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("基础参数区")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.textSecondary)
                        
                        HStack(spacing: 0) {
                            ForEach(TrainingLevel.allCases, id: \.self) { level in
                                Button(action: { selectedLevel = level }) {
                                    Text(level.rawValue)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(selectedLevel == level ? Theme.primary : Theme.surface)
                                        .foregroundColor(selectedLevel == level ? .white : Theme.textSecondary)
                                }
                            }
                        }
                        .cornerRadius(8)
                        
                        Text(selectedLevel.description)
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.secondary)
                            .padding(.top, 4)
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("训练频率")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.textSecondary)
                        
                        Picker("训练频率", selection: $selectedFrequency) {
                            ForEach(TrainingFrequency.allCases, id: \.self) { freq in
                                Text(freq.rawValue).tag(freq)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                        .background(Theme.surface)
                        .cornerRadius(8)
                        .accentColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("训练场景")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.textSecondary)
                        
                        HStack(spacing: 12) {
                            ForEach(TrainingScene.allCases, id: \.self) { scene in
                                Button(action: { selectedScene = scene }) {
                                    HStack {
                                        Circle()
                                            .stroke(selectedScene == scene ? Theme.primary : Color.gray, lineWidth: 2)
                                            .frame(width: 16, height: 16)
                                            .overlay(
                                                Circle()
                                                    .fill(selectedScene == scene ? Theme.primary : Color.clear)
                                                    .frame(width: 10, height: 10)
                                            )
                                        Text(scene.rawValue)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Theme.surface)
                                    .cornerRadius(8)
                                    .foregroundColor(Theme.textPrimary)
                                }
                            }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("伤病史区")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.textSecondary)
                        
                        let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(Injury.allCases, id: \.self) { injury in
                                Button(action: { toggleInjury(injury) }) {
                                    Text(injury.rawValue)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(selectedInjuries.contains(injury) ? Theme.primary.opacity(0.2) : Theme.surface)
                                        .foregroundColor(selectedInjuries.contains(injury) ? Theme.primary : Theme.textSecondary)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(selectedInjuries.contains(injury) ? Theme.primary : Color.clear, lineWidth: 1)
                                        )
                                }
                                .cornerRadius(6)
                            }
                        }
                        
                        if !selectedInjuries.isEmpty && !selectedInjuries.contains(.none) {
                            Text(selectedInjuries.map { $0.rawValue }.joined(separator: " + "))
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.secondary)
                                .padding(.top, 4)
                        }
                    }
                    
                    VStack(spacing: 16) {
                        Button(action: generatePlan) {
                            if isGenerating {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("生成计划")
                                    .fontWeight(.bold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Theme.primary)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .disabled(isGenerating)
                        
                        HStack {
                            Spacer()
                            NavigationLink(destination: Text("历史计划列表")) {
                                Text("历史计划")
                                    .font(Theme.Typography.body)
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                    }
                    .padding(.top, 16)
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
            }
            .navigationTitle("生成训练计划")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func toggleInjury(_ injury: Injury) {
        if injury == .none {
            selectedInjuries = [.none]
        } else {
            selectedInjuries.remove(.none)
            if selectedInjuries.contains(injury) {
                selectedInjuries.remove(injury)
                if selectedInjuries.isEmpty {
                    selectedInjuries.insert(.none)
                }
            } else {
                selectedInjuries.insert(injury)
            }
        }
    }
    
    private func generatePlan() {
        isGenerating = true
        errorMessage = nil

        NetworkManager.shared.generatePlan(level: selectedLevel, frequency: selectedFrequency, scene: selectedScene, injuries: selectedInjuries) { result in
            isGenerating = false
            switch result {
            case .success(let plan):
                withAnimation {
                    self.appData.currentPlan = plan
                }
            case .failure(let error):
                self.errorMessage = "Failed to generate plan: \(error.localizedDescription)"
            }
        }
    }
}

#Preview {
    NavigationView {
        GeneratePlanView()
    }
}
