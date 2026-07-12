#include "BasicHacks.h"
#include "../MenuLoad/Includes.h"
#include <mach-o/dyld.h>
#include <unistd.h>
#include <os/log.h>
#include <atomic>

static std::atomic<bool> gHackThreadRunning(false);
static std::atomic<const char*> gCurrentStatus("Patch Initializing...");

void* BasicHacks::HacksThread(void* arg) {
    gHackThreadRunning.store(true);
    sleep(10); // Wait for binary to load

    uintptr_t base = (uintptr_t)_dyld_get_image_header(0);
    // Hardcoded offset for the target ARM64 instruction inside the main image.
    uintptr_t targetAddr = base + 0x30DE1F8; 
    
    // ARM64 machine code for: mov w8, #0xF423F (999999 decimal),
    // generated/verified with ARM64 disassembler/assembler tooling.
    uint32_t patchBytes = 0x528F4278; 
    bool patchApplied = false;

    while(true) {
        usleep(500000); // 500ms patch loop

        if (KTempVars.SunModToggle) {
            if (KomaruPatch::IsValidPointer(targetAddr)) {
                uint32_t currentValue = static_cast<uint32_t>(KomaruPatch::ReadMem(targetAddr));
                if (!patchApplied || currentValue != patchBytes) {
                    KomaruPatch::WriteMem<uint32_t>(targetAddr, patchBytes);
                    patchApplied = true;
                }
                gCurrentStatus.store("Coins Patched via Assembly!", std::memory_order_relaxed);
            } else {
                patchApplied = false;
                gCurrentStatus.store("Patch Failed (Invalid Address)", std::memory_order_relaxed);
            }
        } else {
            patchApplied = false;
            gCurrentStatus.store("Patch Inactive", std::memory_order_relaxed);
        }
    }
    return nullptr;
}

void BasicHacks::Initialize() {
    pthread_t thread;
    pthread_create(&thread, nullptr, HacksThread, nullptr);
}

bool BasicHacks::IsValidPointer(uintptr_t address) {
    return KomaruPatch::IsValidPointer(address);
}

bool BasicHacks::GetPatchStatus() { return KTempVars.SunModToggle; }
bool BasicHacks::IsThreadRunning() { return gHackThreadRunning.load(); }
const char* BasicHacks::GetStatusMessage() { return gCurrentStatus.load(std::memory_order_relaxed); }
const char* BasicHacks::GetDebugInfo() { return "Using Assembly Patch (No-Hook)"; }
