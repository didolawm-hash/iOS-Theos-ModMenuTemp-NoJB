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
#import <Foundation/Foundation.h>

bool running = true;
bool isCoinPatchApplied = false;
bool lastToggleState = false;
bool threadIsRunning = false;
const char* statusMessage = "Thread not started";
int lastErrno = 0;
char debugBuffer[256] = {0};  // For displaying debug info in menu

namespace offsets {
    // iGameGod showed: UnityFramework +51518132 which is 0x3121AB4
    // BUT that might be in CODE section (has "add w8, w8, w19" instruction)
    // Maybe we need to offset from the DATA section, not TEXT section
    // Let's try the EXACT offset iGameGod gave us first
    
    // 51518132 decimal = 0x3121AB4 hex
    constexpr uintptr_t OFFSET_BulletHeroesCoin = 0x3121AB4;
    
    // Original bytes (clean game value)
    constexpr uint32_t ORIGINAL_BYTES           = 0x00000000; 
    
    // Coins value
    constexpr uint32_t PATCH_BYTES              = 999999;
}
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
        uintptr_t BaseAddr = 0;
        uint32_t imageCount = _dyld_image_count();
        
        // Log modules on first toggle to help debug
        static bool logged = false;
        if (KTempVars.SunModToggle && !logged) {
            logged = true;
            os_log(OS_LOG_DEFAULT, "===== MODULE DEBUG INFO =====");
            for (uint32_t i = 0; i < imageCount && i < 30; i++) {
                const char* name = _dyld_get_image_name(i);
                if (name) {
                    uintptr_t base = (uintptr_t)_dyld_get_image_header(i);
                    os_log(OS_LOG_DEFAULT, "[%2u] %s -> 0x%lx", i, name, base);
                }
            }
        }
        
        for (uint32_t i = 0; i < imageCount; i++) {
            const char* imageName = _dyld_get_image_name(i);
            if (!imageName) continue;
            
            // Try multiple module name patterns
            if (strstr(imageName, "UnityFramework") || 
                strstr(imageName, "UnityFramework.framework") ||
                strstr(imageName, "Unity") ||
                strstr(imageName, "BulletHeroes")) {
                
                BaseAddr = (uintptr_t)_dyld_get_image_header(i);
                if (BaseAddr != 0) {
                    os_log(OS_LOG_DEFAULT, "KTemp: Found module: %s at 0x%lx", imageName, BaseAddr);
                    break;
                }
            }
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
            // BaseAddr and target already calculated above
            
            if (BaseAddr == 0) {
                statusMessage = "Module not found!";
                snprintf(debugBuffer, sizeof(debugBuffer), "Error: Can't find Unity module");
                continue;
            }
            
            // Try patching multiple nearby offsets to find which one actually affects coins
            // iGameGod showed 0x3121ab4, but the display might read from a different location
            uintptr_t offsets_to_try[] = {
                BaseAddr + 0x3121ab0,  // Original -4
                BaseAddr + 0x3121ab4,  // Main one
                BaseAddr + 0x3121ab8,  // +4
                BaseAddr + 0x3121abc,  // +8
                BaseAddr + 0x3121ac0,  // +12
            };
            
            uint32_t value = 111111;
            bool anySuccess = false;
            
            for (int i = 0; i < 5; i++) {
                @try {
                    uint32_t* ptr = (uint32_t*)offsets_to_try[i];
                    *ptr = value;
                    anySuccess = true;
                } @catch (NSException *e) {
                    // Skip this offset if it crashes
                }
            }
            
            // Now read back from the main offset for display
            @try {
                uint32_t currentValue = *(uint32_t*)(BaseAddr + 0x3121ab4);
                
                snprintf(debugBuffer, sizeof(debugBuffer), 
                    "Patching 5 offsets with 111111\nRead at +0x3121ab4: 0x%08x\n%s",
                    currentValue,
                    anySuccess ? "✓ Patches applied" : "✗ Failed");
                
                statusMessage = anySuccess ? "Multi-patch Active!" : "Patch FAILED!";
                isCoinPatchApplied = anySuccess;
            } @catch (NSException *e) {
                statusMessage = "Read crash!";
            }
        } 
        else 
        {
            if (isCoinPatchApplied) 
            {
                statusMessage = "Reverting patch...";
                
                if (BaseAddr == 0) {
                    statusMessage = "Module not found for revert!";
                } else {
                    uintptr_t target = BaseAddr + OFFSET_BulletHeroesCoin;
                    
                    os_log(OS_LOG_DEFAULT, "KTemp: Toggle OFF - Reverting patch");

                    @try {
                        uint32_t* targetPtr = (uint32_t*)target;
                        *targetPtr = ORIGINAL_BYTES;
                        
                        __builtin_arm_dmb(0xB);
                        
                        uint32_t newValue = *(uint32_t*)target;
                        os_log(OS_LOG_DEFAULT, "KTemp: ✓ Patch reverted! New value: 0x%08x", newValue);
                        statusMessage = "Patch Inactive";
                        isCoinPatchApplied = false;
                    } @catch (NSException *e) {
                        statusMessage = "Revert crash prevented!";
                    }
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
