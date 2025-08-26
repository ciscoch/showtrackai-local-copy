# Auto Cycle Development Script Usage Guide

## Overview
The `auto_cycle.sh` script automates your development workflow by breaking down features into thin vertical slices, generating code, running tests, and managing version control automatically.

## Quick Start

### Basic Usage
```bash
./auto_cycle.sh "build my journaling app"
```

### What It Does
1. **Plans** the feature in 5-7 implementable slices
2. **Creates** a feature branch automatically  
3. **Generates** code slice by slice using Claude integration
4. **Tests** each slice automatically (analyze, unit tests, integration)
5. **Commits** changes with descriptive messages
6. **Documents** the entire process

## Prerequisites

### Required Tools
- Flutter SDK (in PATH)
- Git (initialized repository)
- Claude CLI (optional, will work without it)

### Project Structure
- Must be a Flutter project (`pubspec.yaml` present)
- Must have `.claude/commands/generate.md` file
- Git repository must be initialized

## Example Workflow

### 1. Start the Auto Cycle
```bash
./auto_cycle.sh "build my journaling app"
```

### 2. Planning Phase
The script will create:
- `planning_prompt.md` - Input for Claude
- `feature_plan.md` - Generated implementation plan

If Claude CLI is available, planning happens automatically. Otherwise, you'll get a template to fill out manually.

### 3. Implementation Phase
For each slice:
- Script creates `slice_prompt.md` 
- Prompts you to implement with Claude
- Runs tests automatically
- Commits changes with descriptive message
- Asks if you want to continue

### 4. Completion Phase
- Runs final compilation and test check
- Generates `IMPLEMENTATION_LOG.md`
- Provides next steps summary

## Working with Claude

### Automatic Integration
If you have Claude CLI installed:
```bash
# The script will automatically run:
claude --file planning_prompt.md > feature_plan.md
claude --file slice_prompt.md # For each implementation slice
```

### Manual Integration
Without Claude CLI, follow these steps:

1. **Planning:**
   ```bash
   # Copy contents of planning_prompt.md to Claude
   cat planning_prompt.md
   # Save Claude's response to feature_plan.md
   ```

2. **Implementation:**
   ```bash
   # For each slice, copy slice_prompt.md to Claude
   cat slice_prompt.md
   # Implement Claude's code suggestions
   # Press Enter to continue when done
   ```

## Branch Management

### Feature Branches
- Creates branches like: `feature/auto-cycle-20250826-143022`
- Always branches from `main` or `master`
- Pulls latest changes before starting
- Safe - never pushes automatically

### Git Integration
- Each slice gets its own commit
- Descriptive commit messages with `[auto-cycle]` tag
- Tracks all file changes
- Preserves history for easy rollback

## Testing Strategy

### Automated Tests
For each slice:
1. `flutter pub get` - Dependencies
2. `flutter analyze` - Code analysis
3. `flutter test` - Unit tests
4. `flutter test integration_test/` - Integration tests (if present)

### Build Verification
Final check:
- `flutter build apk --debug` - Compilation test
- Overall functionality assessment

## Generated Files

### During Execution
- `planning_prompt.md` - Claude input for planning
- `feature_plan.md` - Implementation roadmap
- `slice_prompt.md` - Claude input for current slice  
- `auto_cycle.log` - Detailed execution log

### After Completion
- `IMPLEMENTATION_LOG.md` - Complete implementation summary
- All source code changes committed to feature branch

## Configuration

### Script Variables
Edit at top of `auto_cycle.sh`:
```bash
MAX_ITERATIONS=10          # Maximum slices to implement
FEATURE_BRANCH_PREFIX="feature/auto-cycle"  # Branch naming
LOG_FILE="$PROJECT_ROOT/auto_cycle.log"     # Log location
```

### Flutter Project Structure
Expected structure for best results:
```
lib/
├── main.dart
├── models/        # Data models
├── services/      # Business logic
├── widgets/       # Reusable UI components  
├── screens/       # Page/screen components
└── utils/         # Utilities

test/              # Unit tests
integration_test/  # Integration tests (optional)
```

## Troubleshooting

### Common Issues

#### "Not a Flutter project"
**Solution:** Run from Flutter project root with `pubspec.yaml`

#### "Git repository not initialized"  
**Solution:** Run `git init` in project directory

#### "Claude generate command not found"
**Solution:** Ensure `.claude/commands/generate.md` exists

#### "Flutter not found in PATH"
**Solution:** Install Flutter SDK and add to PATH

### Recovery Options

#### Resume After Interruption
```bash
# Check current branch
git branch --show-current

# If on feature branch, continue manually
git log --oneline  # See what was completed
```

#### Rollback Changes
```bash
# Return to main branch
git checkout main

# Delete feature branch if needed
git branch -D feature/auto-cycle-TIMESTAMP
```

### Debug Mode
Enable verbose logging:
```bash
# Check the log file for details
tail -f auto_cycle.log

# Monitor git status
git status
git log --oneline -10
```

## Advanced Usage

### Custom Planning
Edit `feature_plan.md` manually for complex features:
1. Let script generate initial plan
2. Pause and edit the plan file
3. Continue with custom plan

### Selective Implementation
Stop at any slice:
- Choose option "2" when prompted
- Continue later from the same branch
- Pick up where you left off

### Integration with Existing Workflow
```bash
# Use with your existing branches
git checkout my-feature-branch
./auto_cycle.sh "add specific functionality"
```

## Best Practices

### Goal Descriptions
✅ **Good:** "build my journaling app"
✅ **Good:** "add user authentication with email"
✅ **Good:** "implement animal health tracking"

❌ **Avoid:** "make it better"
❌ **Avoid:** "fix everything"
❌ **Avoid:** "add features"

### Slice Management
- Review each slice before continuing
- Test manually when in doubt
- Don't skip failing tests
- Keep slices small and focused

### Version Control
- Review commits before pushing
- Use meaningful branch names
- Test in staging before main
- Document breaking changes

## Next Steps After Auto Cycle

1. **Manual Testing**
   ```bash
   flutter run
   # Test the implemented features
   ```

2. **Code Review**
   ```bash
   git log --oneline
   git diff main..HEAD
   ```

3. **Create Pull Request**
   ```bash
   git push origin feature/auto-cycle-TIMESTAMP
   # Create PR in your repository
   ```

4. **Documentation Update**
   - Update README if needed
   - Add to project documentation
   - Share learnings with team

## Example: Journaling App Implementation

Running `./auto_cycle.sh "build my journaling app"` typically generates:

### Slice 1: Data Models
- `lib/models/journal_entry.dart`
- Basic unit tests

### Slice 2: Service Layer
- `lib/services/journal_service.dart`
- Service unit tests

### Slice 3: UI Components
- `lib/widgets/journal_entry_widget.dart`
- Widget tests

### Slice 4: List Screen
- `lib/screens/journal_list_screen.dart`
- Navigation tests

### Slice 5: Add Entry
- `lib/screens/add_journal_entry_screen.dart`
- Form validation tests

### Slice 6: Data Persistence
- SQLite integration
- Persistence tests

### Slice 7: Polish
- Search, filtering, UI improvements
- End-to-end tests

Each slice builds upon the previous, creating a fully functional journaling app incrementally.

---

**Need help?** Check the generated `IMPLEMENTATION_LOG.md` after running the script, or review the detailed log in `auto_cycle.log`.