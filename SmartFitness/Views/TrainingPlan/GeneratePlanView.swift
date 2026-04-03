import SwiftUI

struct GeneratePlanView: View {
    @EnvironmentObject var appData: AppData
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedLevel: TrainingLevel = .novice
    @State private var selectedFrequency: TrainingFrequency = .three
    @State private var selectedScene: TrainingScene = .gym
    @State private var selectedInjuries: Set<Injury> = [.none]
    @State private var isGenerating = false
    @State private var errorMessage: String? = nil

    var body: some View {
        ZStack {
            StitchTheme.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("GENERATE")
                        .font(StitchTypography.headline)
                        .italic()
                        .foregroundColor(StitchTheme.onSurfaceVariant)
                    + Text(" PROTOCOL")
                        .font(StitchTypography.headline)
                        .italic()
                        .foregroundColor(StitchTheme.primaryContainer)
                    
                    Spacer()
                    
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(StitchTheme.onSurfaceVariant)
                            .padding(8)
                            .background(StitchTheme.surfaceContainerHigh)
                            .clipShape(Circle())
                    }
                }
                .padding(24)
                .background(StitchTheme.surfaceContainerLow)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 40) {
                        
                        // Error Message
                        if let errorMessage = errorMessage {
                            Text(errorMessage)
                                .font(StitchTypography.labelSmall)
                                .foregroundColor(StitchTheme.secondary)
                                .padding()
                                .background(StitchTheme.secondary.opacity(0.1))
                                .cornerRadius(8)
                        }
                        
                        // 1. Level Selection
                        protocolSection(title: "TRAINING LEVEL", subtitle: "SPECIFY EXPERIENCE") {
                            HStack(spacing: 8) {
                                ForEach(TrainingLevel.allCases, id: \.self) { level in
                                    selectorButton(
                                        title: level.localizedName.uppercased(),
                                        isSelected: selectedLevel == level
                                    ) {
                                        selectedLevel = level
                                    }
                                }
                            }
                        }
                        
                        // 2. Frequency Selection
                        protocolSection(title: "FREQUENCY", subtitle: "SESSIONS PER WEEK") {
                            HStack(spacing: 8) {
                                ForEach(TrainingFrequency.allCases, id: \.self) { freq in
                                    selectorButton(
                                        title: freq.localizedName.uppercased(),
                                        isSelected: selectedFrequency == freq
                                    ) {
                                        selectedFrequency = freq
                                    }
                                }
                            }
                        }
                        
                        // 3. Scene Selection
                        protocolSection(title: "ENVIRONMENT", subtitle: "LOCATION TYPE") {
                            HStack(spacing: 8) {
                                ForEach(TrainingScene.allCases, id: \.self) { scene in
                                    selectorButton(
                                        title: scene.localizedName.uppercased(),
                                        isSelected: selectedScene == scene
                                    ) {
                                        selectedScene = scene
                                    }
                                }
                            }
                        }
                        
                        // 4. Injuries
                        protocolSection(title: "LIMITATIONS", subtitle: "INJURY HISTORY") {
                            let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(Injury.allCases, id: \.self) { injury in
                                    selectorButton(
                                        title: injury.localizedName.uppercased(),
                                        isSelected: selectedInjuries.contains(injury),
                                        isSmall: true
                                    ) {
                                        toggleInjury(injury)
                                    }
                                }
                            }
                        }
                        
                        // Generate Button
                        VStack(spacing: 16) {
                            Button(action: generatePlan) {
                                HStack {
                                    if isGenerating {
                                        ProgressView()
                                            .tint(StitchTheme.onPrimaryFixed)
                                            .padding(.trailing, 8)
                                    }
                                    Text(isGenerating ? NSLocalizedString("OPTIMIZING...", comment: "") : NSLocalizedString("GENERATE PROTOCOL", comment: ""))
                                        .font(StitchTypography.label)
                                        .tracking(2)
                                }
                                .foregroundColor(StitchTheme.onPrimaryFixed)
                                .frame(maxWidth: .infinity)
                                .frame(height: 64)
                                .background(StitchTheme.primaryContainer)
                                .cornerRadius(12)
                                .shadow(color: StitchTheme.primaryContainer.opacity(0.3), radius: 20, y: 10)
                            }
                            .disabled(isGenerating)
                            
                            Text("AI-DRIVEN PARAMETRIC PROGRAMMING")
                                .font(StitchTypography.labelSmall)
                                .foregroundColor(StitchTheme.onSurfaceVariant)
                                .opacity(0.5)
                        }
                        .padding(.top, 20)
                        
                        Spacer(minLength: 40)
                    }
                    .padding(24)
                }
            }
        }
    }
    
    // MARK: - Components
    
    private func protocolSection<Content: View>(title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(StitchTypography.label)
                    .tracking(3)
                    .foregroundColor(StitchTheme.primaryContainer)
                Text(subtitle)
                    .font(StitchTypography.labelSmall)
                    .foregroundColor(StitchTheme.onSurfaceVariant)
            }
            content()
        }
    }
    
    private func selectorButton(title: String, isSelected: Bool, isSmall: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(isSmall ? StitchTypography.labelSmall : StitchTypography.label)
                .tracking(1)
                .foregroundColor(isSelected ? StitchTheme.onPrimaryFixed : StitchTheme.onSurfaceVariant)
                .frame(maxWidth: .infinity)
                .frame(height: isSmall ? 40 : 50)
                .background(isSelected ? StitchTheme.primaryContainer : StitchTheme.surfaceContainerHigh)
                .cornerRadius(6)
        }
        .animation(.spring(response: 0.3), value: isSelected)
    }
    
    private func toggleInjury(_ injury: Injury) {
        withAnimation {
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
    }
    
    private func generatePlan() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        isGenerating = true
        errorMessage = nil

        NetworkManager.shared.generatePlan(
            level: selectedLevel,
            frequency: selectedFrequency,
            scene: selectedScene,
            injuries: selectedInjuries,
            token: appData.currentUser?.token
        ) { result in
            isGenerating = false
            switch result {
            case .success(let plan):
                withAnimation {
                    self.appData.aiSmartPlan = plan
                    dismiss()
                }
            case .failure(let error):
                self.errorMessage = NSLocalizedString("SYSTEM ERROR: ", comment: "") + error.localizedDescription.uppercased()
            }
        }
    }
}

#Preview {
    GeneratePlanView()
        .environmentObject(AppData())
}
