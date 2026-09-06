import SwiftUI

private enum MoonPlaceMode: String, CaseIterable, Identifiable {
    case v1f = "V1F"
    case v2fx = "V2FX"

    var id: String { rawValue }
}

private struct MoonPlacePatchOption: Identifiable {
    let id: String
    let title: String
    let aliases: [String]
    let excludedAliases: [String]
    let mode: MoonPlaceMode

    func matches(_ item: PatchLibraryItem) -> Bool {
        let name = item.project?.name ?? item.packageURL.deletingPathExtension().lastPathComponent
        return aliases.contains { name.localizedCaseInsensitiveContains($0) }
            && !excludedAliases.contains { name.localizedCaseInsensitiveContains($0) }
    }
}

private enum MoonPlaceCatalog {
    static let options: [MoonPlacePatchOption] = [
        .init(id: "v1f-head-sn", title: "CABEZA SN", aliases: ["CABEZA ANTENA FFTH"], excludedAliases: [], mode: .v1f),
        .init(id: "v1f-neck-sn", title: "CUELLO SN", aliases: ["CUELLO ANTENA FFTH"], excludedAliases: [], mode: .v1f),
        .init(id: "v1f-drag-sn", title: "DRAG SN", aliases: ["DRAG ANTENA FFTH"], excludedAliases: [], mode: .v1f),
        .init(id: "v1f-chest-sn", title: "PECHO SN", aliases: ["PECHO ANTENA FFTH"], excludedAliases: [], mode: .v1f),
        .init(id: "v1f-head", title: "CABEZA V1", aliases: ["CABEZA FFTH"], excludedAliases: ["ANTENA"], mode: .v1f),
        .init(id: "v1f-neck", title: "CUELLO V1", aliases: ["CUELLO FFTH"], excludedAliases: ["ANTENA"], mode: .v1f),
        .init(id: "v1f-drag", title: "DRAG V1", aliases: ["DRAG FFTH"], excludedAliases: ["ANTENA"], mode: .v1f),
        .init(id: "v1f-chest", title: "PECHO V1", aliases: ["PECHO FFTH"], excludedAliases: ["ANTENA"], mode: .v1f),
        .init(id: "v2fx-head-sn", title: "CABEZA SN", aliases: ["AIMBOT MOON CABEZA"], excludedAliases: [], mode: .v2fx),
        .init(id: "v2fx-neck-sn", title: "CUELLO SN", aliases: ["AIMBOT MOON VIP CUELLO"], excludedAliases: [], mode: .v2fx),
        .init(id: "v2fx-drag-sn", title: "DRAG SN", aliases: ["AIMBOT MOON DRAG"], excludedAliases: [], mode: .v2fx),
        .init(id: "v2fx-chest-sn", title: "PECHO SN", aliases: ["AIMBOT MOON PECHO"], excludedAliases: [], mode: .v2fx),
        .init(id: "v2fx-head", title: "CABEZA V2", aliases: ["CABEZA ANTENA-FFMAX"], excludedAliases: [], mode: .v2fx),
        .init(id: "v2fx-neck", title: "CUELLO V2", aliases: ["CUELLO ANTENA-FFMAX"], excludedAliases: [], mode: .v2fx),
        .init(id: "v2fx-drag", title: "DRAG V2", aliases: ["DRAG ANTENA-FFMAX"], excludedAliases: [], mode: .v2fx),
        .init(id: "v2fx-chest", title: "PECHO V2", aliases: ["PECHO ANTENA FF MAX"], excludedAliases: [], mode: .v2fx)
    ]
}

private final class MoonPlaceAuthStore: ObservableObject {
    @Published var isAuthenticated = false
    @Published var username = ""
    @Published var phone = ""
    @Published var expiresAt: Date?
    @Published var errorMessage: String?

    private let credentialsKey = "moon.place.credentials"

    init() {
        if let saved = UserDefaults.standard.dictionary(forKey: credentialsKey),
           let savedUsername = saved["username"] as? String,
           let savedPhone = saved["phone"] as? String,
           let expires = saved["expiresAt"] as? Date {
            username = savedUsername
            phone = savedPhone
            expiresAt = expires
        }
    }

