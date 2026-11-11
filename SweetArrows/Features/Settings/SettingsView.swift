import SwiftUI
import SweetArrowsCore

struct SettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Form {
            Section {
                toggle("Sound", isOn: \.sound)
                toggle("Music", isOn: \.music)
                toggle("Vibration", isOn: \.haptics)
            }
            Section {
                toggle("Color-blind mode", isOn: \.colorBlind)
            } footer: {
                Text("Every color already has its own shape. Color-blind mode adds a letter to each candy.")
            }
            Section {
                Button("Privacy settings") {
                    Task { await model.consent.presentPrivacyOptions() }
                }
                Button("Restore purchases") {
                    Task { await model.purchases.restorePurchases() }
                }
            }
            Section {
                LabeledContent("Version", value: Self.version)
            }
        }
        .font(Theme.body())
        .scrollContentBackground(.hidden)
        .background(Theme.cream.ignoresSafeArea())
        .navigationTitle(Text("Settings"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func toggle(_ title: LocalizedStringKey, isOn keyPath: WritableKeyPath<GameSettings, Bool>) -> some View {
        Toggle(title, isOn: Binding(
            get: { model.settings[keyPath: keyPath] },
            set: { newValue in model.updateSettings { $0[keyPath: keyPath] = newValue } }
        ))
        .tint(Theme.heart)
    }

    private static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }
}

#Preview {
    NavigationStack { SettingsView() }
        .environment(AppModel.preview())
}
