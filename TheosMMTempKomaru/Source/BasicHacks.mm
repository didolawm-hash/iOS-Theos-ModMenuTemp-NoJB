#include "BasicHacks.h"
#include "../MenuLoad/Includes.h"
#include <mach-o/dyld.h>
#include <unistd.h>
#include <os/log.h>
#include <atomic>

static std::atomic<bool> gHackThreadRunning(false);
static const char* gCurrentStatus = "Patch Initializing...";

void* BasicHacks::HacksThread(void* arg) {
    gHackThreadRunning.store(true);
    sleep(10); // Wait for binary to load

    uintptr_t base = (uintptr_t)_dyld_get_image_header(0);
    // Address from your screenshot
    uintptr_t targetAddr = base + 0x30DE1F8; 
    
    // Hex bytes for "mov w8, #0xF423F" (999999 in decimal)
    // 0x528F4278 is the ARM64 encoded instruction
    uint32_t patchBytes = 0x528F4278; 

    while(true) {
        usleep(500000); // 500ms patch loop

        if (KTempVars.SunModToggle) {
            // Write directly to the code segment
            // KomaruPatch handles vm_protect to make this segment writable
            if (KomaruPatch::WriteMem<uint32_t>(targetAddr, patchBytes)) {
                gCurrentStatus = "Coins Patched via Assembly!";
            } else {
                gCurrentStatus = "Patch Failed (Permission Denied)";
            }
        } else {
            gCurrentStatus = "Patch Inactive";
        }
    }
    return nullptr;
}

void BasicHacks::Initialize() {
    pthread_t thread;
    pthread_create(&thread, nullptr, HacksThread, nullptr);
}

bool BasicHacks::GetPatchStatus() { return KTempVars.SunModToggle; }
const char* BasicHacks::GetStatusMessage() { return gCurrentStatus; }
const char* BasicHacks::GetDebugInfo() { return "Using Assembly Patch (No-Hook)"; }
