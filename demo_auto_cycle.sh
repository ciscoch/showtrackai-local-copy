#!/bin/bash

# demo_auto_cycle.sh - Demo script showing auto_cycle.sh usage

set -euo pipefail

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}Auto Cycle Demo${NC}"
echo "==============="
echo ""
echo "This script demonstrates how to use auto_cycle.sh for automated development."
echo ""

# Show current status
echo -e "${GREEN}Current Project Status:${NC}"
echo "Branch: $(git branch --show-current)"
echo "Flutter files: $(find lib -name "*.dart" | wc -l)"
echo "Test files: $(find test -name "*_test.dart" 2>/dev/null | wc -l)"
echo ""

echo -e "${GREEN}Example Usage:${NC}"
echo ""
echo "1. Basic journaling app:"
echo "   ./auto_cycle.sh \"build my journaling app\""
echo ""
echo "2. Add specific feature:"
echo "   ./auto_cycle.sh \"add user authentication with email\""
echo ""
echo "3. Enhance existing functionality:"
echo "   ./auto_cycle.sh \"add search and filtering to journal entries\""
echo ""

echo -e "${GREEN}What auto_cycle.sh will do:${NC}"
echo ""
echo "Planning Phase:"
echo "  ✓ Create feature plan with 5-7 implementation slices"
echo "  ✓ Generate planning_prompt.md for Claude"
echo "  ✓ Create feature_plan.md with roadmap"
echo ""
echo "Implementation Phase:"
echo "  ✓ Create feature branch automatically"
echo "  ✓ Generate code slice by slice using Claude"
echo "  ✓ Run flutter analyze and flutter test after each slice"
echo "  ✓ Commit changes with descriptive messages"
echo "  ✓ Allow manual review and testing at each step"
echo ""
echo "Completion Phase:"
echo "  ✓ Final compilation and test verification"
echo "  ✓ Generate IMPLEMENTATION_LOG.md with complete summary"
echo "  ✓ Provide next steps for manual review and PR creation"
echo ""

echo -e "${YELLOW}Ready to try it?${NC}"
echo ""
echo "Run: ./auto_cycle.sh \"build my journaling app\""
echo ""
echo "Or validate your setup first:"
echo "Run: ./validate_setup.sh"
echo ""

echo -e "${GREEN}Tips for success:${NC}"
echo "• Use descriptive goal statements"
echo "• Review each generated slice before continuing"
echo "• Test manually when prompted"
echo "• Don't skip failing tests"
echo "• The script is safe - it never pushes automatically"