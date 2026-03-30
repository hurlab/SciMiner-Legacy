#!/bin/bash
# Debug script to test prompt reading

echo "Testing prompt reading..."
echo ""

# Test 1: Simple read
echo "Test 1: Simple read"
read -p "Enter something: " test1
echo "You entered: '$test1'"
echo ""

# Test 2: Case sensitive test
echo "Test 2: Case sensitive test"
read -p "Enter y or n: " test2
if [[ $test2 =~ ^[Yy]$ ]]; then
    echo "You entered YES (test2='$test2')"
else
    echo "You entered NO or something else (test2='$test2')"
fi
echo ""

# Test 3: Exact match test
echo "Test 3: Exact match test"
read -p "Enter 'y' or 'n': " test3
if [[ "$test3" == "y" ]] || [[ "$test3" == "Y" ]]; then
    echo "You entered YES (test3='$test3')"
else
    echo "You entered NO or something else (test3='$test3')"
fi
echo ""

# Test 4: Original prompt from script
echo "Test 4: Original prompt from script"
read -p "Do you want to run database configuration now? (y=Yes, n=Skip) [y]: " configure_db
echo "configure_db='$configure_db'"
if [[ $configure_db =~ ^[Yy]$ ]]; then
    echo "IF condition: Would run configuration"
else
    echo "IF condition: Would skip configuration"
fi