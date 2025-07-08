import SwiftUI
import Foundation
import AppKit
import ServiceManagement

struct FileCacheEntry {
	let timestamp: Date
	let usageStat: UsageStat
}

struct ClaudePricing {
	let inputTokenCostPer1M: Double
	let outputTokenCostPer1M: Double
	let cacheCreationTokenCostPer1M: Double
	let cacheReadTokenCostPer1M: Double
	
	static let `default` = ClaudePricing(
		inputTokenCostPer1M: 3.0,
		outputTokenCostPer1M: 15.0,
		cacheCreationTokenCostPer1M: 3.75,
		cacheReadTokenCostPer1M: 0.30
	)
}

@main
struct PriceyApp: App {
	@NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
	
	var body: some Scene {
		Settings {
			EmptyView()
		}
	}
	
	static func getMidnightToday() -> Date {
		let calendar = Calendar.current
		let today = Date()
		return calendar.startOfDay(for: today)
	}
}

class AppDelegate: NSObject, NSApplicationDelegate {
	var statusBarItem: NSStatusItem!
	var costTracker = CostTracker()
	var updateTimer: Timer?
	var animatedTotalCost: AnimatedDouble!
	var animatedClaudeCost: AnimatedDouble!
	var timestampThreshold: Date = PriceyApp.getMidnightToday()
	var settingsWindowController: SettingsWindowController?
	static var fileCache: [String: FileCacheEntry] = [:]
	
