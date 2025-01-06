#!/bin/bash

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Source the main script
source "${DIR}"/../src/common.sh

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Mock functions and commands
setup_mocks() {
    which() { echo "/usr/bin/$1"; }
    export -f which

    cp() { echo "Copying $1 to $2"; }
    export -f cp

    chmod() { echo "Setting permissions $1 on $2"; }
    export -f chmod

    chroot() { echo "Executing chroot with: $@"; }
    export -f chroot

    grep() { 
        if [[ "$3" == "/etc/os-release" ]] && [[ "$MOCK_OS" == "gentoo" ]]; then
            return 0
        fi
        return 1
    }
    export -f grep

    emerge() { echo "Emerging qemu"; }
    export -f emerge

    realpath() { echo "/current/path"; }
    export -f realpath
}

# Define test matrix
declare -A test_matrix=(
    # x86_64 host
    ["x86_64:armv7l:gentoo"]="gentoo"
    ["x86_64:armv7l:ubuntu"]="normal non-arm qemu"
    ["x86_64:armhf:gentoo"]="gentoo"
    ["x86_64:armhf:ubuntu"]="normal non-arm qemu"
    ["x86_64:aarch64:gentoo"]="aarch64"
    ["x86_64:aarch64:ubuntu"]="aarch64"
    ["x86_64:arm64:gentoo"]="aarch64"
    ["x86_64:arm64:ubuntu"]="aarch64"
    
    # armv7l host
    ["armv7l:armv7l:gentoo"]="not using qemu"
    ["armv7l:armv7l:ubuntu"]="not using qemu"
    ["armv7l:armhf:gentoo"]="not using qemu"
    ["armv7l:armhf:ubuntu"]="not using qemu"
    ["armv7l:aarch64:gentoo"]="not using qemu"
    ["armv7l:aarch64:ubuntu"]="not using qemu"
    ["armv7l:arm64:gentoo"]="not using qemu"
    ["armv7l:arm64:ubuntu"]="not using qemu"
    
    # aarch64 host
    # ["aarch64:armv7l:gentoo"]="not using qemu"
    ["aarch64:armv7l:ubuntu"]="using qemu-arm-static"
    # ["aarch64:armhf:gentoo"]="not using qemu"
    ["aarch64:armhf:ubuntu"]="using qemu-arm-static"
    ["aarch64:aarch64:gentoo"]="not using qemu"
    ["aarch64:aarch64:ubuntu"]="not using qemu"
    ["aarch64:arm64:gentoo"]="not using qemu"
    ["aarch64:arm64:ubuntu"]="not using qemu"
)

# Print test header
print_test_header() {
    local test_name="$1"
    echo
    echo -e "${BLUE}════════════════════════════════════════════════════════════════════════════════"
    echo "TEST: $test_name"
    echo -e "════════════════════════════════════════════════════════════════════════════════${NC}"
}

# Print test result
print_test_result() {
    local test_name="$1"
    local is_passed="$2"
    local output="$3"
    local expected="$4"
    
    if $is_passed; then
        echo -e "${GREEN}✓ PASSED:${NC} $test_name"
    else
        echo -e "${RED}✗ FAILED:${NC} $test_name"
        echo -e "${BLUE}Expected to match:${NC} $expected"
        echo -e "${BLUE}Got:${NC} $output"
    fi
}

# Print test matrix
print_test_matrix() {
    echo -e "${BLUE}Test Matrix Configuration:${NC}"
    echo "═══════════════════════════"
    printf "%-10s %-10s %-8s | %-40s\n" "HOST" "TARGET" "OS" "EXPECTED OUTPUT"
    echo "───────────────────────────────────────────────────────────────────────"
    
    for key in "${!test_matrix[@]}"; do
        IFS=':' read -r host target os <<< "$key"
        printf "%-10s %-10s %-8s | %-40s\n" "$host" "$target" "$os" "${test_matrix[$key]}"
    done
    
    echo "───────────────────────────────────────────────────────────────────────"
    echo
}

