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
#include <mach/mach.h>
#include <mach/vm_map.h>

bool running = true;
bool isCoinPatchApplied = false;
bool lastToggleState = false;
bool threadIsRunning = false;
const char* statusMessage = "Thread not started";
int lastErrno = 0;
char debugBuffer[256] = {0};  // For displaying debug info in menu

namespace offsets {
    // The coins aren't at a static offset!
    // Assembly shows: ldr w8, [x20, #0x50] then str w8, [x20, #0x50]
    // x20 is a runtime pointer, 0x50 is offset within the structure
    
    // Instead, we patch the "add w8, w8, w19" instruction (at 0x3121ab0)
    // to "mov w8, #999999" so coins are always 999999
    
    // Location of the "add w8, w8, w19" instruction to patch
    constexpr uintptr_t OFFSET_BulletHeroesCoin = 0x3121ab0;
    
    // Original: add w8, w8, w19
    // ARM64 encoding of "add w8, w8, w19": 0x12635108
    constexpr uint32_t ORIGINAL_BYTES = 0x12635108;
    
    // New: mov w8, #999999 (requires special encoding)
    // mov w8, #0x000F423F (999999 in hex)
    // We'll use: 0x528F003F (movz w8, #0x7C1F) then add more
    // Actually, let's use a simpler approach: just write 0 to always give coins
    // mov w8, #0 = 0x52800008
    constexpr uint32_t PATCH_BYTES = 0x52800008;  // mov w8, #0
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
        usleep(5000);  // 5ms = write every ~5ms (outpaces game updates)

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
            if (BaseAddr == 0) {
                statusMessage = "Module not found!";
                snprintf(debugBuffer, sizeof(debugBuffer), "Error: UnityFramework not found");
                continue;
            }
            
            // Instead of patching a STATIC offset, scan DATA section for ACTUAL coin values
            // and patch those directly (like iGameGod's watchpoint does)
            
            static uintptr_t coinStorageAddr = 0;
            
            // First time: search for coin value
            if (coinStorageAddr == 0) {
                // Search in DATA section (usually after code section, around offset 0x4000000+)
                uintptr_t searchStart = BaseAddr + 0x3E00000;
                uintptr_t searchEnd = BaseAddr + 0x4200000;
                
                // Look for a value around current coins (scan for values 0-10million)
                @try {
                    for (uintptr_t addr = searchStart; addr < searchEnd; addr += 4) {
                        uint32_t value = *(uint32_t*)addr;
                        // Current coins should be a reasonable number
                        if (value > 100 && value < 1000000 && value % 10 != 0) {
                            // Found potential coin location
                            coinStorageAddr = addr;
                            os_log(OS_LOG_DEFAULT, "KTemp: Found coin at 0x%lx = %u", addr, value);
                            break;
                        }
                    }
                } @catch (NSException *e) {
                    // Search failed
                }
            }
            
            // Patch the found coin address
            if (coinStorageAddr != 0) {
                @try {
                    uint32_t currentValue = *(uint32_t*)coinStorageAddr;
                    uint32_t* ptr = (uint32_t*)coinStorageAddr;
                    *ptr = 999999;
                    uint32_t afterValue = *(uint32_t*)coinStorageAddr;
                    
                    snprintf(debugBuffer, sizeof(debugBuffer),
                        "Coin addr: 0x%lx\nBefore: %u\nAfter: %u\n%s",
                        coinStorageAddr & 0xFFFFFFFF,
                        currentValue,
                        afterValue,
                        (afterValue == 999999) ? "✓ Locked!" : "✗ Still changing");
                    
                    statusMessage = (afterValue == 999999) ? "Coins Locked!" : "Trying lock...";
                    isCoinPatchApplied = true;
                } @catch (NSException *e) {
                    statusMessage = "Write failed!";
                }
            } else {
                snprintf(debugBuffer, sizeof(debugBuffer), "Scanning for coins...");
                statusMessage = "Searching...";
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
                    size_t pageSize = sysconf(_SC_PAGE_SIZE);
                    uintptr_t pageStart = target & ~(pageSize - 1);
                    size_t protectSize = pageSize;
                    
                    @try {
                        // Make page writable
                        vm_protect(mach_task_self(), pageStart, protectSize, FALSE, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_EXECUTE);
                        
                        // Restore original instruction
                        uint32_t* targetPtr = (uint32_t*)target;
                        *targetPtr = ORIGINAL_BYTES;
                        
                        // Flush caches
                        __builtin_arm_dmb(0xB);
                        __builtin_arm_isb(0xF);
                        
                        // Restore protection
                        vm_protect(mach_task_self(), pageStart, protectSize, FALSE, VM_PROT_READ | VM_PROT_EXECUTE);
                        
                        os_log(OS_LOG_DEFAULT, "KTemp: Instruction reverted!");
                        statusMessage = "Patch Reverted";
                        isCoinPatchApplied = false;
                    } @catch (NSException *e) {
                        statusMessage = "Revert failed!";
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
