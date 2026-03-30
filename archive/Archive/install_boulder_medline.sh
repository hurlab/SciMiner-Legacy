#!/bin/bash
# Install Boulder::Medline module for SciMiner

echo "Installing Boulder::Medline for SciMiner..."

# Install via cpanm (preferred method)
if command -v cpanm >/dev/null 2>&1; then
    echo "Using cpanm to install Boulder::Medline..."
    cpanm --notest Boulder::Medline
else
    # Fallback to cpan
    echo "cpanm not found, using cpan to install Boulder::Medline..."
    cpan -i Boulder::Medline
fi

# Verify installation
echo ""
echo "Verifying Boulder::Medline installation..."
if perl -MBoulder::Medline -e 'print "✓ Boulder::Medline version: $Boulder::Medline::VERSION\n"'; then
    echo "✓ Boulder::Medline installed successfully!"
else
    echo "✗ Boulder::Medline installation failed"
    exit 1
fi

echo ""
echo "Running full module check..."
/home/sciminer/check_system_perl_modules.pl