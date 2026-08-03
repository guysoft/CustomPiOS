#!/bin/bash
# Shared headless-browser helpers for E2E test scripts.
# Source this file: source /test/scripts/browser-helpers.sh
#
# Provides:
#   find_headless_browser        - locate a usable Firefox/Chrome/Chromium binary
#   headless_screenshot URL OUT  - capture a screenshot, optionally retrying
#                                  until tesseract finds a regex in the page
#
# These helpers are runtime-only (executed in the e2e test container, never
# in the QEMU guest) and assume `timeout` is available. Tesseract and
# dbus-run-session are optional but used when present.

# Locate a real Firefox/Chrome/Chromium binary; skip snap stubs because they
# can't write screenshots to /tmp under confinement. Firefox is preferred
# because its --screenshot CLI is stable across releases (ESR pins a major
# version for ~12 months), avoiding Chrome 147+ --headless --screenshot
# regressions in CI containers. Chrome/Chromium remain as fallback.
# On success: sets BROWSER_PATH, prints the path, returns 0.
# On failure: returns 1 and BROWSER_PATH is empty.
find_headless_browser() {
    BROWSER_PATH=""
    local b path
    for b in firefox-esr firefox google-chrome-stable chromium chromium-browser; do
        path=$(command -v "$b" 2>/dev/null || true)
        [ -n "$path" ] || continue
        if "$path" --version 2>&1 | grep -qi "snap"; then
            continue
        fi
        BROWSER_PATH="$path"
        echo "$BROWSER_PATH"
        return 0
    done
    return 1
}

# Capture a headless screenshot of $1 to $2.
#
# Usage:
#   headless_screenshot <url> <output_png> [ocr_pattern] [attempts] [sleep_secs]
#
# Behavior:
#   - Picks a browser via find_headless_browser if BROWSER_PATH is unset.
#     Firefox is preferred; Chrome/Chromium are used as fallback.
#   - Each attempt times out after 60s. If no image is produced, or the file
#     is <= 10 KiB (typically a blank page), the attempt is rejected.
#   - When ocr_pattern is given AND `tesseract` is installed, the captured
#     image must OCR to text matching the regex (grep -Ei) for the attempt
#     to be considered a success. Otherwise any non-empty screenshot wins.
#
# Side effects:
#   - HEADLESS_OCR_TEXT contains the last OCR result (may be empty).
#   - Writes diagnostic lines to stdout, one per attempt.
#
# Returns:
#   0 if a valid screenshot was captured (and OCR matched, if requested).
#   1 if no usable browser was found, or all attempts failed.
headless_screenshot() {
    local url="$1"
    local out="$2"
    local ocr_pattern="${3:-}"
    local attempts="${4:-12}"
    local sleep_secs="${5:-10}"

    HEADLESS_OCR_TEXT=""

    if [ -z "${BROWSER_PATH:-}" ]; then
        find_headless_browser >/dev/null || return 1
    fi

    local dbus_prefix=""
    if command -v dbus-run-session >/dev/null 2>&1; then
        dbus_prefix="dbus-run-session --"
    fi

    local tmp_png="/tmp/headless-screenshot.$$.png"
    local got_image=0
    local matched=0
    local attempt size

    local is_firefox=0
    case "$(basename "${BROWSER_PATH:-}")" in
        firefox|firefox-esr) is_firefox=1 ;;
    esac

    for attempt in $(seq 1 "$attempts"); do
        rm -f "$tmp_png"
        if [ "$is_firefox" -eq 1 ]; then
            # Firefox: --screenshot implies headless; --no-remote avoids
            # profile clashes. The path is a separate arg (not --screenshot=).
            timeout 60 $dbus_prefix "$BROWSER_PATH" --headless --no-remote \
                --screenshot "$tmp_png" --window-size=1280,720 \
                "$url" >/dev/null 2>&1 || true
        else
            timeout 60 $dbus_prefix "$BROWSER_PATH" --headless --no-sandbox --disable-gpu \
                --disable-dev-shm-usage --disable-setuid-sandbox \
                --disable-software-rasterizer --hide-scrollbars \
                --virtual-time-budget=30000 \
                --screenshot="$tmp_png" \
                --window-size=1280,720 \
                "$url" >/dev/null 2>&1 || true
        fi

        if [ ! -f "$tmp_png" ]; then
            echo "  headless_screenshot: attempt $attempt: no image produced"
            sleep "$sleep_secs"
            continue
        fi

        size=$(stat -c%s "$tmp_png" 2>/dev/null || echo 0)
        if [ "$size" -le 10000 ]; then
            echo "  headless_screenshot: attempt $attempt: image too small (${size} bytes)"
            rm -f "$tmp_png"
            sleep "$sleep_secs"
            continue
        fi

        cp "$tmp_png" "$out"
        got_image=1

        if [ -z "$ocr_pattern" ]; then
            matched=1
            break
        fi

        if command -v tesseract >/dev/null 2>&1; then
            HEADLESS_OCR_TEXT=$(tesseract "$tmp_png" stdout 2>/dev/null || echo "")
            if echo "$HEADLESS_OCR_TEXT" | grep -Eqi "$ocr_pattern"; then
                echo "  headless_screenshot: attempt $attempt: OCR matched (${size} bytes)"
                matched=1
                break
            fi
            local first_line
            first_line=$(echo "$HEADLESS_OCR_TEXT" | head -c 80)
            echo "  headless_screenshot: attempt $attempt: pattern not seen yet (OCR: ${first_line:-<empty>})"
        else
            # No OCR available: accept the first non-trivial screenshot.
            matched=1
            break
        fi

        sleep "$sleep_secs"
    done

    rm -f "$tmp_png"
    [ "$got_image" -eq 1 ] && [ "$matched" -eq 1 ]
}
