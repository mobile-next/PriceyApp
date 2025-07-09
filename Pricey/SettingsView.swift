import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @State private var launchAtStartup = false
    @State private var linesPerDay = 100
    @State private var yearlySalary = 100000
    @State private var selectedSidebar = "General"
    
    var body: some View {
        NavigationSplitView {
            // Sidebar
            VStack(alignment: .leading, spacing: 0) {
                Text("APP SETTINGS")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.top, 40)
                
                Button(action: {
                    selectedSidebar = "General"
                }) {
                    HStack {
                        Image(systemName: "gearshape")
                        Text("General Settings")
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(selectedSidebar == "General" ? Color.accentColor.opacity(0.2) : Color.clear)
                    .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 8)
                .padding(.top, 12)
                
                Spacer()
            }
            .frame(minWidth: 240, maxWidth: 240)
            .background(Color(NSColor.controlBackgroundColor))
            
        } detail: {
            // Main content
            if selectedSidebar == "General" {
                Form {
                    Section {
                        Toggle("Launch at Startup", isOn: $launchAtStartup)
                            .onChange(of: launchAtStartup) {
                                handleLaunchAtStartupChange(launchAtStartup)
                            }
                    }
                    
                    Section("Development Settings") {
                        HStack {
                            Text("Lines of code per day:")
                            Spacer()
                            TextField("", value: $linesPerDay, format: .number)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 120)
                            Stepper("", value: $linesPerDay, in: 1...Int.max, step: 10)
                                .labelsHidden()
                        }
                        
                        HStack {
                            Text("Yearly salary (USD):")
                            Spacer()
                            TextField("", value: $yearlySalary, format: .number)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 120)
                            Stepper("", value: $yearlySalary, in: 0...Int.max, step: 5000)
                                .labelsHidden()
                        }
                    }
                }
                .formStyle(GroupedFormStyle())
                .padding()
            }
        }
        .navigationTitle("Settings")
        .frame(minWidth: 800, minHeight: 500)
        .onAppear {
            loadSettings()
        }
    }
    
    private func loadSettings() {
        launchAtStartup = isLaunchAtStartupEnabled()
        linesPerDay = UserDefaults.standard.integer(forKey: "LinesPerDay")
        if linesPerDay == 0 { linesPerDay = 100 }
        
        yearlySalary = UserDefaults.standard.integer(forKey: "YearlySalary")
        if yearlySalary == 0 { yearlySalary = 100000 }
    }
    
    private func handleLaunchAtStartupChange(_ shouldLaunch: Bool) {
        if shouldLaunch {
            addToLaunchAgents()
        } else {
            removeFromLaunchAgents()
        }
    }
    
    private func addToLaunchAgents() {
        do {
            try SMAppService.mainApp.register()
            print("Successfully added to launch agents")
            UserDefaults.standard.set(true, forKey: "LaunchAtStartup")
        } catch {
            print("Failed to add to launch agents: \(error)")
        }
    }
    
    private func removeFromLaunchAgents() {
        do {
            try SMAppService.mainApp.unregister()
            print("Successfully removed from launch agents")
            UserDefaults.standard.set(false, forKey: "LaunchAtStartup")
        } catch {
            print("Failed to remove from launch agents: \(error)")
        }
    }
    
    private func isLaunchAtStartupEnabled() -> Bool {
        let service = SMAppService.mainApp
        return service.status == .enabled
    }
}

#Preview {
    SettingsView()
}
