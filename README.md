# Philately iOS App

A comprehensive iOS application for stamp collectors built with SwiftUI and modern iOS development practices.

## 🚀 Project Overview

Philately is an iOS app designed to help collectors manage, catalog, and explore their stamp collections with an intuitive and beautiful interface.

## 📱 Features

*To be implemented*

- [ ] Digital stamp catalog
- [ ] Collection management
- [ ] Search and filtering
- [ ] Image recognition (future)
- [ ] Market value tracking (future)

## 🛠 Technology Stack

- **Language**: Swift 6
- **UI Framework**: SwiftUI
- **Architecture**: Clean Architecture / MVVM
- **Minimum iOS Version**: iOS 17+
- **Development Tool**: Xcode 16+

## 📂 Project Structure

```
Philately/
├── .cursor/              # Cursor AI rules and configuration
│   ├── rules/           # 24 specialized iOS development rules
│   ├── specs/           # Feature specifications
│   ├── tasks/           # Task tracking
│   ├── learnings/       # Knowledge base
│   ├── docs/            # Documentation
│   └── output/          # Generated artifacts
├── Source/              # App source code (to be created)
├── Tests/               # Unit and UI tests (to be created)
├── Resources/           # Assets and resources (to be created)
└── README.md           # This file
```

## 🔧 Development Setup

### Prerequisites

- macOS 14+ (Sonoma or later)
- Xcode 16+
- Swift 6+
- CocoaPods or Swift Package Manager (TBD)

### Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/philately-ios.git
cd philately-ios
```

2. Open the project in Xcode:
```bash
open Philately.xcodeproj
```

3. Build and run (⌘R)

## 🤖 AI-Assisted Development

This project uses Cursor AI with comprehensive iOS development rules:

- **Core Development**: `@with-swift`, `@with-ios`
- **Testing**: `@create-tests-swift`, `@with-tests`
- **Architecture**: `@clean-architecture-swift`, `@with-ddd-swift`
- **Release**: `@create-ios-release`, `@create-release`

See [.cursor/QUICKSTART.md](.cursor/QUICKSTART.md) and [CURSOR-RULES.md](CURSOR-RULES.md) for complete documentation.

## 🧪 Testing

```bash
# Run unit tests
xcodebuild test -scheme Philately -destination 'platform=iOS Simulator,name=iPhone 15'

# Run UI tests
xcodebuild test -scheme PhilatelyUITests -destination 'platform=iOS Simulator,name=iPhone 15'
```

## 🚀 Deployment

Deployment is managed using Fastlane and follows App Store guidelines.

See deployment documentation: `@create-ios-release` rule for details.

## 📝 Coding Standards

This project follows:
- Apple's Swift API Design Guidelines
- Swift coding best practices
- Clean Architecture principles
- Comprehensive testing requirements

All standards are enforced through Cursor AI rules in `.cursor/rules/`.

## 🤝 Contributing

1. Create a feature branch: `git checkout -b feature/your-feature`
2. Follow coding standards (use `@with-swift` rule)
3. Write tests (use `@create-tests-swift` rule)
4. Commit with conventional commits (use `@create-commit-message` rule)
5. Push and create a Pull Request

## 📄 License

*To be determined*

## 👥 Authors

- **Laxmi** - Initial development

## 🙏 Acknowledgments

- Built with [brunogama's iOS Cursor Rules](https://github.com/brunogama/ios-cursor-rules)
- Powered by Swift and SwiftUI
- Developed with Cursor AI

---

**Status**: 🟡 In Development

*Last Updated: January 27, 2026*