	func applicationDidFinishLaunching(_ notification: Notification) {
		NSApp.setActivationPolicy(.accessory)
		statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
		
		animatedTotalCost = AnimatedDouble(initialValue: 0.0) { [weak self] value in
			DispatchQueue.main.async {
				if let button = self?.statusBarItem.button {
					button.title = "$\(String(format: "%.3f", value))"
					button.font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
				}
			}
		}
		
		animatedClaudeCost = AnimatedDouble(initialValue: 0.0) { [weak self] _ in
			DispatchQueue.main.async {
				self?.createMenu()
			}
		}
		
		if let button = statusBarItem.button {
			updateStatusBarTitle()
			button.action = #selector(statusBarButtonClicked)
			button.target = self
		}
		
		createMenu()
		
		updateTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
			self.updateStatusBarTitle()
		}
	}
	
	@objc func statusBarButtonClicked() {
	}
	
	func updateStatusBarTitle() {
		_ = sumClaudeInputTokens()
		let totalCost = costTracker.claudeCost
		animatedTotalCost.value = totalCost
		animatedClaudeCost.value = costTracker.claudeCost
	}
	
	func createMenu() {
		let menu = NSMenu()
		
		// let claudeItem = NSMenuItem(title: "Claude: $\(String(format: "%.3f", animatedClaudeCost.value))", action: nil, keyEquivalent: "")
		
		// Get current usage statistics
		let totalUsageStat = getTokenCounts()
				
		// Create attributed string for line change statistics
		let lineStatsString = NSMutableAttributedString()
		lineStatsString.append(NSAttributedString(string: "+\(totalUsageStat.linesAdded)", attributes: [
			.foregroundColor: NSColor(red: 0x3F/255.0, green: 0xBA/255.0, blue: 0x50/255.0, alpha: 1.0)
		]))
		
		lineStatsString.append(NSAttributedString(string: " -\(totalUsageStat.linesRemoved)", attributes: [
			.foregroundColor: NSColor(red: 0xD1/255.0, green: 0x24/255.0, blue: 0x2F/255.0, alpha: 1.0)
		]))
				
		lineStatsString.append(NSAttributedString(string: " lines", attributes: [
			.foregroundColor: NSColor.labelColor
		]))
		
		let lineStatsItem = NSMenuItem()
		lineStatsItem.attributedTitle = lineStatsString
		lineStatsItem.action = #selector(emptyCallback)
		
		// menu.addItem(claudeItem)
		menu.addItem(lineStatsItem)
		menu.addItem(NSMenuItem.separator())
		
		let resetItem = NSMenuItem(title: "Reset", action: #selector(resetCosts), keyEquivalent: "")
		resetItem.target = self
		menu.addItem(resetItem)
		
		let settingsItem = NSMenuItem(title: "Settings", action: #selector(openSettings), keyEquivalent: ",")
		settingsItem.target = self
		menu.addItem(settingsItem)
		
		let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
		quitItem.target = self
		menu.addItem(quitItem)
		
		statusBarItem.menu = menu
	}
	
	@objc func emptyCallback() {		
	}
	
	@objc func resetCosts() {
		costTracker.reset()
		animatedTotalCost.value = 0.0
		animatedClaudeCost.value = 0.0
		timestampThreshold = Date()
		
		// Clear cache to force re-reading with new timestamp threshold
		AppDelegate.fileCache.removeAll()
	}
	
	@objc func openSettings() {
		print("Opening settings window...")
		if settingsWindowController == nil {
			print("Creating new settings window controller")
			settingsWindowController = SettingsWindowController()
		}
		print("Showing settings window")
		settingsWindowController?.showWindow(nil)
		settingsWindowController?.window?.makeKeyAndOrderFront(nil)
		NSApp.activate(ignoringOtherApps: true)
	}
	
	@objc func quitApp() {
		NSApplication.shared.terminate(nil)
	}
	
	func getClaudeProjectDirectories() -> [String] {
		let homeDirectory = FileManager.default.homeDirectoryForCurrentUser.path
		let claudeProjectsPath = "\(homeDirectory)/.claude/projects"
		let fileManager = FileManager.default
		
		do {
			let contents = try fileManager.contentsOfDirectory(atPath: claudeProjectsPath)
			return contents.compactMap { item in
				var isDirectory: ObjCBool = false
				let fullPath = "\(claudeProjectsPath)/\(item)"
				if fileManager.fileExists(atPath: fullPath, isDirectory: &isDirectory) && isDirectory.boolValue {
					return fullPath
				}
				return nil
			}
		} catch {
			print("exception \(error)")
			return []
		}
	}
	
	func processJsonlFile(filePath: String, seenRequestIds: inout Set<String>) -> UsageStat {
		let fileManager = FileManager.default
		
		// get file modification timestamp
		guard let attributes = try? fileManager.attributesOfItem(atPath: filePath),
			  let modificationDate = attributes[.modificationDate] as? Date else {
			print("Could not get file attributes for: \(filePath)")
			return UsageStat.zero
		}
		
		// check cache timestamp
		if let cachedEntry = AppDelegate.fileCache[filePath],
		   cachedEntry.timestamp == modificationDate {
			//print("Cache hit for file: \(filePath)")
			return cachedEntry.usageStat
		}
		
		var usageStat = UsageStat.zero
		// print("Reading file: \(filePath)")
		
		let dateFormatter = DateFormatter()
		dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
		dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
		
		do {
			let fileContent = try String(contentsOfFile: filePath, encoding: .utf8)
			let lines = fileContent.components(separatedBy: .newlines)
			
			for (lineIndex, line) in lines.enumerated() {
				if !line.trimmingCharacters(in: .whitespaces).isEmpty {
					do {
						if let jsonData = line.data(using: .utf8),
						   let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
							
							if let requestId = json["requestId"] as? String {
								if seenRequestIds.contains(requestId) {
									continue
								}
								seenRequestIds.insert(requestId)
							}
							
							if let timestampString = json["timestamp"] as? String,
							   let timestamp = dateFormatter.date(from: timestampString),
							   timestamp >= timestampThreshold {
								
								// Parse token usage data
								var inputTokens: Int64 = 0
								var outputTokens: Int64 = 0
								var cacheCreationTokens: Int64 = 0
								var cacheReadTokens: Int64 = 0
								var linesAdded: Int64 = 0
								var linesRemoved: Int64 = 0
								
								if let message = json["message"] as? [String: Any],
								   let usage = message["usage"] as? [String: Any] {
									inputTokens = Int64(usage["input_tokens"] as? Int ?? 0)
									outputTokens = Int64(usage["output_tokens"] as? Int ?? 0)
									cacheCreationTokens = Int64(usage["cache_creation_input_tokens"] as? Int ?? 0)
									cacheReadTokens = Int64(usage["cache_read_input_tokens"] as? Int ?? 0)
								}
								
								// Parse toolUseResult.structuredPatch data
								if let toolUseResult = json["toolUseResult"] as? [String: Any],
								   let structuredPatch = toolUseResult["structuredPatch"] as? [[String: Any]] {
									for patch in structuredPatch {
										if let patchLines = patch["lines"] as? [String] {
											for patchLine in patchLines {
												if patchLine.hasPrefix("+") {
													linesAdded += 1
												} else if patchLine.hasPrefix("-") {
													linesRemoved += 1
												}
											}
										}
									}
								}
								
								let additionalStat = UsageStat(
									inputTokens: inputTokens,
									outputTokens: outputTokens,
									cacheCreationTokens: cacheCreationTokens,
									cacheReadTokens: cacheReadTokens,
									linesAdded: linesAdded,
									linesRemoved: linesRemoved
								)
								
								usageStat = usageStat + additionalStat
							}
						} else {
							print("Line \(lineIndex): Failed to parse JSON")
						}
					} catch {
						print("Line \(lineIndex): JSON parsing error: \(error)")
					}
				}
			}
		} catch {
			print("Error reading file \(filePath): \(error)")
		}
		
		// Update cache
		AppDelegate.fileCache[filePath] = FileCacheEntry(
			timestamp: modificationDate,
			usageStat: usageStat
		)
		
		return usageStat
	}
	
	func processDirectory(directoryPath: String, seenRequestIds: inout Set<String>) -> UsageStat {
		let fileManager = FileManager.default
		var totalUsageStat = UsageStat.zero
		
		// print("Processing project directory: \(directoryPath)")
		
		do {
			let projectContents = try fileManager.contentsOfDirectory(atPath: directoryPath)
			let jsonlFiles = projectContents.filter { $0.hasSuffix(".jsonl") }
			print("Found \(jsonlFiles.count) .jsonl files in \(directoryPath)")
			
			for jsonlFile in jsonlFiles {
				let filePath = "\(directoryPath)/\(jsonlFile)"
				let usageStat = processJsonlFile(filePath: filePath, seenRequestIds: &seenRequestIds)
				totalUsageStat = totalUsageStat + usageStat
			}
		} catch {
			print("Error reading directory \(directoryPath): \(error)")
		}
		
		return totalUsageStat
	}
	
	func getTokenCounts(pricing: ClaudePricing = .default) -> UsageStat {
		var totalUsageStat = UsageStat.zero
		var seenRequestIds = Set<String>()
		
		let projectDirectories = getClaudeProjectDirectories()
		print("Found \(projectDirectories.count) project directories: \(projectDirectories)")
		
		for projectDir in projectDirectories {
			let directoryUsageStat = processDirectory(directoryPath: projectDir, seenRequestIds: &seenRequestIds)
			totalUsageStat = totalUsageStat + directoryUsageStat
		}
		
		let totalCost = (pricing.inputTokenCostPer1M * Double(totalUsageStat.inputTokens) / 1_000_000) +
						(pricing.outputTokenCostPer1M * Double(totalUsageStat.outputTokens) / 1_000_000) +
						(pricing.cacheCreationTokenCostPer1M * Double(totalUsageStat.cacheCreationTokens) / 1_000_000) +
						(pricing.cacheReadTokenCostPer1M * Double(totalUsageStat.cacheReadTokens) / 1_000_000)
		
		costTracker.claudeCost = totalCost
		
		print("Total tokens calculated in: \(totalUsageStat.inputTokens) out: \(totalUsageStat.outputTokens) cache_creation: \(totalUsageStat.cacheCreationTokens) cache_read: \(totalUsageStat.cacheReadTokens)")
		print("Total usage stats - Lines added: \(totalUsageStat.linesAdded) removed: \(totalUsageStat.linesRemoved)")
		print("Total Claude cost: $\(String(format: "%.4f", totalCost))")
		return totalUsageStat
	}
	
	func sumClaudeInputTokens(pricing: ClaudePricing = .default) -> Int64 {
		let totalUsageStat = getTokenCounts(pricing: pricing)
		return totalUsageStat.inputTokens
	}
}

