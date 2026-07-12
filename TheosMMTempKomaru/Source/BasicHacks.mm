#include "BasicHacks.h"
#include "../MenuLoad/Includes.h"
#include <mach-o/dyld.h>
#include <unistd.h>
#include <os/log.h>
#include <atomic>

// Static variables to maintain patch state
static std::atomic<bool> gHackThreadRunning(false);
static std::atomic<bool> gPatchApplied(false);
static std::atomic<const char*> gCurrentStatus("Patch Initializing...");

// The offset confirmed via iGameGod Watchpoint
static constexpr uintptr_t kCoinPatchOffset = 0x3121ab4; 
static constexpr int kTargetCoinValue = 999999;

void* BasicHacks::HacksThread(void* arg) {
    (void)arg;
    gHackThreadRunning.store(true);
    
    // Give the game enough time to fully load the binary into memory
    sleep(10); 

    // Calculate the absolute address of the coin balance
    uintptr_t base = (uintptr_t)_dyld_get_image_header(0);
    uintptr_t targetAddr = base + kCoinPatchOffset; 
    
    while(true) {
        usleep(500000); // 500ms cycle

        if (KTempVars.SunModToggle) {
            // Verify if the address is currently valid
            if (KomaruPatch::IsValidPointer(targetAddr)) {
                // Perform the write using KomaruPatch to ensure memory is writable (vm_protect)
                KomaruPatch::WriteMem<int>(targetAddr, kTargetCoinValue);
                
                // Verify the write was successful
                int verifyValue = KomaruPatch::ReadMem(targetAddr);
                if (verifyValue == kTargetCoinValue) {
                    gPatchApplied.store(true, std::memory_order_relaxed);
                    gCurrentStatus.store("Coins Patched!", std::memory_order_relaxed);
                } else {
                    gPatchApplied.store(false, std::memory_order_relaxed);
                    gCurrentStatus.store("Write Verification Failed", std::memory_order_relaxed);
                }
            } else {
                gPatchApplied.store(false, std::memory_order_relaxed);
                gCurrentStatus.store("Invalid Memory Address", std::memory_order_relaxed);
            }
        } else {
            gPatchApplied.store(false, std::memory_order_relaxed);
            gCurrentStatus.store("Patch Inactive", std::memory_order_relaxed);
        }
    }
    return nullptr;
}

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
