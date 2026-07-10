/*
IOS Theos Template Komaru
Jailed (NoJB) Mod Menu Template for iOS Games
By aq9
https://github.com/VenerableCode/iOS-Theos-ModMenuTemp-NoJB
*/

#include "BasicHacks.h"
#include "../MenuLoad/Includes.h"

bool running = true;

// Keep track of the patch state so it doesn't constantly rewrite memory
bool isSunPatchApplied = false;

namespace offsets {
    // Your relative offset (Absolute 0x1001E61A4 minus the standard base 0x100000000)
    constexpr uintptr_t OFFSET_PlantsVsZombiesSun  = 0x1E61A4;
    
    // Original bytes of the game (used to restore the game when turned off)
    // You will need to replace 0x00000000 with the original hex if you want the "OFF" switch to work perfectly.
    constexpr uint32_t ORIGINAL_BYTES              = 0x00000000; 
    
    // Your patch bytes: D5 E1 84 52 converted to Little-Endian integer format for C++
    constexpr uint32_t PATCH_BYTES                 = 0x5284E1D5; 
}

void* BasicHacks::HacksThread(void* arg)
{
    // Wait a brief moment for the game binary to completely load into memory
    usleep(500000); 
    
    // Get the dynamic base address of the running game
    uintptr_t BaseAddr = (uintptr_t)_dyld_get_image_header(0);

    while(running)
    {   
        using namespace offsets;
        usleep(100000); // Check the menu state 10 times a second (saves battery/CPU)

        // Assuming your template's UI sets a boolean variable when you click the switch.
        // Replace 'KTempVars.SunModToggle' with the actual variable name your UI layout uses.
        if (KTempVars.SunModToggle) 
        {
            if (!isSunPatchApplied) 
            {
                // Apply the hex patch to freeze suns at 9999
                KomaruPatch::WriteMem<uint32_t>(BaseAddr + OFFSET_PlantsVsZombiesSun, PATCH_BYTES);
                isSunPatchApplied = true;
            }
        } 
        else 
        {
            if (isSunPatchApplied) 
            {
                // Restore the original game bytes when the mod menu switch is turned OFF
                KomaruPatch::WriteMem<uint32_t>(BaseAddr + OFFSET_PlantsVsZombiesSun, ORIGINAL_BYTES);
                isSunPatchApplied = false;
            }
        }
    } 
    return NULL; 
}

void BasicHacks::Initialize()
{
    pthread_t BasicHacksThread;
    pthread_create(&BasicHacksThread, nullptr, HacksThread, nullptr);
}
