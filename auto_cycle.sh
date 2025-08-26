#!/bin/bash

# auto_cycle.sh - Automated Development Cycle Script
# Usage: ./auto_cycle.sh "build my journaling app"
# 
# This script automates the development process by:
# - Planning features in thin vertical slices
# - Generating code iteratively
# - Running tests automatically
# - Committing changes with descriptive messages
# - Documenting progress

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"
CLAUDE_DIR="$PROJECT_ROOT/.claude"
LOG_FILE="$PROJECT_ROOT/auto_cycle.log"
MAX_ITERATIONS=10
FEATURE_BRANCH_PREFIX="feature/auto-cycle"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1" >> "$LOG_FILE"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >> "$LOG_FILE"
}

info() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Initialize logging
init_logging() {
    touch "$LOG_FILE"
    log "=== Auto Cycle Started: $GOAL ==="
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if we're in a Flutter project
    if [[ ! -f "$PROJECT_ROOT/pubspec.yaml" ]]; then
        error "Not a Flutter project (no pubspec.yaml found)"
        exit 1
    fi
    
    # Check if git is initialized
    if [[ ! -d "$PROJECT_ROOT/.git" ]]; then
        error "Git repository not initialized"
        exit 1
    fi
    
    # Check for Claude commands
    if [[ ! -f "$CLAUDE_DIR/commands/generate.md" ]]; then
        error "Claude generate command not found at $CLAUDE_DIR/commands/generate.md"
        exit 1
    fi
    
    # Check if Flutter is available
    if ! command -v flutter &> /dev/null; then
        error "Flutter not found in PATH"
        exit 1
    fi
    
    log "Prerequisites check passed"
}

# Create feature branch
create_feature_branch() {
    local branch_name="$1"
    log "Creating feature branch: $branch_name"
    
    # Ensure we're on main/master
    git checkout main 2>/dev/null || git checkout master 2>/dev/null || {
        warn "Could not checkout main/master branch, staying on current branch"
    }
    
    # Pull latest changes
    git pull origin $(git branch --show-current) 2>/dev/null || warn "Could not pull latest changes"
    
    # Create and checkout feature branch
    git checkout -b "$branch_name" || {
        warn "Branch $branch_name already exists, checking it out"
        git checkout "$branch_name"
    }
    
    log "Working on branch: $branch_name"
}

# Plan feature implementation
plan_feature() {
    local goal="$1"
    log "Planning feature implementation for: $goal"
    
    # Create a planning prompt for Claude
    cat > "$PROJECT_ROOT/planning_prompt.md" << EOF
# Feature Planning Request

## Goal
$goal

## Current Project Structure
This is a Flutter ShowTrackAI app for agricultural education with the following structure:
- lib/main.dart - Main application entry
- lib/services/ - Business logic and API services
- lib/widgets/ - Reusable UI components
- lib/screens/ - Screen/page components
- lib/models/ - Data models
- test/ - Test files

## Planning Requirements
Please break down this goal into 5-7 thin vertical slices that can be implemented incrementally. Each slice should:
1. Be independently testable
2. Provide visible user value
3. Build upon the previous slice
4. Take 1-3 hours to implement

For each slice, provide:
- Brief description
- Key files to create/modify
- Testing approach
- Success criteria

## Output Format
Please structure your response as:

### Slice 1: [Title]
**Description:** [What this slice accomplishes]
**Files:** [Key files to create/modify]
**Tests:** [How to test this slice]
**Success:** [When this slice is complete]

[Continue for all slices...]
EOF

    info "Planning prompt created. Next: Use Claude to analyze and plan the feature."
    info "Run: claude --file planning_prompt.md"
    info "Save the planning output to: feature_plan.md"
}

# Generate feature plan using Claude
generate_feature_plan() {
    local goal="$1"
    log "Generating feature plan with Claude..."
    
    # Check if Claude CLI is available
    if ! command -v claude &> /dev/null; then
        warn "Claude CLI not found. Creating manual planning template."
        create_manual_plan_template "$goal"
        return 1
    fi
    
    # Generate plan using Claude
    claude --file "$PROJECT_ROOT/planning_prompt.md" > "$PROJECT_ROOT/feature_plan.md" 2>/dev/null || {
        warn "Failed to generate plan with Claude CLI. Creating manual template."
        create_manual_plan_template "$goal"
        return 1
    }
    
    log "Feature plan generated: feature_plan.md"
    return 0
}

