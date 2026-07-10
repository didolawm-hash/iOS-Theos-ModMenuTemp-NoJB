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
#include <string.h>

bool running = true;
bool isCoinPatchApplied = false;
bool lastToggleState = false;
bool threadIsRunning = false;
const char* statusMessage = "Thread not started";
int lastErrno = 0;
char debugBuffer[256] = {0};  // For displaying debug info in menu

namespace offsets {
    // The offset within UnityFramework module (as shown by iGameGod watchpoint)
    // iGameGod showed: UnityFramework +51518132 = 0x3121ab4
    constexpr uintptr_t OFFSET_TRY_0 = 0x3121ab4;  // Correct offset from iGameGod
    constexpr uintptr_t OFFSET_TRY_1 = 0x3121aa0;
    constexpr uintptr_t OFFSET_TRY_2 = 0x3121aa8;
    constexpr uintptr_t OFFSET_TRY_3 = 0x3121aac;
    constexpr uintptr_t OFFSET_TRY_4 = 0x3121ab8;
    constexpr uintptr_t OFFSET_TRY_5 = 0x3121abc;
    constexpr uintptr_t OFFSET_TRY_6 = 0x3121ac0;
    
    // Current offset being tested
    constexpr uintptr_t OFFSET_BulletHeroesCoin = OFFSET_TRY_0;
    
    // Original bytes (clean game value)
    constexpr uint32_t ORIGINAL_BYTES           = 0x00000000; 
    
    // 999999 for infinite coins
    constexpr uint32_t PATCH_BYTES              = 999999;
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

        // Get UnityFramework module base address (not main app!)
        uintptr_t BaseAddr = 0;
        uint32_t imageCount = _dyld_image_count();
        for (uint32_t i = 0; i < imageCount; i++) {
            const char* imageName = _dyld_get_image_name(i);
            if (imageName && strstr(imageName, "UnityFramework")) {
                BaseAddr = (uintptr_t)_dyld_get_image_header(i);
                break;
            }
        }
        
        if (BaseAddr == 0) {
            statusMessage = "UnityFramework not found!";
            continue;
        }
        
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
            uintptr_t BaseAddr = 0;
            uint32_t imageCount = _dyld_image_count();
            for (uint32_t i = 0; i < imageCount; i++) {
                const char* imageName = _dyld_get_image_name(i);
                if (imageName && strstr(imageName, "UnityFramework")) {
                    BaseAddr = (uintptr_t)_dyld_get_image_header(i);
                    break;
                }
            }
            
            if (BaseAddr == 0) {
                statusMessage = "UnityFramework not found!";
                continue;
            }
            
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
                BaseAddr & 0xFFFFFFFF,
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
                
                uintptr_t BaseAddr = 0;
                uint32_t imageCount = _dyld_image_count();
                for (uint32_t i = 0; i < imageCount; i++) {
                    const char* imageName = _dyld_get_image_name(i);
                    if (imageName && strstr(imageName, "UnityFramework")) {
                        BaseAddr = (uintptr_t)_dyld_get_image_header(i);
                        break;
                    }
                }
                
                if (BaseAddr == 0) {
                    statusMessage = "UnityFramework not found!";
                } else {
                    uintptr_t target = BaseAddr + OFFSET_BulletHeroesCoin;
                    
                    os_log(OS_LOG_DEFAULT, "KTemp: Toggle OFF - Reverting patch");

                    uint32_t* targetPtr = (uint32_t*)target;
                    *targetPtr = ORIGINAL_BYTES;
                    
                    __builtin_arm_dmb(0xB);
                    
                    uint32_t newValue = *(uint32_t*)target;
                    os_log(OS_LOG_DEFAULT, "KTemp: ✓ Patch reverted! New value: 0x%08x", newValue);
                    statusMessage = "Patch Inactive";
                    isCoinPatchApplied = false;
                }
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
