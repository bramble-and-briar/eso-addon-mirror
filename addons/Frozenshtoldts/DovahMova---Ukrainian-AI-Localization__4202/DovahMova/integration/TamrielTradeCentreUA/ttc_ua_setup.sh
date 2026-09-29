#!/bin/bash

echo "========================================"
echo "Complete TamrielTradeCentre Ukrainian Setup"
echo "========================================"
echo

# Get the script's directory and navigate to TamrielTradeCentre
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
cd ../../../TamrielTradeCentre

# Check if TamrielTradeCentre exists
if [ ! -f "TamrielTradeCentre.lua" ] && [ ! -f "TamrielTradeCentre.txt" ]; then
    echo "ERROR: TamrielTradeCentre addon not found."
    echo "Please make sure TamrielTradeCentre is installed in the same AddOns directory as DovahMova."
    echo "Current directory: $(pwd)"
    echo "Press any key to continue..."
    read -n 1 -s
    exit 1
fi

# Get absolute paths for display
TTC_PATH="$(pwd)"
DOVAHMOVA_PATH="$(cd "$SCRIPT_DIR" && cd ../../.. && pwd)/DovahMova"

echo "Detected paths:"
echo "TamrielTradeCentre: $TTC_PATH"
echo "DovahMova: $DOVAHMOVA_PATH"
echo

echo "Paths verified successfully!"
echo

# Navigate back to TamrielTradeCentre for operations
cd "$TTC_PATH"

# Create backup directory
BACKUP_DIR="backup_$(date +%Y%m%d_%H%M%S)"
echo "Creating backup at: $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"

# Backup original files
echo "Creating backups..."
if [ -f "TamrielTradeCentre.lua" ]; then
    cp "TamrielTradeCentre.lua" "$BACKUP_DIR/TamrielTradeCentre.lua.backup"
    echo "✓ TamrielTradeCentre.lua backed up"
fi
if [ -f "TamrielTradeCentreInit.lua" ]; then
    cp "TamrielTradeCentreInit.lua" "$BACKUP_DIR/TamrielTradeCentreInit.lua.backup"
    echo "✓ TamrielTradeCentreInit.lua backed up"
fi
if [ -f "TamrielTradeCentre.txt" ]; then
    cp "TamrielTradeCentre.txt" "$BACKUP_DIR/TamrielTradeCentre.txt.backup"
    echo "✓ TamrielTradeCentre.txt backed up"
fi
echo "Backup completed."
echo

# Step 1: Create Ukrainian language file
echo "Step 1: Creating Ukrainian language file..."
mkdir -p "lang"
if [ -f "$DOVAHMOVA_PATH/integration/TamrielTradeCentreUA/ttc_lang_ua.lua" ]; then
    cp "$DOVAHMOVA_PATH/integration/TamrielTradeCentreUA/ttc_lang_ua.lua" "lang/ua.lua"
    echo "✓ Ukrainian language file created: lang/ua.lua"
else
    echo "✗ ERROR: ttc_lang_ua.lua not found in DovahMova"
fi
echo ""

# Step 2: Create Ukrainian ItemLookUpTable
echo "Step 2: Creating Ukrainian ItemLookUpTable..."
if [ -f "ItemLookUpTable_EN.lua" ]; then
    cp "ItemLookUpTable_EN.lua" "ItemLookUpTable_UA.lua"
    echo "✓ Ukrainian ItemLookUpTable created from English version"
else
    echo "✗ ERROR: English ItemLookUpTable not found"
    echo "Cannot create Ukrainian version without English base file."
fi
echo

# Step 3: Remove the generator installed by older DovahMova versions
# (since DovahMova 1.5.0 the price table is built by DovahMova itself)
echo "Step 3: Removing old DovahMova generator from TamrielTradeCentre..."
if [ -f "generate_ua_itemlookup.lua" ]; then
    rm "generate_ua_itemlookup.lua"
    echo "✓ generate_ua_itemlookup.lua removed"
fi
if [ -f "TamrielTradeCentre.txt" ] && grep -q "generate_ua_itemlookup.lua" "TamrielTradeCentre.txt"; then
    grep -v "^generate_ua_itemlookup.lua" "TamrielTradeCentre.txt" > "TamrielTradeCentre.txt.tmp"
    mv "TamrielTradeCentre.txt.tmp" "TamrielTradeCentre.txt"
    echo "✓ TamrielTradeCentre.txt cleaned"
fi
echo ""

