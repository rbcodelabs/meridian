import Foundation

enum StepStatus: Equatable {
    case pending
    case running
    case done
    case skipped(String)
    case failed(String)

    static func == (lhs: StepStatus, rhs: StepStatus) -> Bool {
        switch (lhs, rhs) {
        case (.pending, .pending), (.running, .running), (.done, .done): return true
        case (.skipped(let a), .skipped(let b)): return a == b
        case (.failed(let a), .failed(let b)): return a == b
        default: return false
        }
    }
}

struct SetupStep: Identifiable {
    let id = UUID()
    let title: String
    var status: StepStatus = .pending
    var detail: String = ""
}

// MARK: - Obsidian Plugins

struct ObsidianPlugin: Identifiable {
    let id: String          // matches the folder name and community-plugins.json entry
    let name: String
    let description: String
    let isBundled: Bool     // true = has a folder in .obsidian/plugins/ that must be deleted if excluded
    var isSelected: Bool = true

    static let all: [ObsidianPlugin] = [
        // rbcodelabs plugins (bundled as full plugin folders in the vault)
        .init(id: "claude-threads",       name: "Claude Threads",       description: "Multi-threaded AI chat sessions in Obsidian",           isBundled: true),
        .init(id: "kanban-bases-view",    name: "Kanban Bases View",    description: "Drag-and-drop kanban for Obsidian Bases",               isBundled: true),
        .init(id: "linear-integration",   name: "Linear Integration",   description: "Two-way Linear issue sync",                            isBundled: true),
        .init(id: "obsidian-gdocs-sync",  name: "Google Docs Sync",     description: "Bi-directional Obsidian ↔ Google Docs sync",           isBundled: true),
        .init(id: "obsidian-tasks-plugin",name: "Tasks",                description: "Task management with due dates and recurrence",        isBundled: true),
        .init(id: "obsidian42-brat",      name: "BRAT",                 description: "Auto-updates for beta plugins",                        isBundled: true),
        .init(id: "mdx-support",          name: "MDX Support",          description: "MDX file support in Obsidian",                         isBundled: true),

        // Community plugins (installed from the registry when Obsidian first opens)
        .init(id: "dataview",                         name: "Dataview",                description: "Query your vault like a database",                           isBundled: false),
        .init(id: "templater-obsidian",               name: "Templater",               description: "Powerful template language for notes",                       isBundled: false),
        .init(id: "quickadd",                         name: "QuickAdd",                description: "Quickly add notes, capture text, and run macros",            isBundled: false),
        .init(id: "periodic-notes",                   name: "Periodic Notes",          description: "Daily, weekly, and monthly note templates",                  isBundled: false),
        .init(id: "calendar",                         name: "Calendar",                description: "Calendar view for daily notes",                              isBundled: false),
        .init(id: "omnisearch",                       name: "Omnisearch",              description: "Better full-text search across your vault",                  isBundled: false),
        .init(id: "smart-connections",                name: "Smart Connections",       description: "AI-powered semantic note connections",                       isBundled: false),
        .init(id: "nldates-obsidian",                 name: "Natural Language Dates",  description: "Parse dates like 'next Monday' in notes",                    isBundled: false),
        .init(id: "text-extractor",                   name: "Text Extractor",          description: "Extract text from PDFs and images for search",               isBundled: false),
        .init(id: "obsidian-style-settings",          name: "Style Settings",          description: "Fine-tune theme appearance",                                 isBundled: false),
        .init(id: "obsidian-minimal-settings",        name: "Minimal Theme Settings",  description: "Settings panel for the Minimal theme",                       isBundled: false),
        .init(id: "obsidian-system-dark-mode",        name: "System Dark Mode",        description: "Sync dark/light mode with macOS",                            isBundled: false),
        .init(id: "recent-files-obsidian",            name: "Recent Files",            description: "Show recently opened files in the sidebar",                  isBundled: false),
        .init(id: "obsidian-auto-link-title",         name: "Auto Link Title",         description: "Auto-fetch page titles for pasted URLs",                     isBundled: false),
        .init(id: "obsidian-rollover-daily-todos",    name: "Rollover Daily Todos",    description: "Roll unfinished tasks forward to the next daily note",       isBundled: false),
        .init(id: "note-refactor-obsidian",           name: "Note Refactor",           description: "Extract selections into new notes or split notes",           isBundled: false),
        .init(id: "obsidian-local-images",            name: "Local Images",            description: "Download and embed remote images locally",                   isBundled: false),
        .init(id: "markdown-table-editor",            name: "Markdown Table Editor",   description: "Visual table editing with alignment controls",                isBundled: false),
        .init(id: "obsidian-excel-to-markdown-table", name: "Excel to Markdown",       description: "Paste Excel data as formatted markdown tables",              isBundled: false),
        .init(id: "obsidian-regex-replace",           name: "Regex Replace",           description: "Find and replace using regular expressions",                 isBundled: false),
        .init(id: "obsidian-regex-pipeline",          name: "Regex Pipeline",          description: "Run multiple regex replacements in sequence",                isBundled: false),
        .init(id: "obsidian-custom-frames",           name: "Custom Frames",           description: "Embed websites as sidebar panes",                            isBundled: false),
    ]
}

// MARK: - Setup Options

struct SetupOptions {
    var installObsidian: Bool = true
    var obsidianPlugins: [ObsidianPlugin] = ObsidianPlugin.all
    var installHomebrew: Bool = true
    var installClaudeCode: Bool = true
    var installGitHub: Bool = true
    var installGWS: Bool = true
}
