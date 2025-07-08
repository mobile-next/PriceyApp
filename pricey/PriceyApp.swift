import SwiftUI
import Foundation

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
}

class AppDelegate: NSObject, NSApplicationDelegate {
	var statusBarItem: NSStatusItem!
	var costTracker = CostTracker()
	var updateTimer: Timer?
	var animatedTotalCost: AnimatedDouble!
	var animatedClaudeCost: AnimatedDouble!
	
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
		// Menu will show automatically
	}
	
	func updateStatusBarTitle() {
		_ = sumClaudeInputTokens()
		let totalCost = costTracker.claudeCost
		animatedTotalCost.value = totalCost
		animatedClaudeCost.value = costTracker.claudeCost
	}
	
	func createMenu() {
		let menu = NSMenu()
		
		let claudeItem = NSMenuItem(title: "Claude: $\(String(format: "%.3f", animatedClaudeCost.value))", action: nil, keyEquivalent: "")
		
		menu.addItem(claudeItem)
		menu.addItem(NSMenuItem.separator())
		
		let resetItem = NSMenuItem(title: "Reset", action: #selector(resetCosts), keyEquivalent: "")
		resetItem.target = self
		menu.addItem(resetItem)
		
		let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
		quitItem.target = self
		menu.addItem(quitItem)
		
		statusBarItem.menu = menu
	}
	
	@objc func resetCosts() {
		costTracker.reset()
		animatedTotalCost.value = 0.0
		animatedClaudeCost.value = 0.0
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
	
	struct TokenCounts {
		let inputTokens: Int64
		let outputTokens: Int64
		let cacheCreationTokens: Int64
		let cacheReadTokens: Int64
		
		static let zero = TokenCounts(inputTokens: 0, outputTokens: 0, cacheCreationTokens: 0, cacheReadTokens: 0)
		
		static func +(lhs: TokenCounts, rhs: TokenCounts) -> TokenCounts {
			return TokenCounts(
				inputTokens: lhs.inputTokens + rhs.inputTokens,
				outputTokens: lhs.outputTokens + rhs.outputTokens,
				cacheCreationTokens: lhs.cacheCreationTokens + rhs.cacheCreationTokens,
				cacheReadTokens: lhs.cacheReadTokens + rhs.cacheReadTokens
			)
		}
	}
	
	func processJsonlFile(filePath: String, seenRequestIds: inout Set<String>) -> TokenCounts {
		var tokenCounts = TokenCounts.zero
		print("Reading file: \(filePath)")
		
		let dateFormatter = DateFormatter()
		dateFormatter.dateFormat = "yyyy-MM-dd"
		let todayPrefix = dateFormatter.string(from: Date()) + "T"
		
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
							
							if let timestamp = json["timestamp"] as? String,
							   timestamp.starts(with: todayPrefix),
							   let message = json["message"] as? [String: Any],
							   let usage = message["usage"] as? [String: Any] {
								
								let inputTokens = Int64(usage["input_tokens"] as? Int ?? 0)
								let outputTokens = Int64(usage["output_tokens"] as? Int ?? 0)
								let cacheCreationTokens = Int64(usage["cache_creation_input_tokens"] as? Int ?? 0)
								let cacheReadTokens = Int64(usage["cache_read_input_tokens"] as? Int ?? 0)
								
								let additionalTokens = TokenCounts(
									inputTokens: inputTokens,
									outputTokens: outputTokens,
									cacheCreationTokens: cacheCreationTokens,
									cacheReadTokens: cacheReadTokens
								)
								
								tokenCounts = tokenCounts + additionalTokens
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
		
		return tokenCounts
	}
	
	func processDirectory(directoryPath: String, seenRequestIds: inout Set<String>) -> TokenCounts {
		let fileManager = FileManager.default
		var totalTokenCounts = TokenCounts.zero
		
		print("Processing project directory: \(directoryPath)")
		
		do {
			let projectContents = try fileManager.contentsOfDirectory(atPath: directoryPath)
			let jsonlFiles = projectContents.filter { $0.hasSuffix(".jsonl") }
			print("Found \(jsonlFiles.count) .jsonl files in \(directoryPath): \(jsonlFiles)")
			
			for jsonlFile in jsonlFiles {
				let filePath = "\(directoryPath)/\(jsonlFile)"
				let tokenCounts = processJsonlFile(filePath: filePath, seenRequestIds: &seenRequestIds)
				totalTokenCounts = totalTokenCounts + tokenCounts
			}
		} catch {
			print("Error reading directory \(directoryPath): \(error)")
		}
		
		return totalTokenCounts
	}
	
	func sumClaudeInputTokens(pricing: ClaudePricing = .default) -> Int64 {
		var totalTokenCounts = TokenCounts.zero
		var seenRequestIds = Set<String>()
		
		let projectDirectories = getClaudeProjectDirectories()
		print("Found \(projectDirectories.count) project directories: \(projectDirectories)")
		
		for projectDir in projectDirectories {
			let directoryTokenCounts = processDirectory(directoryPath: projectDir, seenRequestIds: &seenRequestIds)
			totalTokenCounts = totalTokenCounts + directoryTokenCounts
		}
		
		let totalCost = (pricing.inputTokenCostPer1M * Double(totalTokenCounts.inputTokens) / 1_000_000) +
						(pricing.outputTokenCostPer1M * Double(totalTokenCounts.outputTokens) / 1_000_000) +
						(pricing.cacheCreationTokenCostPer1M * Double(totalTokenCounts.cacheCreationTokens) / 1_000_000) +
						(pricing.cacheReadTokenCostPer1M * Double(totalTokenCounts.cacheReadTokens) / 1_000_000)
		
		costTracker.claudeCost = totalCost
		
		print("Total tokens calculated in: \(totalTokenCounts.inputTokens) out: \(totalTokenCounts.outputTokens) cache_creation: \(totalTokenCounts.cacheCreationTokens) cache_read: \(totalTokenCounts.cacheReadTokens)")
		print("Total Claude cost: $\(String(format: "%.4f", totalCost))")
		return totalTokenCounts.inputTokens
	}
}
