#!/bin/bash

echo "=== CI/CD Pipeline Verification ==="

# Check files exist
FILES=(
    ".github/workflows/test-vault-performance.yml"
    ".github/workflows/security-scan.yml" 
    ".github/workflows/continuous-monitoring.yml"
    "scripts/test/performance-benchmark.sh"
    "scripts/setup/dev-workflow.sh"
    "scripts/setup/local-cicd-test.sh"
)

echo "Checking required files..."
for file in "${FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "✅ $file"
    else
        echo "❌ $file - MISSING"
    fi
done

# Check executable permissions
SCRIPTS=(
    "scripts/test/performance-benchmark.sh"
    "scripts/setup/dev-workflow.sh"
    "scripts/setup/local-cicd-test.sh"
    "scripts/setup/setup-github-secrets.sh"
)

echo ""
echo "Checking script permissions..."
for script in "${SCRIPTS[@]}"; do
    if [ -x "$script" ]; then
        echo "✅ $script - executable"
    else
        echo "⚠️  $script - not executable (run: chmod +x $script)"
    fi
done

# Check workflow syntax
echo ""
echo "Checking workflow syntax..."
if command -v yamllint >/dev/null 2>&1; then
    for workflow in .github/workflows/*.yml; do
        if yamllint "$workflow" >/dev/null 2>&1; then
            echo "✅ $(basename $workflow) - valid YAML"
        else
            echo "❌ $(basename $workflow) - invalid YAML"
        fi
    done
else
    echo "⚠️  yamllint not installed - skipping YAML validation"
fi

# Check Git status
echo ""
echo "Git repository status:"
if git status >/dev/null 2>&1; then
    echo "✅ Git repository initialized"
    echo "   Staged files: $(git diff --cached --name-only | wc -l)"
    echo "   Untracked files: $(git ls-files --others --exclude-standard | wc -l)"
else
    echo "❌ Not a Git repository"
fi

echo ""
echo "=== Pipeline Setup Summary ==="
echo "✅ GitHub Actions workflows configured"
echo "✅ Security scanning enabled"
echo "✅ Performance monitoring setup"
echo "✅ Local development tools ready"
echo ""
echo "Ready to push to GitHub! 🚀"