class SettingsWindowController: NSWindowController {
	@IBOutlet weak var launchAtStartupCheckbox: NSButton!
	@IBOutlet weak var linesPerDayTextField: NSTextField!
	@IBOutlet weak var yearlySalaryTextField: NSTextField!
	
	override init(window: NSWindow?) {
		super.init(window: window)
		setupWindow()
	}
	
	required init?(coder: NSCoder) {
		super.init(coder: coder)
		setupWindow()
	}
	
	convenience init() {
		self.init(window: nil)
	}
	
	private func setupWindow() {
		print("Setting up settings window...")
		let window = NSWindow(
			contentRect: NSRect(x: 0, y: 0, width: 800, height: 500),
			styleMask: [.titled, .closable, .resizable],
			backing: .buffered,
			defer: false
		)
		
		window.title = "Settings"
		window.center()
		window.isReleasedWhenClosed = false
		window.minSize = NSSize(width: 600, height: 400)
		
		self.window = window
		print("Window created, setting up UI...")
		setupUI()
		print("Settings window setup complete")
	}
	
	private func setupUI() {
		guard let window = self.window else { return }
		
		let contentView = NSView(frame: window.contentRect(forFrameRect: window.frame))
		window.contentView = contentView
		
		// Create split view
		let splitView = NSSplitView()
		splitView.isVertical = true
		splitView.dividerStyle = .thin
		splitView.translatesAutoresizingMaskIntoConstraints = false
		contentView.addSubview(splitView)
		
		// Create sidebar
		let sidebar = NSView()
		sidebar.wantsLayer = true
		sidebar.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
		
		// Create main content area
		let mainContent = NSView()
		mainContent.wantsLayer = true
		mainContent.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
		
		splitView.addArrangedSubview(sidebar)
		splitView.addArrangedSubview(mainContent)
		
		// Setup sidebar content
		setupSidebar(sidebar)
		
		// Setup main content
		setupMainContent(mainContent)
		
		// Setup constraints
		NSLayoutConstraint.activate([
			splitView.topAnchor.constraint(equalTo: contentView.topAnchor),
			splitView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
			splitView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
			splitView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
			
			sidebar.widthAnchor.constraint(equalToConstant: 240)
		])
		
		// Set split view position
		splitView.setPosition(240, ofDividerAt: 0)
	}
	
