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

namespace offsets {
    // Relative static offset for Bullet Heroes
    constexpr uintptr_t OFFSET_BulletHeroesCoin = 0x3121AB0;
    
    // Original bytes (Make sure to verify these in a clean game!)
    constexpr uint32_t ORIGINAL_BYTES           = 0x00000000; 
    
    // Your patch bytes (Converted to Little-Endian)
    constexpr uint32_t PATCH_BYTES              = 0x0B133108; 
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
            
            if (!isCoinPatchApplied) {
                statusMessage = "Attempting patch...";
                
                // Log extensive debug info
                uint32_t valueBeforePatch = *(uint32_t*)target;
                os_log(OS_LOG_DEFAULT, "KTemp: Toggle ON");
                os_log(OS_LOG_DEFAULT, "KTemp:   BaseAddr:     0x%lx", BaseAddr);
                os_log(OS_LOG_DEFAULT, "KTemp:   Offset:       0x%lx", OFFSET_BulletHeroesCoin);
                os_log(OS_LOG_DEFAULT, "KTemp:   Target:       0x%lx", target);
                os_log(OS_LOG_DEFAULT, "KTemp:   Value BEFORE: 0x%08x", valueBeforePatch);
                os_log(OS_LOG_DEFAULT, "KTemp:   Will patch to: 0x%08x", PATCH_BYTES);
            }

            // Use direct memory write instead of vm_write for current process
            uint32_t* targetPtr = (uint32_t*)target;
            *targetPtr = PATCH_BYTES;  // Direct write
            
            // Flush any caches
            __builtin_arm_dmb(0xB);  // Data memory barrier
            
            // Verify write
            uint32_t readValue = *(uint32_t*)target;
            
            if (readValue == PATCH_BYTES) {
                if (!isCoinPatchApplied) {
                    os_log(OS_LOG_DEFAULT, "KTemp: ✓ Patch applied successfully! Value is now: 0x%08x", readValue);
                    statusMessage = "Patch Active!";
                    isCoinPatchApplied = true;
                }
                // Keep patching every frame to ensure it stays patched
            } else {
                os_log(OS_LOG_DEFAULT, "KTemp: ✗ Patch FAILED! Expected 0x%08x but got 0x%08x", PATCH_BYTES, readValue);
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
