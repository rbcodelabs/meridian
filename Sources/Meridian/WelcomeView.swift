import SwiftUI
import AppKit

struct WelcomeView: View {
    let onStart: (URL, SetupOptions) -> Void

    @State private var vaultPath = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent("Documents/TeamVault")
        .path

    @State private var options = SetupOptions()
    @State private var showingPluginSheet = false
    @State private var hasHomebrew: Bool = false
    @State private var hasClaudeLogin: Bool = false
    @State private var hasGitHubAuth: Bool = false
    @State private var hasGWS: Bool = false

    // GWS credential fields (combined into options.gwsCredentials on submit)
    @State private var gwsSource: GWSSource = .keeper
    @State private var keeperEmail: String = ""
    @State private var keeperUID: String = ""
    @State private var opClientIDRef: String = ""
    @State private var opSecretRef: String = ""
    @State private var directClientID: String = ""
    @State private var directClientSecret: String = ""

    enum GWSSource: String, CaseIterable, Identifiable {
        case keeper      = "Keeper"
        case onePassword = "1Password"
        case direct      = "Enter directly"
        var id: String { rawValue }
    }

    private var canSetUp: Bool {
        let anySelected = options.installObsidian || options.installHomebrew ||
                          options.installClaudeCode || options.installGitHub || options.installGWS
        guard anySelected else { return false }
        if options.installGWS && !hasGWS {
            switch gwsSource {
            case .keeper:      return !keeperEmail.isEmpty && !keeperUID.isEmpty
            case .onePassword: return !opClientIDRef.isEmpty && !opSecretRef.isEmpty
            case .direct:      return !directClientID.isEmpty && !directClientSecret.isEmpty
            }
        }
        return true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Header
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 28))
                        .foregroundStyle(.purple)
                    Text("Meridian")
                        .font(.system(size: 26, weight: .bold))
                }
                Text("Your agentic knowledge working environment.")
                    .foregroundStyle(.secondary)
                    .padding(.leading, 38)
            }

            Divider().padding(.vertical, 20)

            // Components — scrollable so expanded credential fields don't overflow
            ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Components")
                    .font(.headline)

                // Obsidian vault row
                HStack(alignment: .top, spacing: 10) {
                    Toggle("", isOn: $options.installObsidian)
                        .labelsHidden()
                        .padding(.top, 2)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Obsidian vault")
                            .fontWeight(.medium)
                        Text("Shared team workspace with Claude Threads, Linear sync, and 15+ plugins")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if options.installObsidian {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    TextField("Vault path", text: $vaultPath)
                                        .textFieldStyle(.roundedBorder)
                                    Button("Browse…") { browse() }
                                }
                                Text("A new folder will be created at this path.")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)

                                TextField("Starter vault GitHub URL (optional)", text: $options.vaultGitHubURL)
                                    .textFieldStyle(.roundedBorder)
                                Text("e.g. https://github.com/org/repo — leave blank for an empty vault")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)

                                HStack {
                                    let selected = options.obsidianPlugins.filter(\.isSelected).count
                                    let total = options.obsidianPlugins.count
                                    Text("\(selected) of \(total) plugins selected")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Button("Customize…") { showingPluginSheet = true }
                                        .font(.caption)
                                }
                            }
                            .padding(.top, 6)
                            .padding(.leading, 2)
                        }
                    }
                }
                .animation(.easeInOut, value: options.installObsidian)

                // Homebrew row
                HStack(alignment: .top, spacing: 10) {
                    Toggle("", isOn: $options.installHomebrew)
                        .labelsHidden()
                        .disabled(hasHomebrew)
                        .padding(.top, 2)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text("Homebrew")
                                .fontWeight(.medium)
                            if hasHomebrew {
                                Label("Already installed", systemImage: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            }
                        }
                        Text("macOS package manager — needed by Claude Code, GitHub CLI, and GWS")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Claude Code row
                HStack(alignment: .top, spacing: 10) {
                    Toggle("", isOn: $options.installClaudeCode)
                        .labelsHidden()
                        .disabled(hasClaudeLogin)
                        .padding(.top, 2)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text("Claude Code")
                                .fontWeight(.medium)
                            if hasClaudeLogin {
                                Label("Already signed in", systemImage: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            }
                        }
                        Text("AI coding assistant — installs via Homebrew + npm")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // GitHub CLI row
                HStack(alignment: .top, spacing: 10) {
                    Toggle("", isOn: $options.installGitHub)
                        .labelsHidden()
                        .disabled(hasGitHubAuth)
                        .padding(.top, 2)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text("GitHub CLI (gh)")
                                .fontWeight(.medium)
                            if hasGitHubAuth {
                                Label("Already signed in", systemImage: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            }
                        }
                        Text("Lets Claude open PRs, read issues, and interact with GitHub repos")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Google Workspace CLI row
                HStack(alignment: .top, spacing: 10) {
                    Toggle("", isOn: $options.installGWS)
                        .labelsHidden()
                        .disabled(hasGWS)
                        .padding(.top, 2)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text("Google Workspace CLI (gws)")
                                .fontWeight(.medium)
                            if hasGWS {
                                Label("Already set up", systemImage: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            }
                        }
                        Text("Lets Claude access Drive, Gmail, Calendar, and Docs")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if options.installGWS && !hasGWS {
                            VStack(alignment: .leading, spacing: 8) {
                                Picker("Credentials", selection: $gwsSource) {
                                    ForEach(GWSSource.allCases) { source in
                                        Text(source.rawValue).tag(source)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .padding(.top, 4)

                                switch gwsSource {
                                case .keeper:
                                    TextField("Your email (e.g. you@company.com)", text: $keeperEmail)
                                        .textFieldStyle(.roundedBorder)
                                    TextField("Keeper record UID", text: $keeperUID)
                                        .textFieldStyle(.roundedBorder)
                                    Text("The Keeper record must contain a Login field (client ID) and Password field (client secret).")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)

                                case .onePassword:
                                    TextField("Client ID ref  (op://vault/item/field)", text: $opClientIDRef)
                                        .textFieldStyle(.roundedBorder)
                                    TextField("Client Secret ref  (op://vault/item/field)", text: $opSecretRef)
                                        .textFieldStyle(.roundedBorder)
                                    Text("The 1Password app must be running and unlocked.")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)

                                case .direct:
                                    TextField("Google OAuth Client ID", text: $directClientID)
                                        .textFieldStyle(.roundedBorder)
                                    SecureField("Google OAuth Client Secret", text: $directClientSecret)
                                        .textFieldStyle(.roundedBorder)
                                    Text("Create an OAuth 2.0 Desktop app credential in Google Cloud Console.")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .padding(.top, 4)
                            .padding(.leading, 2)
                        }
                    }
                }
                .animation(.easeInOut, value: options.installGWS)
            }
            } // ScrollView

            Divider().padding(.top, 16)

            HStack {
                Spacer()
                Button("Set Up Now") {
                    var finalOptions = options
                    switch gwsSource {
                    case .keeper:
                        finalOptions.gwsCredentials = .keeper(email: keeperEmail, recordUID: keeperUID)
                    case .onePassword:
                        finalOptions.gwsCredentials = .onePassword(clientIDRef: opClientIDRef, clientSecretRef: opSecretRef)
                    case .direct:
                        finalOptions.gwsCredentials = .direct(clientID: directClientID, clientSecret: directClientSecret)
                    }
                    onStart(URL(fileURLWithPath: vaultPath), finalOptions)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!canSetUp)
            }
        }
        .sheet(isPresented: $showingPluginSheet) {
            PluginPickerSheet(plugins: $options.obsidianPlugins)
        }
        .onAppear {
            hasHomebrew = FileManager.default.fileExists(atPath: "/opt/homebrew/bin/brew")
                || FileManager.default.fileExists(atPath: "/usr/local/bin/brew")
            if hasHomebrew { options.installHomebrew = false }
            hasClaudeLogin = detectClaudeLogin()
            if hasClaudeLogin { options.installClaudeCode = false }
            hasGitHubAuth = detectGitHubAuth()
            if hasGitHubAuth { options.installGitHub = false }
            hasGWS = detectGWSAuth()
            if hasGWS { options.installGWS = false }
        }
    }

    // MARK: - Helpers

    private func browse() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "Choose"
        panel.message = "Select a parent folder for your vault"
        if panel.runModal() == .OK, let url = panel.url {
            vaultPath = url.appendingPathComponent("TeamVault").path
        }
    }

    /// Returns true only if gws is installed AND the credential + token files
    /// are both present. Binary-only means auth was never completed — keep the
    /// toggle on so the auth step runs.
    private func detectGWSAuth() -> Bool {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        let binaryExists = fm.fileExists(atPath: "/opt/homebrew/bin/gws")
            || fm.fileExists(atPath: "/usr/local/bin/gws")
        let tokenExists = fm.fileExists(atPath: home.appendingPathComponent(".config/gws/token_cache.json").path)
        let credsExist  = fm.fileExists(atPath: home.appendingPathComponent(".config/gws/client_secret.json").path)
        return binaryExists && tokenExists && credsExist
    }

    /// Returns true if `gh auth login` has already been completed, detected by
    /// the presence of ~/.config/gh/hosts.yml (written on first successful auth).
    private func detectGitHubAuth() -> Bool {
        let hostsFile = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/gh/hosts.yml")
        return FileManager.default.fileExists(atPath: hostsFile.path)
    }

    /// Returns true if Claude Desktop / Claude Code has an active account login,
    /// detected by the presence of oauth:tokenCache in Claude's config.json.
    private func detectClaudeLogin() -> Bool {
        let configURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Claude/config.json")
        guard let data = try? Data(contentsOf: configURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = json["oauth:tokenCache"] as? String,
              !token.isEmpty else { return false }
        return true
    }
}