	private func setupSidebar(_ sidebar: NSView) {
		// Category header
		let categoryHeader = NSTextField(labelWithString: "APP SETTINGS")
		categoryHeader.font = NSFont.systemFont(ofSize: 11, weight: .medium)
		categoryHeader.textColor = NSColor.secondaryLabelColor
		categoryHeader.translatesAutoresizingMaskIntoConstraints = false
		sidebar.addSubview(categoryHeader)
		
		// General Settings button
		let generalButton = NSButton()
		generalButton.title = "General Settings"
		generalButton.bezelStyle = .rounded
		generalButton.isBordered = false
		generalButton.alignment = .left
		generalButton.font = NSFont.systemFont(ofSize: 13)
		generalButton.contentTintColor = NSColor.labelColor
		generalButton.translatesAutoresizingMaskIntoConstraints = false
		generalButton.target = self
		generalButton.action = #selector(selectGeneralSettings)
		sidebar.addSubview(generalButton)
		
		// Add gear icon to general button
		if let gearImage = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "Settings") {
			generalButton.image = gearImage
			generalButton.imagePosition = .imageLeading
			generalButton.imageHugsTitle = true
		}
		
		NSLayoutConstraint.activate([
			categoryHeader.topAnchor.constraint(equalTo: sidebar.topAnchor, constant: 40),
			categoryHeader.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor, constant: 20),
			categoryHeader.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: -20),
			
