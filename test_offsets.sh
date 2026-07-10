#!/bin/bash
# Test all 7 coin offsets systematically

cd /workspaces/iOS-Theos-ModMenuTemp-NoJB/TheosMMTempKomaru

offsets=(
    "OFFSET_TRY_0  # 0x3121AB0 (original)"
    "OFFSET_TRY_1  # 0x3121AA0 (-0x10)"
    "OFFSET_TRY_2  # 0x3121AA8 (-0x8)"
    "OFFSET_TRY_3  # 0x3121AAC (-0x4)"
    "OFFSET_TRY_4  # 0x3121AB4 (+0x4)"
    "OFFSET_TRY_5  # 0x3121ABC (+0x8)"
    "OFFSET_TRY_6  # 0x3121AC0 (+0x10)"
)

for i in {0..6}; do
    echo "========================================"
    echo "Testing OFFSET_TRY_$i"
    echo "========================================"
    
    # Update the offset
    sed -i "s/constexpr uintptr_t OFFSET_BulletHeroesCoin = OFFSET_TRY_.*/constexpr uintptr_t OFFSET_BulletHeroesCoin = OFFSET_TRY_$i;/" Source/BasicHacks.mm
    
    # Rebuild
    make 2>&1 | grep -E "Linking|Signing|Error"
    
    # Commit and push
    git add Source/BasicHacks.mm
    git commit -m "Test OFFSET_TRY_$i" -q
    git push -q origin main
    
    echo "✓ Built and pushed OFFSET_TRY_$i"
    echo ""
    echo "Test on your device and tell me:"
    echo "- Do coins change to 999999?"
    echo "- What Target address shows?"
    echo ""
    read -p "Continue to next offset? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        break
    fi
done