// MARK: - Plugin Picker Sheet

struct PluginPickerSheet: View {
    @Binding var plugins: [ObsidianPlugin]
    @Environment(\.dismiss) private var dismiss

    private var bundledIndices: [Int] { plugins.indices.filter { plugins[$0].isBundled } }
    private var communityIndices: [Int] { plugins.indices.filter { !plugins[$0].isBundled } }
    private var selectedCount: Int { plugins.filter(\.isSelected).count }

    var body: some View {
        VStack(spacing: 0) {

            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Plugins")
                        .font(.title2.bold())
                    Text("\(selectedCount) of \(plugins.count) selected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: 8) {
                    Button("Select All") {
                        for i in plugins.indices { plugins[i].isSelected = true }
                    }
                    .buttonStyle(.bordered)
                    Button("Deselect All") {
                        for i in plugins.indices { plugins[i].isSelected = false }
                    }
                    .buttonStyle(.bordered)
                    Button("Done") { dismiss() }
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding()

            Divider()

            List {
                Section {
                    ForEach(bundledIndices, id: \.self) { i in
                        PluginRow(plugin: plugins[i], isSelected: $plugins[i].isSelected)
                    }
                } header: {
                    Label("rbcodelabs", systemImage: "shippingbox.fill")
                        .foregroundStyle(.purple)
                        .font(.caption.bold())
                        .textCase(nil)
                }

                Section {
                    ForEach(communityIndices, id: \.self) { i in
                        PluginRow(plugin: plugins[i], isSelected: $plugins[i].isSelected)
                    }
                } header: {
                    Label("Community", systemImage: "person.3.fill")
                        .foregroundStyle(.secondary)
                        .font(.caption.bold())
                        .textCase(nil)
                }
            }
            .listStyle(.inset)
        }
        .frame(width: 480, height: 520)
    }
}

struct PluginRow: View {
    let plugin: ObsidianPlugin
    @Binding var isSelected: Bool

    var body: some View {
        Toggle(isOn: $isSelected) {
            VStack(alignment: .leading, spacing: 2) {
                Text(plugin.name)
                    .fontWeight(.medium)
                Text(plugin.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)
        }
    }
}