			generalButton.topAnchor.constraint(equalTo: categoryHeader.bottomAnchor, constant: 12),
			generalButton.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor, constant: 20),
			generalButton.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: -20),
			generalButton.heightAnchor.constraint(equalToConstant: 32)
		])
	}
	
	private func setupMainContent(_ mainContent: NSView) {
		// Launch at Startup checkbox
		let launchCheckbox = NSButton(checkboxWithTitle: "Launch at Startup", target: self, action: #selector(launchAtStartupChanged))
		launchCheckbox.translatesAutoresizingMaskIntoConstraints = false
		launchCheckbox.state = isLaunchAtStartupEnabled() ? .on : .off
		mainContent.addSubview(launchCheckbox)
		self.launchAtStartupCheckbox = launchCheckbox
		
		// Lines per day label and text field
		let linesLabel = NSTextField(labelWithString: "Lines of code per day:")
		linesLabel.translatesAutoresizingMaskIntoConstraints = false
		mainContent.addSubview(linesLabel)
		
		let linesTextField = NSTextField()
		linesTextField.translatesAutoresizingMaskIntoConstraints = false
		linesTextField.stringValue = "100"
		linesTextField.placeholderString = "100"
		mainContent.addSubview(linesTextField)
		self.linesPerDayTextField = linesTextField
		
		// Yearly salary label and text field
		let salaryLabel = NSTextField(labelWithString: "Yearly salary (USD):")
		salaryLabel.translatesAutoresizingMaskIntoConstraints = false
		mainContent.addSubview(salaryLabel)
		
		let salaryTextField = NSTextField()
		salaryTextField.translatesAutoresizingMaskIntoConstraints = false
		salaryTextField.stringValue = "100000"
		salaryTextField.placeholderString = "100000"
		mainContent.addSubview(salaryTextField)
		self.yearlySalaryTextField = salaryTextField
		
		// Setup constraints for main content
		NSLayoutConstraint.activate([
			// Launch checkbox
			launchCheckbox.topAnchor.constraint(equalTo: mainContent.topAnchor, constant: 40),
			launchCheckbox.leadingAnchor.constraint(equalTo: mainContent.leadingAnchor, constant: 30),
			launchCheckbox.trailingAnchor.constraint(lessThanOrEqualTo: mainContent.trailingAnchor, constant: -30),
			
			// Lines label
			linesLabel.topAnchor.constraint(equalTo: launchCheckbox.bottomAnchor, constant: 30),
			linesLabel.leadingAnchor.constraint(equalTo: mainContent.leadingAnchor, constant: 30),
			linesLabel.widthAnchor.constraint(equalToConstant: 180),
			
			// Lines text field
			linesTextField.topAnchor.constraint(equalTo: linesLabel.topAnchor),
			linesTextField.leadingAnchor.constraint(equalTo: linesLabel.trailingAnchor, constant: 15),
			linesTextField.trailingAnchor.constraint(equalTo: mainContent.trailingAnchor, constant: -30),
			
			// Salary label
			salaryLabel.topAnchor.constraint(equalTo: linesLabel.bottomAnchor, constant: 20),
			salaryLabel.leadingAnchor.constraint(equalTo: mainContent.leadingAnchor, constant: 30),
			salaryLabel.widthAnchor.constraint(equalToConstant: 180),
			
			// Salary text field
			salaryTextField.topAnchor.constraint(equalTo: salaryLabel.topAnchor),
			salaryTextField.leadingAnchor.constraint(equalTo: salaryLabel.trailingAnchor, constant: 15),
			salaryTextField.trailingAnchor.constraint(equalTo: mainContent.trailingAnchor, constant: -30)
		])
	}
	
	@objc private func selectGeneralSettings() {
		// TODO: Handle category selection
		print("General Settings selected")
	}
	
	@objc private func launchAtStartupChanged() {
		let shouldLaunchAtStartup = launchAtStartupCheckbox.state == .on
		print("Launch at startup changed: \(shouldLaunchAtStartup)")
		
		if shouldLaunchAtStartup {
			addToLaunchAgents()
		} else {
			removeFromLaunchAgents()
		}
	}
	
	private func addToLaunchAgents() {
		if #available(macOS 13.0, *) {
			// Use new API for macOS 13+
			do {
				try SMAppService.mainApp.register()
				print("Successfully added to launch agents (new API)")
				UserDefaults.standard.set(true, forKey: "LaunchAtStartup")
			} catch {
				print("Failed to add to launch agents (new API): \(error)")
			}
		} else {
			// Use legacy API for older macOS versions
			guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
				print("Error: Could not get bundle identifier")
				return
			}
			
			let success = SMLoginItemSetEnabled(bundleIdentifier as CFString, true)
			if success {
				print("Successfully added to launch agents (legacy API)")
				UserDefaults.standard.set(true, forKey: "LaunchAtStartup")
			} else {
				print("Failed to add to launch agents (legacy API)")
			}
		}
	}
	
	private func removeFromLaunchAgents() {
		if #available(macOS 13.0, *) {
			// Use new API for macOS 13+
			do {
				try SMAppService.mainApp.unregister()
				print("Successfully removed from launch agents (new API)")
				UserDefaults.standard.set(false, forKey: "LaunchAtStartup")
			} catch {
				print("Failed to remove from launch agents (new API): \(error)")
			}
		} else {
			// Use legacy API for older macOS versions
			guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
				print("Error: Could not get bundle identifier")
				return
			}
			
			let success = SMLoginItemSetEnabled(bundleIdentifier as CFString, false)
			if success {
				print("Successfully removed from launch agents (legacy API)")
				UserDefaults.standard.set(false, forKey: "LaunchAtStartup")
			} else {
				print("Failed to remove from launch agents (legacy API)")
			}
		}
	}
	
	private func isLaunchAtStartupEnabled() -> Bool {
		guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
			return false
		}
		
		// Use the newer macOS 13+ API if available
		if #available(macOS 13.0, *) {
			let service = SMAppService.mainApp
			return service.status == .enabled
		} else {
			// Fallback for older macOS versions
			return checkLoginItemsLegacy(bundleIdentifier: bundleIdentifier)
		}
	}
	
	private func checkLoginItemsLegacy(bundleIdentifier: String) -> Bool {
		// For older macOS versions, we'll use a combination approach
		// Check if we can find our app in the login items through LaunchServices
		let workspace = NSWorkspace.shared
		
		// Get login items using the legacy approach
		let script = """
		tell application "System Events"
			get the name of every login item
		end tell
		"""
		
		var error: NSDictionary?
		if let scriptObject = NSAppleScript(source: script) {
			if let output = scriptObject.executeAndReturnError(&error) {
				let loginItems = output.stringValue ?? ""
				let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "pricey"
				return loginItems.contains(appName)
			}
		}
		
		// If AppleScript fails, fall back to UserDefaults as last resort
		return UserDefaults.standard.bool(forKey: "LaunchAtStartup")
	}
}
