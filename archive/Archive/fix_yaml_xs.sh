#!/bin/bash
# Script to fix YAML::XS installation issue

echo "Fixing YAML::XS installation..."

# Install build tools if missing
echo "Installing required build tools..."
apt-get update
apt-get install -y build-essential gcc make libc6-dev

# Install libyaml development headers
echo "Installing libyaml development headers..."
apt-get install -y libyaml-dev

# Try installing via system package first (preferred)
echo "Attempting to install libyaml-libyaml-perl via system package..."
if apt-get install -y libyaml-libyaml-perl; then
    echo "✓ libyaml-libyaml-perl installed successfully via system package"
else
    echo "⚠ System package installation failed, trying cpanm..."

    # If system package fails, try cpanm with system paths
    if command -v cpanm &> /dev/null; then
        cpanm --configure-args=--with-libyaml YAML::XS
    else
        echo "Installing cpanm first..."
        curl -L https://cpanmin.us | perl - --sudo App::cpanminus
        cpanm --configure-args=--with-libyaml YAML::XS
    fi
fi

# Verify installation
echo ""
echo "Verifying YAML::XS installation..."
if perl -MYAML::XS -le 'print "YAML::XS version: $YAML::XS::VERSION"'; then
    echo "✓ YAML::XS is working correctly"
else
    echo "✗ YAML::XS installation failed"
    exit 1
fi