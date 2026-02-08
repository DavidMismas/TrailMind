import SwiftUI

struct PersonalProfileScreen: View {
    @ObservedObject var profileStore: UserProfileStore

    @State private var age = ""
    @State private var weight = ""
    @State private var height = ""
    @State private var condition: FitnessCondition = .moderate
    @State private var saveStatus = ""

    var body: some View {
        NavigationStack {
            ZStack {
                TrailTheme.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 14) {
                        headerCard
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

                        Button("Save Profile") {
                            guard let profile = builtProfile else { return }
                            profileStore.save(profile)
                            saveStatus = "Profile updated. New insights use these values."
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canSave ? TrailTheme.accent : Color.gray)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .disabled(!canSave)

                        if !saveStatus.isEmpty {
                            Text(saveStatus)
                                .font(.footnote)
                                .foregroundStyle(Color.white.opacity(0.78))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Personal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .onAppear(perform: loadFromStore)
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("AI Personalization")
                .font(.headline)
                .foregroundStyle(.white)
            Text("Your profile calibrates fatigue and Apple Intelligence coaching.")
                .font(.subheadline)
                .foregroundStyle(Color.white.opacity(0.74))
            if let profile = builtProfile {
                Text("Current fatigue multiplier: \(String(format: "%.2f", profile.fatigueMultiplier))")
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.66))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .trailCard()
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

    private var canSave: Bool {
        builtProfile != nil
    }

    private func loadFromStore() {
        guard let profile = profileStore.profile else { return }
        age = "\(profile.age)"
        weight = String(format: "%.1f", profile.weightKg)
        height = String(format: "%.1f", profile.heightCm)
        condition = profile.condition
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