    func login(username: String, password: String, key: String) {
        guard !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !password.isEmpty,
              !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Enter your username, password and license key."
            return
        }
        guard let saved = UserDefaults.standard.dictionary(forKey: credentialsKey),
              saved["username"] as? String == username,
              saved["password"] as? String == password,
              saved["key"] as? String == key else {
            errorMessage = "The credentials could not be verified on this device."
            return
        }
        self.username = username
        self.phone = saved["phone"] as? String ?? ""
        self.expiresAt = saved["expiresAt"] as? Date
        isAuthenticated = true
        errorMessage = nil
    }

    func register(username: String, password: String, key: String, phone: String) {
        guard username.count >= 3, password.count >= 6, key.count >= 4 else {
            errorMessage = "Use a username, a password with 6+ characters and a valid key."
            return
        }
        let expiration = Calendar.current.date(byAdding: .day, value: 30, to: Date())!
        UserDefaults.standard.set([
            "username": username,
            "password": password,
            "key": key,
            "phone": phone,
            "expiresAt": expiration
        ], forKey: credentialsKey)
        login(username: username, password: password, key: key)
    }

    func logout() {
        isAuthenticated = false
    }
}

struct MoonPlaceView: View {
    @EnvironmentObject private var patchStore: PatchProjectStore
    @StateObject private var auth = MoonPlaceAuthStore()
    @State private var selectedMode: MoonPlaceMode?
    @State private var showRegister = false
    @State private var selectedOption: MoonPlacePatchOption?
    @State private var workingOptionID: String?
    @State private var message: String?
    @State private var showAdvanced = false

    var body: some View {
        ZStack {
            MoonPlaceBackground()
            if !auth.isAuthenticated {
                MoonPlaceLoginView(auth: auth, showRegister: $showRegister)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else if selectedMode == nil {
                MoonPlaceModeView(auth: auth, selectedMode: $selectedMode, showAdvanced: $showAdvanced)
                    .transition(.opacity)
            } else {
                MoonPlaceSelectorView(
                    auth: auth,
                    mode: selectedMode!,
                    options: MoonPlaceCatalog.options.filter { $0.mode == selectedMode! },
                    items: patchStore.items,
                    isBusy: patchStore.isBusy,
                    workingOptionID: workingOptionID,
                    onBack: { selectedMode = nil },
                    onLogout: { auth.logout(); selectedMode = nil },
                    onToggle: toggle
                )
                .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
        }
        .animation(.easeInOut(duration: 0.35), value: auth.isAuthenticated)
        .animation(.easeInOut(duration: 0.35), value: selectedMode)
        .sheet(item: $selectedOption) { option in
            MoonPlacePatchInfoView(option: option, item: matchingItem(for: option))
        }
        .sheet(isPresented: $showAdvanced) {
            PatchProjectsView()
        }
        .alert("Moon Place", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK") { message = nil }
        } message: {
            Text(message ?? "")
        }
    }

    private func matchingItem(for option: MoonPlacePatchOption) -> PatchLibraryItem? {
        patchStore.items.first(where: option.matches)
    }

    private func toggle(_ option: MoonPlacePatchOption) {
        guard let item = matchingItem(for: option), let project = item.project else {
            message = "Import the matching .3105 package in Advanced Patches before using this option."
            return
        }
        guard workingOptionID == nil else { return }
        workingOptionID = option.id
        Task.detached(priority: .userInitiated) {
            do {
                if let receipt = DevicePatchService.latestReceipt(projectID: project.id) {
                    try DevicePatchService.restore(receipt: receipt)
                } else {
                    let source = item.summary.schemaVersion >= 2 && item.canInspectContents
                        ? try PatchProjectLibrary.synchronizeWorkspace(item: item)
                        : project
                    _ = try DevicePatchService.apply(project: source)
                }
                await MainActor.run {
                    patchStore.reload()
                    workingOptionID = nil
                }
            } catch let error as PatchPackageError {
                await MainActor.run {
                    workingOptionID = nil
                    message = error.localizedDescription
                }
            } catch {
                await MainActor.run {
                    workingOptionID = nil
                    message = "The patch operation failed. Check device support and the target app."
                }
            }
        }
    }
}

private struct MoonPlaceBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.black, Color(red: 0.08, green: 0.03, blue: 0.17), Color(red: 0.18, green: 0.02, blue: 0.08)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            ForEach(0..<18, id: \.self) { index in
                Circle()
                    .fill(index.isMultiple(of: 3) ? Color.red.opacity(0.32) : Color.blue.opacity(0.28))
                    .frame(width: CGFloat(2 + index % 4), height: CGFloat(2 + index % 4))
                    .offset(x: CGFloat((index * 47) % 330) - 165, y: CGFloat((index * 71) % 690) - 345)
                    .blur(radius: index.isMultiple(of: 3) ? 1 : 0)
                    .animation(.easeInOut(duration: 2.2 + Double(index % 3)).repeatForever(autoreverses: true), value: index)
            }
        }
    }
}

