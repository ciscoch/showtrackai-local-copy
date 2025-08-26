#!/bin/bash

# validate_setup.sh - Validate environment for auto_cycle.sh

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "Validating environment for auto_cycle.sh..."
echo "============================================"

# Check Flutter
if command -v flutter &> /dev/null; then
    echo -e "${GREEN}✅ Flutter CLI found${NC}"
    flutter --version | head -1
else
    echo -e "${RED}❌ Flutter CLI not found${NC}"
    exit 1
fi

# Check Git
if command -v git &> /dev/null; then
    echo -e "${GREEN}✅ Git found${NC}"
    git --version
else
    echo -e "${RED}❌ Git not found${NC}"
    exit 1
fi

# Check if in Flutter project
if [[ -f "pubspec.yaml" ]]; then
    echo -e "${GREEN}✅ Flutter project detected${NC}"
    echo "Project: $(grep '^name:' pubspec.yaml | cut -d' ' -f2)"
else
    echo -e "${RED}❌ Not a Flutter project (no pubspec.yaml)${NC}"
    exit 1
fi

# Check Git repository
if [[ -d ".git" ]]; then
    echo -e "${GREEN}✅ Git repository initialized${NC}"
    echo "Branch: $(git branch --show-current)"
else
    echo -e "${RED}❌ Git repository not initialized${NC}"
    exit 1
fi

# Check Claude commands
if [[ -f ".claude/commands/generate.md" ]]; then
    echo -e "${GREEN}✅ Claude generate command found${NC}"
else
    echo -e "${RED}❌ Claude generate command not found${NC}"
    echo "Expected: .claude/commands/generate.md"
    exit 1
fi

# Check Claude CLI (optional)
if command -v claude &> /dev/null; then
    echo -e "${GREEN}✅ Claude CLI found (automatic planning enabled)${NC}"
    claude --version 2>/dev/null || echo "Claude CLI found but version unknown"
else
    echo -e "${YELLOW}⚠️  Claude CLI not found (manual planning will be used)${NC}"
fi

# Test Flutter commands
echo ""
echo "Testing Flutter functionality..."
echo "==============================="

# Test pub get
if flutter pub get &>/dev/null; then
    echo -e "${GREEN}✅ Flutter pub get works${NC}"
else
    echo -e "${RED}❌ Flutter pub get failed${NC}"
    exit 1
fi

# Test analyze
if flutter analyze --no-pub &>/dev/null; then
    echo -e "${GREEN}✅ Flutter analyze works${NC}"
else
    echo -e "${YELLOW}⚠️  Flutter analyze found issues${NC}"
fi

# Test basic compilation for web (since Android/iOS tools missing)
echo "Testing compilation (web target)..."
if timeout 60 flutter build web --no-pub &>/dev/null; then
    echo -e "${GREEN}✅ Flutter compilation works${NC}"
else
    echo -e "${YELLOW}⚠️  Flutter compilation had issues (may be normal)${NC}"
fi

# Check project structure
echo ""
echo "Checking project structure..."
echo "============================"

if [[ -d "lib" ]]; then
    echo -e "${GREEN}✅ lib/ directory exists${NC}"
    echo "Dart files: $(find lib -name "*.dart" | wc -l)"
else
    echo -e "${RED}❌ lib/ directory missing${NC}"
fi

if [[ -d "test" ]]; then
    echo -e "${GREEN}✅ test/ directory exists${NC}"
    echo "Test files: $(find test -name "*_test.dart" 2>/dev/null | wc -l)"
else
    echo -e "${YELLOW}⚠️  test/ directory missing (will be created as needed)${NC}"
fi

# Summary
echo ""
echo "Validation Summary"
echo "=================="
echo -e "${GREEN}✅ Environment is ready for auto_cycle.sh${NC}"
echo ""
echo "Usage:"
echo "  ./auto_cycle.sh \"build my journaling app\""
echo ""
echo "Features available:"
echo "  - Automatic feature planning"
echo "  - Code generation with Claude integration"
echo "  - Automated testing (flutter analyze, flutter test)"
echo "  - Git branch management and commits"
echo "  - Implementation documentation"