# Create manual planning template
create_manual_plan_template() {
    local goal="$1"
    cat > "$PROJECT_ROOT/feature_plan.md" << EOF
# Feature Plan: $goal

## Slice 1: Basic Structure Setup
**Description:** Set up basic journaling data models and service structure
**Files:** lib/models/journal_entry.dart, lib/services/journal_service.dart
**Tests:** Unit tests for models and service
**Success:** Models can be instantiated and service can manage entries

## Slice 2: Basic UI Components
**Description:** Create basic journal entry list and entry widget
**Files:** lib/widgets/journal_entry_widget.dart, lib/widgets/journal_list.dart
**Tests:** Widget tests for components
**Success:** UI components render correctly

## Slice 3: Journal List Screen
**Description:** Create screen to display list of journal entries
**Files:** lib/screens/journal_list_screen.dart
**Tests:** Integration test for screen navigation
**Success:** Screen displays and navigates properly

## Slice 4: Add Entry Functionality
**Description:** Add ability to create new journal entries
**Files:** lib/screens/add_journal_entry_screen.dart, update journal_service.dart
**Tests:** Test entry creation and persistence
**Success:** Users can add new entries

## Slice 5: Entry Detail View
**Description:** View and edit individual journal entries
**Files:** lib/screens/journal_detail_screen.dart
**Tests:** Test detail view and editing
**Success:** Entries can be viewed and edited

## Slice 6: Data Persistence
**Description:** Implement local storage for journal entries
**Files:** Update journal_service.dart with SQLite/SharedPreferences
**Tests:** Test data persistence across app restarts
**Success:** Data persists between sessions

## Slice 7: Polish and Refinement
**Description:** Add search, filtering, and UI polish
**Files:** Update existing screens with enhanced features
**Tests:** End-to-end testing
**Success:** Full journaling functionality is polished and tested
EOF
    
    log "Manual planning template created: feature_plan.md"
}

# Execute a development slice
execute_slice() {
    local slice_num="$1"
    local max_slices="$2"
    
    log "Executing slice $slice_num of $max_slices"
    
    # Read the feature plan
    if [[ ! -f "$PROJECT_ROOT/feature_plan.md" ]]; then
        error "Feature plan not found. Run planning first."
        return 1
    fi
    
    # Create slice-specific prompt
    cat > "$PROJECT_ROOT/slice_prompt.md" << EOF
# Development Slice Execution

## Current Slice
Slice $slice_num of $max_slices

## Feature Plan Context
$(cat "$PROJECT_ROOT/feature_plan.md")

## Current Project State
$(find lib -name "*.dart" -type f | head -20 | xargs -I {} echo "- {}")

## Instructions
Based on the feature plan above, implement Slice $slice_num. Focus only on this slice and:

1. Create or modify the files mentioned for this slice
2. Follow Flutter best practices
3. Include appropriate error handling
4. Make the code testable
5. Add comments for complex logic

## Code Generation Request
Please generate the code for Slice $slice_num, showing:
- Complete file contents for new files
- Modifications for existing files (show before/after or clear instructions)
- Any additional dependencies needed in pubspec.yaml

EOF

    info "Slice prompt created for slice $slice_num"
    info "Next: Use Claude to generate code for this slice"
    info "Run: claude --file slice_prompt.md"
    
    # Wait for user input to continue
    read -p "Press Enter after implementing the slice with Claude..."
    
    return 0
}

# Run tests
run_tests() {
    log "Running tests..."
    
    cd "$PROJECT_ROOT"
    
    # Get dependencies first
    flutter pub get || {
        error "Failed to get Flutter dependencies"
        return 1
    }
    
    # Run Flutter analyze
    log "Running Flutter analyze..."
    flutter analyze || {
        warn "Flutter analyze found issues"
    }
    
    # Run unit tests
    log "Running unit tests..."
    flutter test || {
        warn "Some unit tests failed"
    }
    
    # Run integration tests if they exist
    if [[ -d "integration_test" ]] && [[ $(find integration_test -name "*.dart" | wc -l) -gt 0 ]]; then
        log "Running integration tests..."
        flutter test integration_test/ || {
            warn "Some integration tests failed"
        }
    fi
    
    log "Test execution completed"
}

# Commit changes
commit_changes() {
    local slice_num="$1"
    local message="$2"
    
    log "Committing changes for slice $slice_num"
    
    cd "$PROJECT_ROOT"
    
    # Add all changes
    git add .
    
    # Check if there are changes to commit
    if git diff --cached --quiet; then
        warn "No changes to commit for slice $slice_num"
        return 0
    fi
    
    # Commit with descriptive message
    local commit_message="feat: implement slice $slice_num - $message

Auto-generated commit from auto_cycle.sh
Slice $slice_num implementation includes:
- $message

[auto-cycle]"
    
    git commit -m "$commit_message" || {
        error "Failed to commit changes"
        return 1
    }
    
    log "Changes committed for slice $slice_num"
}

# Check if implementation is complete
check_completion() {
    log "Checking implementation completion..."
    
    # Basic checks
    local flutter_check=0
    local test_check=0
    
    # Check if Flutter app compiles
    cd "$PROJECT_ROOT"
    if flutter build apk --debug --target-platform android-arm64; then
        flutter_check=1
        log "Flutter app compiles successfully"
    else
        warn "Flutter app has compilation issues"
    fi
    
    # Check if tests pass
    if flutter test --coverage 2>/dev/null; then
        test_check=1
        log "Tests are passing"
    else
        warn "Some tests are failing"
    fi
    
    # Overall completion assessment
    if [[ $flutter_check -eq 1 && $test_check -eq 1 ]]; then
        log "Implementation appears complete and functional"
        return 0
    else
        warn "Implementation may need more work"
        return 1
    fi
}

