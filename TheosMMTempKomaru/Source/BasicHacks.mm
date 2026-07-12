#include "BasicHacks.h"
#include "../MenuLoad/Includes.h"
#include <mach-o/dyld.h>
#include <unistd.h>
#include <os/log.h>
#include <atomic>
#include <cstring> // Required for memcpy

static std::atomic<bool> gHackThreadRunning(false);
static std::atomic<bool> gPatchApplied(false);
static std::atomic<const char*> gCurrentStatus("Patch Initializing...");

// The target address and the exact bytes from your working Live Patcher
static constexpr uintptr_t kCoinPatchOffset = 0x3121ab0; 
static const unsigned char kTargetBytes[] = {0xE8, 0xFF, 0x8F, 0x52}; // E8 FF 8F 52

void* BasicHacks::HacksThread(void* arg) {
    (void)arg;
    gHackThreadRunning.store(true);
    
    sleep(10); // Wait for binary to load

    uintptr_t base = (uintptr_t)_dyld_get_image_header(0);
    uintptr_t targetAddr = base + kCoinPatchOffset; 
    
    while(true) {
        usleep(500000); // 500ms patch loop

        if (KTempVars.SunModToggle) {
            if (KomaruPatch::IsValidPointer(targetAddr)) {
                // Using raw byte writing to match the Live Patcher's behavior
                // We use KomaruPatch to handle the vm_protect automatically
                KomaruPatch::WriteMem(targetAddr, (void*)kTargetBytes, sizeof(kTargetBytes));
                
                // Verify the bytes at the address
                unsigned char buffer[4];
                KomaruPatch::ReadMem(targetAddr, buffer, sizeof(buffer));
                
                if (memcmp(buffer, kTargetBytes, sizeof(kTargetBytes)) == 0) {
                    gPatchApplied.store(true, std::memory_order_relaxed);
                    gCurrentStatus.store("Coins Patched!", std::memory_order_relaxed);
                } else {
                    gCurrentStatus.store("Write Failed", std::memory_order_relaxed);
                }
            } else {
                gCurrentStatus.store("Invalid Address", std::memory_order_relaxed);
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

bool BasicHacks::IsValidPointer(uintptr_t address) {
    return KomaruPatch::IsValidPointer(address);
}

bool BasicHacks::GetPatchStatus() { return gPatchApplied.load(std::memory_order_relaxed); }
bool BasicHacks::IsThreadRunning() { return gHackThreadRunning.load(); }
const char* BasicHacks::GetStatusMessage() { return gCurrentStatus.load(std::memory_order_relaxed); }
const char* BasicHacks::GetDebugInfo() { return "Direct Byte Patching (Raw)"; }
