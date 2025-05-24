#!/bin/bash

echo "=== Validating GitHub Actions Workflows ==="

# Function to validate YAML syntax
validate_yaml() {
    local file=$1
    echo "Checking $file..."
    
    if command -v yq >/dev/null 2>&1; then
        if yq eval '.' "$file" >/dev/null 2>&1; then
            echo "✅ $file - Valid YAML syntax"
            return 0
        else
            echo "❌ $file - Invalid YAML syntax"
            yq eval '.' "$file" 2>&1 | head -5
            return 1
        fi
    elif command -v python3 >/dev/null 2>&1; then
        if python3 -c "import yaml; yaml.safe_load(open('$file'))" 2>/dev/null; then
            echo "✅ $file - Valid YAML syntax"
            return 0
        else
            echo "❌ $file - Invalid YAML syntax"
            python3 -c "import yaml; yaml.safe_load(open('$file'))" 2>&1 | head -5
            return 1
        fi
    else
        echo "⚠️ $file - Cannot validate (no YAML parser found)"
        return 0
    fi
}

# Install yq if not available
if ! command -v yq >/dev/null 2>&1; then
    echo "Installing yq for YAML validation..."
    if command -v snap >/dev/null 2>&1; then
        sudo snap install yq
    elif command -v pip3 >/dev/null 2>&1; then
        pip3 install yq
    else
        echo "Using Python yaml module for validation"
    fi
fi

# Validate all workflow files
WORKFLOW_DIR=".github/workflows"
if [ ! -d "$WORKFLOW_DIR" ]; then
    echo "❌ Workflow directory not found: $WORKFLOW_DIR"
    exit 1
fi

VALID_COUNT=0
TOTAL_COUNT=0

for workflow_file in "$WORKFLOW_DIR"/*.yml "$WORKFLOW_DIR"/*.yaml; do
    if [ -f "$workflow_file" ]; then
        TOTAL_COUNT=$((TOTAL_COUNT + 1))
        if validate_yaml "$workflow_file"; then
            VALID_COUNT=$((VALID_COUNT + 1))
        fi
        echo ""
    fi
done

echo "=== Validation Summary ==="
echo "Valid workflows: $VALID_COUNT/$TOTAL_COUNT"

if [ $VALID_COUNT -eq $TOTAL_COUNT ]; then
    echo "🎉 All workflows have valid YAML syntax!"
    exit 0
else
    echo "❌ Some workflows have invalid YAML syntax"
    exit 1
fi