# Run a single test case
run_test_case() {
    local host="$1"
    local target="$2"
    local os="$3"
    local test_name="Architecture Test"
    local key="${host}:${target}:${os}"
    local expected_pattern="${test_matrix[$key]}"
    
    print_test_header "$test_name"
    echo "Parameters:"
    echo "  Host Architecture: $host"
    echo "  Target Architecture: $target"
    echo "  Operating System: $os"
    echo "  Expected Pattern: $expected_pattern"
    
    MOCK_OS="$os"
    local output=$(chroot_correct_qemu "$host" "$target" 2>&1)
    local is_passed=false
    
    if [[ -n "$expected_pattern" ]] && [[ "$output" =~ $expected_pattern ]]; then
        is_passed=true
    fi

    echo -e "${BLUE}Command Output:${NC}"
    echo "$output"
    
    print_test_result "$test_name" "$is_passed" "$output" "$expected_pattern"
    
    if $is_passed; then
        return 0
    else
        return 1
    fi
}

# Test invalid inputs
test_invalid_inputs() {
    print_test_header "Invalid Input Tests"
    local invalid_tests_passed=0
    
    echo -e "${BLUE}Invalid Test Cases:${NC}"
    printf "%-20s | %-40s\n" "TEST CASE" "EXPECTED OUTPUT"
    echo "───────────────────────────────────────────────────────────────"
    printf "%-20s | %-40s\n" "Missing Arguments" "Error: Missing required arguments"
    printf "%-20s | %-40s\n" "Invalid Architecture" "Unknown arch"
    echo "───────────────────────────────────────────────────────────────"
    echo

    # Test missing arguments
    local output=$(chroot_correct_qemu "" "" 2>&1)
    local expected="Error: Missing required arguments"
    local is_passed=false
    
    echo "Testing missing arguments:"
    echo -e "${BLUE}Command Output:${NC}"
    echo "$output"
    
    if [[ "$output" =~ "$expected" ]]; then
        is_passed=true
        ((invalid_tests_passed++))
    fi
    print_test_result "Missing Arguments Test" "$is_passed" "$output" "$expected"

    # Test invalid architecture
    output=$(chroot_correct_qemu "invalid" "armv7l" 2>&1)
    expected="Unknown arch"
    is_passed=false
    
    echo "Testing invalid architecture:"
    echo -e "${BLUE}Command Output:${NC}"
    echo "$output"
    
    if [[ "$output" =~ "$expected" ]]; then
        is_passed=true
        ((invalid_tests_passed++))
    fi
    print_test_result "Invalid Architecture Test" "$is_passed" "$output" "$expected"
    
    echo "$invalid_tests_passed"
}

# Main test runner
run_tests() {
    local test_count=0
    local tests_passed=0
    local failed_tests=()

    # Print test matrix
    print_test_matrix

    # Run architecture combination tests
    echo -e "${BLUE}Running Architecture Combination Tests${NC}"
    for key in "${!test_matrix[@]}"; do
        IFS=':' read -r host target os <<< "$key"
        ((test_count++))
        
        if run_test_case "$host" "$target" "$os"; then
            ((tests_passed++))
        else
            failed_tests+=("$key")
        fi
    done

    # Run invalid input tests
#     echo -e "${BLUE}Running Invalid Input Tests${NC}"
#     local invalid_passed
#     invalid_passed=$(test_invalid_inputs)
#     ((test_count+=2))  # Two invalid input tests
#     ((tests_passed+=invalid_passed))

    # Print summary
    echo
    echo -e "${BLUE}Test Summary${NC}"
    echo "═══════════"
    echo "Total tests: $test_count"
    echo "Tests passed: $tests_passed"
    echo "Tests failed: $((test_count - tests_passed))"
    
    if ((${#failed_tests[@]} > 0)); then
        echo
        echo -e "${RED}Failed Tests:${NC}"
        printf '%s\n' "${failed_tests[@]}"
        return 1
    fi
    return 0
}

# Set up mocks and run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    setup_mocks
    run_tests
fi
