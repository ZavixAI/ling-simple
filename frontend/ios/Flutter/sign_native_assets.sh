#!/bin/sh

set -eu

APP_FRAMEWORKS_DIR="${TARGET_BUILD_DIR}/${WRAPPER_NAME}/Frameworks"

write_output_stamp() {
  if [ -n "${SCRIPT_OUTPUT_FILE_0:-}" ]; then
    mkdir -p "$(dirname "$SCRIPT_OUTPUT_FILE_0")"
    : > "$SCRIPT_OUTPUT_FILE_0"
  fi
}

if [ ! -d "$APP_FRAMEWORKS_DIR" ]; then
  write_output_stamp
  exit 0
fi

can_code_sign=1
if [ -z "${EXPANDED_CODE_SIGN_IDENTITY:-}" ]; then
  echo "Skipping Flutter native asset re-sign because EXPANDED_CODE_SIGN_IDENTITY is empty."
  can_code_sign=0
fi

find "$APP_FRAMEWORKS_DIR" -maxdepth 1 -type d -name "*.framework" | while IFS= read -r framework_path; do
  if [ "$can_code_sign" -ne 1 ]; then
    continue
  fi

  sign_info="$(/usr/bin/codesign -dvv "$framework_path" 2>&1 || true)"

  echo "$sign_info" | /usr/bin/grep -q "Identifier=io.flutter.flutter.native-assets." || continue

  framework_name="$(/usr/bin/basename "$framework_path")"
  echo "Re-signing Flutter native asset framework: $framework_name"

  if [ "${CONFIGURATION:-}" = "Release" ]; then
    /usr/bin/codesign \
      --force \
      --sign "$EXPANDED_CODE_SIGN_IDENTITY" \
      --preserve-metadata=identifier,flags \
      "$framework_path"
  else
    /usr/bin/codesign \
      --force \
      --sign "$EXPANDED_CODE_SIGN_IDENTITY" \
      --timestamp=none \
      --preserve-metadata=identifier,flags \
      "$framework_path"
  fi
done

write_output_stamp
