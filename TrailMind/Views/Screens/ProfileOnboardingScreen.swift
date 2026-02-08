import SwiftUI

struct ProfileOnboardingScreen: View {
    let onSave: (UserProfile) -> Void

    @State private var age = ""
    @State private var weight = ""
    @State private var height = ""
    @State private var condition: FitnessCondition = .moderate

    var body: some View {
        NavigationStack {
            ZStack {
                TrailTheme.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Personal Setup")
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                            Text("Used to personalize fatigue and AI insights.")
                                .font(.subheadline)
                                .foregroundStyle(Color.white.opacity(0.74))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .trailCard()

                        inputField("Age", text: $age, keyboard: .numberPad)
                        inputField("Weight (kg)", text: $weight, keyboard: .decimalPad)
                        inputField("Height (cm)", text: $height, keyboard: .decimalPad)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Condition")
                                .font(.headline)
                                .foregroundStyle(.white)

                            Picker("Condition", selection: $condition) {
                                ForEach(FitnessCondition.allCases) { option in
                                    Text(option.rawValue).tag(option)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        .trailCard()

                        Button("Continue") {
                            guard let profile = builtProfile else { return }
                            onSave(profile)
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canContinue ? TrailTheme.accent : Color.gray)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .disabled(!canContinue)
                    }
                    .padding()
                }
            }
            .navigationTitle("Welcome")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private var canContinue: Bool {
        builtProfile != nil
    }

    private var builtProfile: UserProfile? {
        guard let ageValue = Int(age), (10...100).contains(ageValue),
              let weightValue = Double(weight), (25...220).contains(weightValue),
              let heightValue = Double(height), (100...240).contains(heightValue)
        else {
            return nil
        }

        return UserProfile(
            age: ageValue,
            weightKg: weightValue,
            heightCm: heightValue,
            condition: condition
        )
    }

    private func inputField(_ title: String, text: Binding<String>, keyboard: UIKeyboardType) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)

            TextField(title, text: text)
                .keyboardType(keyboard)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(12)
                .background(Color.white.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .foregroundStyle(.white)
        }
        .trailCard()
    }
}