private struct MoonPlaceLoginView: View {
    @ObservedObject var auth: MoonPlaceAuthStore
    @Binding var showRegister: Bool
    @State private var username = ""
    @State private var password = ""
    @State private var key = ""

    var body: some View {
        VStack(spacing: 22) {
            AppLogo(size: 88)
            Text("WELCOME BACK TO MOON PLACE")
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text("Secure access to your control patches")
                .foregroundStyle(.white.opacity(0.66))
            VStack(spacing: 12) {
                MoonPlaceField(title: "USERNAME", text: $username, icon: "person.fill")
                MoonPlaceSecureField(title: "PASSWORD", text: $password, icon: "lock.fill")
                MoonPlaceField(title: "LICENSE KEY", text: $key, icon: "key.fill")
            }
            Button("LOGIN") { auth.login(username: username, password: password, key: key) }
                .buttonStyle(MoonPlacePrimaryButton())
            Button("REGISTER NEW USER") { showRegister = true }
                .foregroundStyle(.white.opacity(0.8))
                .font(.subheadline.weight(.semibold))
            if let error = auth.errorMessage { Text(error).font(.caption).foregroundStyle(.red.opacity(0.9)).multilineTextAlignment(.center) }
        }
        .padding(28)
        .frame(maxWidth: 430)
        .sheet(isPresented: $showRegister) { MoonPlaceRegisterView(auth: auth) }
    }
}

private struct MoonPlaceRegisterView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var auth: MoonPlaceAuthStore
    @State private var username = ""
    @State private var password = ""
    @State private var key = ""
    @State private var phone = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("NEW MOON PLACE USER") {
                    TextField("Username", text: $username)
                    TextField("Phone", text: $phone)
                    SecureField("Password", text: $password)
                    TextField("License key", text: $key)
                }
                Section {
                    Button("CREATE ACCOUNT") {
                        auth.register(username: username, password: password, key: key, phone: phone)
                        if auth.isAuthenticated { dismiss() }
                    }
                }
                if let error = auth.errorMessage { Text(error).foregroundStyle(.red) }
            }
            .navigationTitle("Register")
            .toolbar { Button("Close") { dismiss() } }
        }
    }
}

private struct MoonPlaceModeView: View {
    @ObservedObject var auth: MoonPlaceAuthStore
    @Binding var selectedMode: MoonPlaceMode?
    @Binding var showAdvanced: Bool

    var body: some View {
        VStack(spacing: 26) {
            MoonPlaceHeader(title: "SELECT MODE OF CONTROL", subtitle: "Choose your active control profile")
            ForEach(MoonPlaceMode.allCases) { mode in
                Button { selectedMode = mode } label: {
                    HStack {
                        Image(systemName: mode == .v1f ? "scope" : "bolt.horizontal.fill")
                        Text(mode.rawValue)
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(22)
                    .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.blue.opacity(0.45)))
                }
            }
            MoonPlaceAccountBadge(auth: auth)
            Button("ADVANCED PATCHES") { showAdvanced = true }
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.65))
        }
        .padding(28)
        .frame(maxWidth: 500)
    }
}