# Generate final documentation
generate_documentation() {
    local goal="$1"
    
    log "Generating final documentation..."
    
    cat > "$PROJECT_ROOT/IMPLEMENTATION_LOG.md" << EOF
# Implementation Log: $goal

**Generated:** $(date '+%Y-%m-%d %H:%M:%S')
**Branch:** $(git branch --show-current)
**Commits:** $(git rev-list --count HEAD ^main 2>/dev/null || git rev-list --count HEAD ^master 2>/dev/null || echo "Unknown")

## Overview
This document tracks the automated implementation of: $goal

## Implementation Summary
$(cat "$PROJECT_ROOT/feature_plan.md" 2>/dev/null || echo "Feature plan not available")

## Files Modified/Created
$(git diff --name-only HEAD~$(git rev-list --count HEAD ^main 2>/dev/null || git rev-list --count HEAD ^master 2>/dev/null || echo "1") HEAD 2>/dev/null | sort || echo "Could not determine changed files")

## Test Results
- Flutter Analyze: $(flutter analyze &>/dev/null && echo "✅ Passed" || echo "❌ Failed")
- Unit Tests: $(flutter test &>/dev/null && echo "✅ Passed" || echo "❌ Failed") 
- Build Test: $(flutter build apk --debug &>/dev/null && echo "✅ Passed" || echo "❌ Failed")

## Next Steps
1. Review implementation manually
2. Test functionality end-to-end  
3. Consider merging feature branch
4. Plan next development cycle

## Auto Cycle Log
$(tail -50 "$LOG_FILE" 2>/dev/null || echo "Log not available")
EOF

    log "Implementation log created: IMPLEMENTATION_LOG.md"
}

# Main execution function
main() {
    local goal="${1:-}"
    
    if [[ -z "$goal" ]]; then
        error "Usage: $0 \"description of goal/feature\""
        error "Example: $0 \"build my journaling app\""
        exit 1
    fi
    
    # Initialize
    GOAL="$goal"
    BRANCH_NAME="$FEATURE_BRANCH_PREFIX-$(date +%Y%m%d-%H%M%S)"
    
    init_logging
    
    # Pre-flight checks
    check_prerequisites
    create_feature_branch "$BRANCH_NAME"
    
    # Planning phase
    log "=== PLANNING PHASE ==="
    plan_feature "$goal"
    
    # Attempt to generate plan automatically
    if ! generate_feature_plan "$goal"; then
        info "Manual planning required. Please:"
        info "1. Review and edit: $PROJECT_ROOT/feature_plan.md"
        info "2. Break down the goal into implementable slices"
        read -p "Press Enter when planning is complete..."
    fi
    
    # Implementation phase
    log "=== IMPLEMENTATION PHASE ==="
    
    local slice_num=1
    local continue_implementation=true
    
    while [[ $slice_num -le $MAX_ITERATIONS && $continue_implementation == true ]]; do
        log "Starting slice $slice_num"
        
        # Execute slice
        if execute_slice "$slice_num" "$MAX_ITERATIONS"; then
            # Run tests
            run_tests
            
            # Commit changes
            commit_changes "$slice_num" "Slice $slice_num implementation"
            
            # Check if we should continue
            echo -e "\n${YELLOW}Slice $slice_num completed.${NC}"
            echo "Options:"
            echo "1. Continue to next slice"
            echo "2. Stop here (implementation complete)"
            echo "3. Skip to completion check"
            
            read -p "Choose option (1/2/3): " choice
            
            case $choice in
                1)
                    slice_num=$((slice_num + 1))
                    ;;
                2)
                    continue_implementation=false
                    ;;
                3)
                    break
                    ;;
                *)
                    info "Invalid choice, continuing to next slice"
                    slice_num=$((slice_num + 1))
                    ;;
            esac
        else
            warn "Slice $slice_num had issues, but continuing"
            slice_num=$((slice_num + 1))
        fi
    done
    
    # Completion phase
    log "=== COMPLETION PHASE ==="
    check_completion
    generate_documentation "$goal"
    
    # Final summary
    log "=== AUTO CYCLE COMPLETE ==="
    info "Goal: $goal"
    info "Branch: $BRANCH_NAME"
    info "Slices completed: $((slice_num - 1))"
    info "Documentation: IMPLEMENTATION_LOG.md"
    info "Log file: $LOG_FILE"
    
    echo -e "\n${GREEN}Auto cycle completed!${NC}"
    echo "Next steps:"
    echo "1. Review implementation: git log --oneline"
    echo "2. Test manually: flutter run"
    echo "3. Create PR: git push origin $BRANCH_NAME"
    echo "4. Check documentation: cat IMPLEMENTATION_LOG.md"
}

# Handle script interruption
cleanup() {
    log "Auto cycle interrupted by user"
    log "Current branch: $(git branch --show-current)"
    log "To resume, checkout the feature branch and continue manually"
    exit 130
}

trap cleanup SIGINT SIGTERM

# Run main function with all arguments
main "$@"