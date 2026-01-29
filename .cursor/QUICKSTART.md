# iOS Cursor Rules - Quick Start Guide

Welcome to your comprehensive iOS development setup with Cursor AI! 🎉

**Project: StampFolio** - Your iOS stamp collection app

## 📦 What's Installed

You now have **24 specialized rule files** covering the complete iOS development lifecycle:

### 🍎 Core iOS Development
- `@with-swift` - Swift coding standards and best practices
- `@with-ios` - iOS-specific patterns and architecture
- `@clean-architecture-swift` - Clean Architecture principles
- `@with-ddd-swift` - Domain-Driven Design for Swift

### 🧪 Testing & Quality
- `@create-tests-swift` - Create comprehensive Swift tests
- `@with-tests` - Run and analyze tests
- `@swift-testing-policy` - Testing standards
- `@object-calisthenics-swift` - Code quality constraints

### 🚀 Release & Deployment
- `@create-ios-release` - Complete App Store submission guide
- `@create-release` - Version bumping and changelog
- `@create-commit-message` - Standardized commit messages

### 🔧 Workflow & Development
- `@finalize` - Post-development cleanup
- `@recover` - Error recovery and debugging
- `@main-refactoring-rules` - Code refactoring guidance

### 📋 Planning & Documentation
- `@prepare` - Pre-development research
- `@propose` - Feature proposals and planning
- `@create-prompt` - AI prompt generation

### 🏗 Project Management
- `@command-rules` - Custom command system
- `@knowledge-management-rule` - Knowledge base management
- `@specification-management-rule` - Requirements handling
- `@visualization-rule` - Project diagrams
- `@location-rule` - File organization
- `@on-load-rule` - Project initialization
- `@project-onboarding-rule` - New developer onboarding

## 🚀 How to Use

### Using Rules in Chat
Simply mention a rule with `@` in your message:

```
"Create a new SwiftUI view for user profile @with-swift @with-ios"
```

### Common Workflows

#### 1️⃣ **Starting a New Feature**
```
"I need to implement user authentication. x$"
```
Then implement:
```
"Implement the authentication flow we discussed @with-swift @with-ios"
```

#### 2️⃣ **Writing Tests**
```
"Create unit tests for the UserService class @create-tests-swift"
```
Run them:
```
"Run the tests and debug any failures @with-tests"
```

#### 3️⃣ **Preparing for Release**
```
"Prepare the app for App Store submission @create-ios-release"
```

#### 4️⃣ **Refactoring Code**
```
"Refactor the networking layer to use async/await @main-refactoring-rules @with-swift"
```

#### 5️⃣ **When Things Go Wrong**
```
"The app keeps crashing on launch @recover"
```

### Auto-Applying Rules

Some rules apply automatically based on file types:
- `.swift` files → `@with-swift` guidance
- Test files → `@create-tests-swift` assistance

## 📂 Directory Structure

Your workspace now includes:
```
.cursor/
├── rules/           # All 24 rule files
├── specs/           # Feature specifications
├── tasks/           # Task tracking
├── learnings/       # Knowledge base
├── docs/            # Documentation
└── output/          # Generated artifacts
```

## 🎯 Next Steps

1. **Start a New iOS Project**: Create your Xcode project in this directory
2. **Use Rules**: Reference rules with `@` when asking for help
3. **Read More**: Check `CURSOR-RULES.md` for detailed rule descriptions
4. **Customize**: Modify rules in `.cursor/rules/` as needed

## 📚 Additional Resources

- [Main Documentation](../CURSOR-RULES.md)
- [Contributing Guidelines](https://github.com/brunogama/ios-cursor-rules)
- [Apple Developer Documentation](https://developer.apple.com)

---

**Ready to build StampFolio! 🚀**
