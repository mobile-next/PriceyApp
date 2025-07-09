import SwiftUI
import Foundation
import AppKit
import ServiceManagement

class SettingsWindowController: NSWindowController, NSTextFieldDelegate {
	@IBOutlet weak var launchAtStartupCheckbox: NSButton!
	@IBOutlet weak var linesPerDayTextField: NSTextField!
	@IBOutlet weak var linesPerDayStepper: NSStepper!
	@IBOutlet weak var yearlySalaryTextField: NSTextField!
	@IBOutlet weak var yearlySalaryStepper: NSStepper!
	
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
		
		// Lines per day label, text field, and stepper
		let linesLabel = NSTextField(labelWithString: "Lines of code per day:")
		linesLabel.translatesAutoresizingMaskIntoConstraints = false
		mainContent.addSubview(linesLabel)
		
		let linesTextField = NSTextField()
		linesTextField.translatesAutoresizingMaskIntoConstraints = false
		linesTextField.integerValue = 100
		linesTextField.placeholderString = "100"
		
		// Set up number formatter for lines field
		let linesFormatter = NumberFormatter()
		linesFormatter.numberStyle = .decimal
		linesFormatter.minimum = 1
		linesTextField.formatter = linesFormatter
		
		linesTextField.delegate = self
		mainContent.addSubview(linesTextField)
		self.linesPerDayTextField = linesTextField
		
		// Lines stepper
		let linesStepper = NSStepper()
		linesStepper.translatesAutoresizingMaskIntoConstraints = false
		linesStepper.minValue = 1
		linesStepper.maxValue = Double.greatestFiniteMagnitude
		linesStepper.increment = 10
		linesStepper.integerValue = 100
		linesStepper.target = self
		linesStepper.action = #selector(linesStepperChanged)
		mainContent.addSubview(linesStepper)
		self.linesPerDayStepper = linesStepper
		
		// Yearly salary label, text field, and stepper
		let salaryLabel = NSTextField(labelWithString: "Yearly salary (USD):")
		salaryLabel.translatesAutoresizingMaskIntoConstraints = false
		mainContent.addSubview(salaryLabel)
		
		let salaryTextField = NSTextField()
		salaryTextField.translatesAutoresizingMaskIntoConstraints = false
		salaryTextField.integerValue = 100000
		salaryTextField.placeholderString = "100000"
		
		// Set up number formatter for salary field
		let salaryFormatter = NumberFormatter()
		salaryFormatter.numberStyle = .decimal
		salaryFormatter.minimum = 0
		salaryTextField.formatter = salaryFormatter
		
		salaryTextField.delegate = self
		mainContent.addSubview(salaryTextField)
		self.yearlySalaryTextField = salaryTextField
		
		// Salary stepper
		let salaryStepper = NSStepper()
		salaryStepper.translatesAutoresizingMaskIntoConstraints = false
		salaryStepper.minValue = 0
		salaryStepper.maxValue = Double.greatestFiniteMagnitude
		salaryStepper.increment = 5000
		salaryStepper.integerValue = 100000
		salaryStepper.target = self
		salaryStepper.action = #selector(salaryStepperChanged)
		mainContent.addSubview(salaryStepper)
		self.yearlySalaryStepper = salaryStepper
		
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
			linesTextField.trailingAnchor.constraint(equalTo: linesStepper.leadingAnchor, constant: -5),
			
			// Lines stepper
			linesStepper.topAnchor.constraint(equalTo: linesLabel.topAnchor),
			linesStepper.trailingAnchor.constraint(equalTo: mainContent.trailingAnchor, constant: -30),
			linesStepper.widthAnchor.constraint(equalToConstant: 19),
			
			// Salary label
			salaryLabel.topAnchor.constraint(equalTo: linesLabel.bottomAnchor, constant: 20),
			salaryLabel.leadingAnchor.constraint(equalTo: mainContent.leadingAnchor, constant: 30),
			salaryLabel.widthAnchor.constraint(equalToConstant: 180),
			
			// Salary text field
			salaryTextField.topAnchor.constraint(equalTo: salaryLabel.topAnchor),
			salaryTextField.leadingAnchor.constraint(equalTo: salaryLabel.trailingAnchor, constant: 15),
			salaryTextField.trailingAnchor.constraint(equalTo: salaryStepper.leadingAnchor, constant: -5),
			
			// Salary stepper
			salaryStepper.topAnchor.constraint(equalTo: salaryLabel.topAnchor),
			salaryStepper.trailingAnchor.constraint(equalTo: mainContent.trailingAnchor, constant: -30),
			salaryStepper.widthAnchor.constraint(equalToConstant: 19)
		])
	}
	
	@objc private func selectGeneralSettings() {
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
	
	@objc private func linesStepperChanged() {
		linesPerDayTextField.integerValue = linesPerDayStepper.integerValue
	}
	
	@objc private func salaryStepperChanged() {
		yearlySalaryTextField.integerValue = yearlySalaryStepper.integerValue
	}
	
	// MARK: - NSTextFieldDelegate
	
	func controlTextDidChange(_ notification: Notification) {
		guard let textField = notification.object as? NSTextField else { return }
		
		if textField == linesPerDayTextField {
			linesPerDayStepper.integerValue = max(1, linesPerDayTextField.integerValue)
		} else if textField == yearlySalaryTextField {
			yearlySalaryStepper.integerValue = max(0, yearlySalaryTextField.integerValue)
		}
	}
	
	private func addToLaunchAgents() {
		if #available(macOS 13.0, *) {
			do {
				try SMAppService.mainApp.register()
				print("Successfully added to launch agents (new API)")
				UserDefaults.standard.set(true, forKey: "LaunchAtStartup")
			} catch {
				print("Failed to add to launch agents (new API): \(error)")
			}
		} else {
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
			do {
				try SMAppService.mainApp.unregister()
				print("Successfully removed from launch agents (new API)")
				UserDefaults.standard.set(false, forKey: "LaunchAtStartup")
			} catch {
				print("Failed to remove from launch agents (new API): \(error)")
			}
		} else {
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
		let service = SMAppService.mainApp
		return service.status == .enabled
	}
}