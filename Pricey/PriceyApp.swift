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
			SettingsView()
		}
		.windowResizability(.contentSize)
		
		MenuBarExtra("Pricey", systemImage: "dollarsign.circle") {
			SettingsLink {
				Text("Settings...")
			}
			.keyboardShortcut(",", modifiers: .command)
			
			Divider()
			
			Button("Quit") {
				NSApplication.shared.terminate(nil)
			}
			.keyboardShortcut("q", modifiers: .command)
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
		
		// For status bar apps in macOS 14+, we need to open settings differently
		// Try the keyboard shortcut approach as the most reliable method
		let event = NSEvent.keyEvent(
			with: .keyDown,
			location: .zero,
			modifierFlags: .command,
			timestamp: 0,
			windowNumber: 0,
			context: nil,
			characters: ",",
			charactersIgnoringModifiers: ",",
			isARepeat: false,
			keyCode: 43
		)
		
		if let event = event {
			NSApp.sendEvent(event)
		}
		
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