private struct MoonPlaceSelectorView: View {
    @ObservedObject var auth: MoonPlaceAuthStore
    let mode: MoonPlaceMode
    let options: [MoonPlacePatchOption]
    let items: [PatchLibraryItem]
    let isBusy: Bool
    let workingOptionID: String?
    let onBack: () -> Void
    let onLogout: () -> Void
    let onToggle: (MoonPlacePatchOption) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                HStack {
                    Button(action: onBack) { Image(systemName: "chevron.left") }
                    Spacer()
                    AppLogo(size: 42)
                    Spacer()
                    Menu { Button("LOG OUT", action: onLogout) } label: { Image(systemName: "ellipsis.circle") }
                }
                .foregroundStyle(.white)
                Text("MOON PLACE SELECTOR")
                    .font(.system(size: 25, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text(mode.rawValue + " CONTROL PROFILE")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.red.opacity(0.9))
                MoonPlaceAccountBadge(auth: auth)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(options) { option in
                        let item = items.first(where: option.matches)
                        Button { onToggle(option) } label: {
                            VStack(spacing: 9) {
                                Image(systemName: workingOptionID == option.id ? "arrow.triangle.2.circlepath" : item == nil ? "shippingbox" : "scope")
                                    .font(.title2)
                                Text(option.title)
                                    .font(.subheadline.weight(.bold))
                                    .multilineTextAlignment(.center)
                                Text(item == nil ? "NOT LOADED" : DevicePatchService.latestReceipt(projectID: item!.id) == nil ? "APPLY PATCH" : "RESTORE ORIGINAL")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(item == nil ? .orange : .white.opacity(0.7))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 112)
                            .background(item == nil ? .white.opacity(0.06) : Color.blue.opacity(0.18), in: RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(item == nil ? .white.opacity(0.12) : .blue.opacity(0.65)))
                        }
                        .disabled(isBusy || workingOptionID != nil)
                    }
                }
            }
            .padding(22)
        }
    }
}

private struct MoonPlacePatchInfoView: View {
    let option: MoonPlacePatchOption
    let item: PatchLibraryItem?

    var body: some View {
        VStack(spacing: 18) {
            AppLogo(size: 64)
            Text(option.title).font(.title2.bold())
            Text(item?.packageURL.lastPathComponent ?? "Package not loaded")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Text("Use the tile to apply the packaged patch or restore its original files.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding(32)
        .presentationDetents([.medium])
    }
}

private struct MoonPlaceField: View {
    let title: String
    @Binding var text: String
    let icon: String

    var body: some View {
        HStack {
            Image(systemName: icon).foregroundStyle(.blue)
            TextField(title, text: $text).foregroundStyle(.white).textInputAutocapitalization(.never).autocorrectionDisabled()
        }
        .padding(14)
        .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct MoonPlaceSecureField: View {
    let title: String
    @Binding var text: String
    let icon: String

    var body: some View {
        HStack {
            Image(systemName: icon).foregroundStyle(.blue)
            SecureField(title, text: $text).foregroundStyle(.white).textInputAutocapitalization(.never)
        }
        .padding(14)
        .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct MoonPlaceHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 8) {
            AppLogo(size: 70)
            Text(title).font(.system(size: 24, weight: .black, design: .rounded)).foregroundStyle(.white).multilineTextAlignment(.center)
            Text(subtitle).foregroundStyle(.white.opacity(0.65))
        }
    }
}

private struct MoonPlaceAccountBadge: View {
    @ObservedObject var auth: MoonPlaceAuthStore

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "person.crop.circle.fill").font(.title2).foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 2) {
                Text(auth.username.isEmpty ? "GUEST" : auth.username).font(.subheadline.bold()).foregroundStyle(.white)
                Text("ACTIVE  •  " + expirationText).font(.caption2.weight(.bold)).foregroundStyle(.green)
            }
            Spacer()
            Text(auth.phone.isEmpty ? "MOON MEMBER" : auth.phone).font(.caption2).foregroundStyle(.white.opacity(0.6))
        }
        .padding(13)
        .background(.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 12))
    }

    private var expirationText: String {
        guard let expiresAt = auth.expiresAt else { return "NO EXPIRATION" }
        return expiresAt.formatted(date: .abbreviated, time: .omitted)
    }
}

private struct MoonPlacePrimaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.black))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(15)
            .background(LinearGradient(colors: [.blue, .red.opacity(0.85)], startPoint: .leading, endPoint: .trailing), in: RoundedRectangle(cornerRadius: 12))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}
