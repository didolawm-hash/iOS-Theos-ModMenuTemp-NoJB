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
            
            uintptr_t target = BaseAddr + OFFSET_BulletHeroesCoin;
            
            // We're patching a CODE section, which is protected
            // Need to make it writable first
            size_t pageSize = sysconf(_SC_PAGE_SIZE);
            uintptr_t pageStart = target & ~(pageSize - 1);
            size_t protectSize = pageSize;
            
            @try {
                // Make page writable
                vm_protect(mach_task_self(), pageStart, protectSize, FALSE, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_EXECUTE);
                
                // Read original instruction
                uint32_t currentInstr = *(uint32_t*)target;
                
                // Patch the instruction
                uint32_t* targetPtr = (uint32_t*)target;
                *targetPtr = PATCH_BYTES;
                
                // Flush instruction/data caches
                __builtin_arm_dmb(0xB);  // Full memory barrier
                __builtin_arm_isb(0xF);  // ISB - flush prefetch buffer
                
                // Restore protection
                vm_protect(mach_task_self(), pageStart, protectSize, FALSE, VM_PROT_READ | VM_PROT_EXECUTE);
                
                // Verify write
                uint32_t readBack = *(uint32_t*)target;
                
                snprintf(debugBuffer, sizeof(debugBuffer), 
                    "Code patch attempt\nTarget: 0x%lx\nOrig: 0x%08x\nNew: 0x%08x\n%s",
                    target & 0xFFFFFFFF,
                    currentInstr,
                    readBack,
                    (readBack == PATCH_BYTES) ? "✓ Patched" : "✗ Failed");
                
                if (readBack == PATCH_BYTES) {
                    statusMessage = "Instruction Patched!";
                    isCoinPatchApplied = true;
                } else {
                    statusMessage = "Patch verification failed";
                }
            } @catch (NSException *e) {
                statusMessage = "Exception during patch!";
                snprintf(debugBuffer, sizeof(debugBuffer), "Error: %s", [[e description] UTF8String]);
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
