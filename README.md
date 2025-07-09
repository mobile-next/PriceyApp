# Pricey 💰

<div align="center">
  <img src="https://img.shields.io/badge/macOS-14.0+-blue.svg" alt="macOS 14.0+">
  <img src="https://img.shields.io/badge/Swift-5.9-orange.svg" alt="Swift 5.9">
  <img src="https://img.shields.io/badge/license-MIT-green.svg" alt="MIT License">
</div>

**Pricey** is a macOS status bar app that tracks your Claude Code AI usage costs in real-time and compares them to human developer costs. See exactly how your AI expenses stack up against traditional development - because spending $5 on AI that saves 2 hours of developer time is a bargain! 🤖💰

## Features

- 💰 **Real-time cost tracking** - See your Claude costs live in your menu bar
- 📊 **Code statistics** - Track lines of code added and removed by Claude Code
- 💼 **Salary calculator** - Calculate how much developer time you're saving
- 🎯 **Model-specific pricing** - Accurate costs for different Claude models
- 🔄 **Auto-refresh** - Automatically updates on code changes
- ⚡ **Lightweight** - Minimal resource usage, lives quietly in your menu bar

## Getting Started

### Prerequisites

- macOS 14.0 or later
- Claude Code app installed

### Installation

1. **Download the latest release** from the [releases page](https://github.com/mobile-next/pricey/releases)
2. **Move to Applications** - Drag `Pricey.app` to your Applications folder
3. **Launch** - Open Pricey from your Applications folder
4. **Grant permissions** - Allow file access when prompted

The app will automatically start tracking your Claude usage and display costs in your menu bar.

## How It Works

Pricey reads your Claude project files from `~/.claude/projects` and calculates costs based on:

- **Input tokens** - Text you send to Claude
- **Output tokens** - Claude's responses
- **Cache creation** - When Claude creates prompt cache
- **Cache reads** - When Claude uses cached prompts

Different Claude models have different pricing, and Pricey automatically detects which model was used for each conversation.

## Usage

### Menu Bar Display

The menu bar shows your current session costs (e.g., `$4.123`). Click the dollar sign icon to see:

- **Code statistics** - Lines added/removed
- **Salary savings** - Estimated developer time saved
- **Reset** - Clear current session costs
- **Settings** - Configure the app

### Settings

Configure Pricey to match your workflow:

- **Launch at startup** - Start Pricey automatically
- **Lines per day** - Your coding productivity (for salary calculation)
- **Yearly salary** - Your annual income (for savings calculation)

## Building from Source

### Prerequisites

- Xcode 15.0 or later

### Build Steps

```bash
# Clone the repository
git clone https://github.com/mobile-next/pricey.git
cd pricey

# Open in Xcode
open Pricey.xcodeproj

# Build and run
# Press Cmd+R in Xcode
```

## Contributing

We love contributions! Whether it's bug fixes, new features, or documentation improvements.

### How to Contribute

1. **Fork** the repository
2. **Create** a feature branch (`git checkout -b feature/amazing-feature`)
3. **Commit** your changes (`git commit -m 'Add amazing feature'`)
4. **Push** to the branch (`git push origin feature/amazing-feature`)
5. **Open** a Pull Request

## FAQ

### Why is the app not showing costs?

Make sure:
- Claude Code is installed and you've used it
- You've granted file access permissions
- Project files exist in `~/.claude/projects`

### Can I track costs for other AI services?

Currently, Pricey only supports Claude. We'd love to add support for other services if there's interest!

### Is my data secure?

Yes! Pricey only reads local files and never sends data anywhere. All processing happens locally on your Mac.

### Why does the app need file access?

Pricey reads Claude's local project files to calculate token usage and costs. This is read-only access to your `~/.claude/projects` directory.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

<div align="center">
  Made with ❤️ for the 10x engineers
</div>