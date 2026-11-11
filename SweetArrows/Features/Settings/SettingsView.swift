import SwiftUI
import SweetArrowsCore
import UIKit

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
                if model.consent.privacyOptionsRequired {
                    Button("Privacy settings") {
                        Task { await model.consent.presentPrivacyOptions() }
                    }
                }
                Button("Restore purchases") {
                    Task { await model.purchases.restorePurchases() }
                }
            }
            Section("About") {
                Link("Privacy policy", destination: Links.privacy)
                Link("Terms of use", destination: Links.terms)
                Link("Contact", destination: Links.supportMail(version: Self.version))
            }
            Section {
                LabeledContent("Version", value: Self.version)
                #if DEBUG
                NavigationLink {
                    DebugMenuView()
                } label: {
                    Text(verbatim: "Debug menu")
                }
                #endif
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

/// Public pages on the game's website (docs/site, served by GitHub Pages).
@MainActor
enum Links {
    static let website = URL(string: "https://sweetarrowsgame.com")!
    static let privacy = URL(string: "https://sweetarrowsgame.com/privacy.html")!
    static let terms = URL(string: "https://sweetarrowsgame.com/terms.html")!
    static let supportAddress = "support@sweetarrowsgame.com"

    /// A mail with app version and device already filled in.
    static func supportMail(version: String) -> URL {
        let device = UIDevice.current.model + " · iOS " + UIDevice.current.systemVersion
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = supportAddress
        components.queryItems = [
            URLQueryItem(name: "subject", value: "Sweet Arrows \(version)"),
            URLQueryItem(name: "body", value: "\n\n—\nSweet Arrows \(version)\n\(device)"),
        ]
        return components.url ?? URL(string: "mailto:\(supportAddress)")!
    }
}
