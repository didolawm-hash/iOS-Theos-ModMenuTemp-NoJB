/*
IOS Theos Template Komaru
Jailed (NoJB) Mod Menu Template for iOS Games
*/

#include "BasicHacks.h"
#include "../MenuLoad/Includes.h"
#include <mach-o/dyld.h>
#include <sys/mman.h>
#include <unistd.h>
#include <os/log.h>
#include <errno.h>

bool running = true;
bool isCoinPatchApplied = false;
bool lastToggleState = false;
bool threadIsRunning = false;
const char* statusMessage = "Thread not started";
int lastErrno = 0;
char debugBuffer[256] = {0};  // For displaying debug info in menu

namespace offsets {
    // The original offset works in iGameGod but not in our dylib
    // Try multiple nearby offsets to find actual coin storage
    constexpr uintptr_t OFFSET_TRY_0 = 0x3121AB0;  // Original
    constexpr uintptr_t OFFSET_TRY_1 = 0x3121AB0 - 0x10;
    constexpr uintptr_t OFFSET_TRY_2 = 0x3121AB0 - 0x8;
    constexpr uintptr_t OFFSET_TRY_3 = 0x3121AB0 - 0x4;
    constexpr uintptr_t OFFSET_TRY_4 = 0x3121AB0 + 0x4;
    constexpr uintptr_t OFFSET_TRY_5 = 0x3121AB0 + 0x8;
    constexpr uintptr_t OFFSET_TRY_6 = 0x3121AB0 + 0x10;
    
    // Current offset being tested (change this when testing)
    constexpr uintptr_t OFFSET_BulletHeroesCoin = OFFSET_TRY_1;  // Testing -0x10
    
    // Original bytes (clean game value)
    constexpr uint32_t ORIGINAL_BYTES           = 0x00000000; 
    
    // 999999 in hex = 0x000F423F
    constexpr uint32_t PATCH_BYTES              = 999999;  // Will write 999999 directly
}

void* BasicHacks::HacksThread(void* arg)
{
    threadIsRunning = true;
    statusMessage = "Thread running, waiting...";
    os_log(OS_LOG_DEFAULT, "KTemp: HacksThread started!");
    sleep(5); // Allow game to load

    while(running)
    {   
        using namespace offsets;
        usleep(100000);

        // Get base address each iteration in case of ASLR
        uintptr_t BaseAddr = (uintptr_t)_dyld_get_image_header(0);
        uintptr_t target = BaseAddr + OFFSET_BulletHeroesCoin;
        size_t pageSize = sysconf(_SC_PAGE_SIZE);
        uintptr_t pageStart = target & ~(pageSize - 1);
        
        // Log toggle state change only when it changes
        if (KTempVars.SunModToggle != lastToggleState) {
            os_log(OS_LOG_DEFAULT, "KTemp: Toggle state changed to %d", KTempVars.SunModToggle);
            lastToggleState = KTempVars.SunModToggle;
        }

        if (KTempVars.SunModToggle)
        {
            // Continuously apply patch - don't just apply once
            uintptr_t BaseAddr = (uintptr_t)_dyld_get_image_header(0);
            uintptr_t target = BaseAddr + OFFSET_BulletHeroesCoin;
            
            // Always read current value
            uint32_t currentValue = *(uint32_t*)target;
            
            // Apply patch
            uint32_t* targetPtr = (uint32_t*)target;
            *targetPtr = PATCH_BYTES;
            
            // Flush any caches
            __builtin_arm_dmb(0xB);
            
            // Read back what we wrote
            uint32_t readBack = *(uint32_t*)target;
            
            // Update debug buffer for menu display
            snprintf(debugBuffer, sizeof(debugBuffer), 
                "Base: 0x%lx\nTarget: 0x%lx\nBefore: 0x%08x\nAfter: 0x%08x\n%s",
                BaseAddr & 0xFFFFFFFF,  // Show lower 32 bits
                target & 0xFFFFFFFF,
                currentValue,
                readBack,
                (readBack == PATCH_BYTES) ? "✓ SUCCESS" : "✗ MISMATCH");
            
            if (readBack == PATCH_BYTES) {
                statusMessage = "Patch Active!";
                isCoinPatchApplied = true;
            } else {
                statusMessage = "Patch FAILED!";
            }
        } 
        else 
        {
            if (isCoinPatchApplied) 
            {
                statusMessage = "Reverting patch...";
                
                uintptr_t BaseAddr = (uintptr_t)_dyld_get_image_header(0);
                uintptr_t target = BaseAddr + OFFSET_BulletHeroesCoin;
                
                os_log(OS_LOG_DEFAULT, "KTemp: Toggle OFF - Reverting patch");

                uint32_t* targetPtr = (uint32_t*)target;
                *targetPtr = ORIGINAL_BYTES;  // Direct write
                
                // Flush any caches
                __builtin_arm_dmb(0xB);  // Data memory barrier
                
                uint32_t newValue = *(uint32_t*)target;
                os_log(OS_LOG_DEFAULT, "KTemp: ✓ Patch reverted! New value: 0x%08x", newValue);
                statusMessage = "Patch Inactive";
                isCoinPatchApplied = false;
            } else {
                statusMessage = "Patch Inactive";
            }
        }
    } 
    threadIsRunning = false;
    return NULL; 
}

void BasicHacks::Initialize()
{
    os_log(OS_LOG_DEFAULT, "KTemp: BasicHacks::Initialize() called!");
    pthread_t BasicHacksThread;
    int result = pthread_create(&BasicHacksThread, nullptr, HacksThread, nullptr);
    if (result == 0) {
        os_log(OS_LOG_DEFAULT, "KTemp: Hack thread created successfully!");
    } else {
        os_log(OS_LOG_DEFAULT, "KTemp: FAILED to create hack thread! Error: %d", result);
    }
}

bool BasicHacks::GetPatchStatus()
{
    return isCoinPatchApplied;
}

bool BasicHacks::IsThreadRunning()
{
    return threadIsRunning;
}

const char* BasicHacks::GetStatusMessage()
{
    return statusMessage;
}

const char* BasicHacks::GetDebugInfo()
{
    return debugBuffer;
}