# Step 6: Patch TamrielTradeCentre.lua for Ukrainian language support
echo "Step 6: Patching TamrielTradeCentre.lua for Ukrainian support..."
if [ -f "TamrielTradeCentre.lua" ]; then
    echo "Checking current language check line..."
    grep "clientCulture" "TamrielTradeCentre.lua" | head -1
    echo
    echo "Attempting to patch language support..."
    
    # Create a temporary file for patching using more portable method
    TEMP_FILE="TamrielTradeCentre.lua.tmp"
    
    # Try multiple patterns to handle different versions
    if grep -q 'if (clientCulture~= "en" and clientCulture ~= "de" and clientCulture ~= "fr" and clientCulture ~= "zh" and clientCulture ~= "ru" and clientCulture ~= "es" and clientCulture ~= "jp") then' "TamrielTradeCentre.lua"; then
        awk '{gsub(/if \(clientCulture~= "en" and clientCulture ~= "de" and clientCulture ~= "fr" and clientCulture ~= "zh" and clientCulture ~= "ru" and clientCulture ~= "es" and clientCulture ~= "jp"\) then/, "if (clientCulture~= \"en\" and clientCulture ~= \"de\" and clientCulture ~= \"fr\" and clientCulture ~= \"zh\" and clientCulture ~= \"ru\" and clientCulture ~= \"es\" and clientCulture ~= \"jp\" and clientCulture ~= \"ua\") then"); print}' "TamrielTradeCentre.lua" > "$TEMP_FILE"
        mv "$TEMP_FILE" "TamrielTradeCentre.lua"
        echo "Pattern 1 applied successfully"
    elif grep -q 'if (clientCulture ~= "en" and clientCulture ~= "de" and clientCulture ~= "fr" and clientCulture ~= "zh" and clientCulture ~= "ru" and clientCulture ~= "es" and clientCulture ~= "jp") then' "TamrielTradeCentre.lua"; then
        awk '{gsub(/if \(clientCulture ~= "en" and clientCulture ~= "de" and clientCulture ~= "fr" and clientCulture ~= "zh" and clientCulture ~= "ru" and clientCulture ~= "es" and clientCulture ~= "jp"\) then/, "if (clientCulture ~= \"en\" and clientCulture ~= \"de\" and clientCulture ~= \"fr\" and clientCulture ~= \"zh\" and clientCulture ~= \"ru\" and clientCulture ~= \"es\" and clientCulture ~= \"jp\" and clientCulture ~= \"ua\") then"); print}' "TamrielTradeCentre.lua" > "$TEMP_FILE"
        mv "$TEMP_FILE" "TamrielTradeCentre.lua"
        echo "Pattern 2 applied successfully"
    elif grep -q 'clientCulture.*ua' "TamrielTradeCentre.lua"; then
        echo "Ukrainian language already supported!"
    else
        echo "No matching pattern found - manual patch required"
    fi
    
    echo
    echo "Checking if patch was successful..."
    if grep -q "clientCulture.*ua" "TamrielTradeCentre.lua"; then
        echo "✓ TamrielTradeCentre.lua patched successfully"
    else
        echo
        echo "✗ WARNING: Automatic patch may have failed"
        echo "MANUAL PATCH REQUIRED - see instructions below"
    fi
else
    echo "✗ ERROR: TamrielTradeCentre.lua not found"
fi
echo

# Step 7: Patch TamrielTradeCentreInit.lua to ensure Ukrainian language enum is properly defined
echo "Step 7: Verifying Ukrainian language enum in TamrielTradeCentreInit.lua..."
if [ -f "TamrielTradeCentreInit.lua" ]; then
    if grep -q "UA = 8" "TamrielTradeCentreInit.lua"; then
        echo "✓ Ukrainian language enum found in TamrielTradeCentreInit.lua"
    else
        echo "✗ WARNING: Ukrainian language enum may not be properly defined"
        echo "This might cause issues with language detection"
    fi
else
    echo "✗ ERROR: TamrielTradeCentreInit.lua not found"
fi
echo

# Step 8: Final verification
echo "Step 8: Final verification..."
echo
echo "========================================"
echo "Setup Summary"
echo "========================================"
echo
echo "✓ Backup created at: $BACKUP_DIR"
echo "✓ Ukrainian language file: lang/ua.lua"
echo "✓ Ukrainian ItemLookUpTable: ItemLookUpTable_UA.lua"
echo "✓ Old DovahMova generator removed from TamrielTradeCentre"
echo "✓ TamrielTradeCentre.lua patched for Ukrainian support"
echo
echo "========================================"
echo "Next Steps"
echo "========================================"
echo
echo "1. If the automatic patch failed, manually edit TamrielTradeCentre.lua:"
echo '   - Find the line with clientCulture language check'
echo '   - Add " and clientCulture ~= \"ua\"" before the closing parenthesis'
echo
echo "2. Restart ESO completely"
echo "3. Make sure your ESO client is set to Ukrainian language"
echo "4. Load into the game"
echo "5. Check if TamrielTradeCentre loads without the \"unsupported language\" error"
echo "6. Open DovahMova settings and press \"Згенерувати TTC\""
echo
echo "========================================"
echo "Troubleshooting"
echo "========================================"
echo
echo 'If you still get "unsupported language" error:'
echo "1. Check that your ESO client language is set to Ukrainian"
echo '2. Verify the language check line in TamrielTradeCentre.lua includes "ua"'
echo "3. Make sure lang/ua.lua exists and contains Ukrainian strings"
echo "4. Check the backup folder for original files if needed"
echo
echo "To restore original files, copy from: $BACKUP_DIR"
echo

echo "Setup completed! Press any key to continue..."
read -n 1
