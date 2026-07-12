#include "BasicHacks.h"
#include "../MenuLoad/Includes.h"
#include <mach-o/dyld.h>
#include <unistd.h>
#include <os/log.h>
#include <atomic>

static std::atomic<bool> gHackThreadRunning(false);
static std::atomic<bool> gPatchApplied(false);
static std::atomic<const char*> gCurrentStatus("Patch Initializing...");

// Ensure these constants are defined globally
static constexpr uintptr_t kCoinPatchOffset = 0x3121ab0; 
static constexpr uint32_t kTargetCoinValue = 0x528F4268; // The mov w8, #999999 instruction

void* BasicHacks::HacksThread(void* arg) {
    (void)arg;
    gHackThreadRunning.store(true);
    
    sleep(10); // Wait for binary load

    uintptr_t base = (uintptr_t)_dyld_get_image_header(0);
    uintptr_t targetAddr = base + kCoinPatchOffset; 
    
    while(true) {
        usleep(500000); 

        if (KTempVars.SunModToggle) {
            if (KomaruPatch::IsValidPointer(targetAddr)) {
                // Write the ARM64 instruction (uint32_t)
                KomaruPatch::WriteMem<uint32_t>(targetAddr, kTargetCoinValue);
                
                // Verify the write
                uint32_t verifyValue = KomaruPatch::ReadMem<uint32_t>(targetAddr);
                if (verifyValue == kTargetCoinValue) {
                    gPatchApplied.store(true, std::memory_order_relaxed);
                    gCurrentStatus.store("Coins Patched!", std::memory_order_relaxed);
                } else {
                    gPatchApplied.store(false, std::memory_order_relaxed);
                    gCurrentStatus.store("Write Verification Failed", std::memory_order_relaxed);
                }
            } else {
                gPatchApplied.store(false, std::memory_order_relaxed);
                gCurrentStatus.store("Invalid Address", std::memory_order_relaxed);
            }
        } else {
            gPatchApplied.store(false, std::memory_order_relaxed);
            gCurrentStatus.store("Patch Inactive", std::memory_order_relaxed);
        }
    }
    return nullptr;
}

// ... Keep your existing Initialize and helper functions below ...
void BasicHacks::Initialize() {
    pthread_t thread;
    pthread_create(&thread, nullptr, HacksThread, nullptr);
}

// Helper methods for the UI menu status
bool BasicHacks::IsValidPointer(uintptr_t address) {
    return KomaruPatch::IsValidPointer(address);
}

bool BasicHacks::GetPatchStatus() { return gPatchApplied.load(std::memory_order_relaxed); }
bool BasicHacks::IsThreadRunning() { return gHackThreadRunning.load(); }
const char* BasicHacks::GetStatusMessage() { return gCurrentStatus.load(std::memory_order_relaxed); }
const char* BasicHacks::GetDebugInfo() { return "Direct Memory Patching (Static Offset)"; }
