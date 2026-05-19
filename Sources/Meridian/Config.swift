import Foundation

// MARK: - GWSSource (referenced by both WelcomeView and OrgConfig)

/// Which credential source the user picks in the GWS segmented picker.
enum GWSSource: String, CaseIterable, Identifiable {
    case keeper      = "Keeper"
    case onePassword = "1Password"
    case direct      = "Enter directly"
    var id: String { rawValue }
}

// MARK: - OrgConfig

/// Org-specific defaults for this build of Meridian.
/// Fork this repo, edit only this file, and ship a customized app for your team.
enum OrgConfig {

    // MARK: Branding

    /// App title shown in the welcome view header.
    static let appTitle    = "Bankrate Meridian"

    /// Subtitle shown below the header icon.
    static let appSubtitle = "Your Bankrate agentic knowledge working environment."

    // MARK: Vault

    /// Pre-filled GitHub URL for the starter vault.
    /// Leave empty to start with a blank vault.
    static let defaultVaultURL = "https://github.com/rbcodelabs/bankrate-vault"

    // MARK: Google Workspace Credentials

    /// Which credential source is selected by default in the GWS picker.
    static let defaultGWSSource: GWSSource = .keeper

    /// Pre-filled email domain hint for Keeper auth (used in placeholder text).
    /// Set to "" to show a generic placeholder.
    static let defaultEmailDomain = "bankrate.com"

    /// Pre-filled Keeper record UID for the GWS OAuth credentials.
    /// Set to "" if unknown — the user must fill it in before setup can run.
    static let defaultKeeperUID = ""

    // MARK: Auto-update

    /// Sparkle appcast URL. Hosted on the public meridian GitHub Pages site
    /// under a bankrate/ subdirectory so no paid Pages plan is required.
    static let updateFeedURL   = "https://rbcodelabs.github.io/meridian/bankrate/appcast.xml"

    /// EdDSA public key matching the SPARKLE_PRIVATE_KEY secret in this repo.
    static let updatePublicKey = "NUlUXdomYQaFCld5icDl1FxgdQ4Uw/Bp7VQnYHqqL0I="
}
