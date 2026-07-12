#include "BasicHacks.h"
#include "../MenuLoad/Includes.h"
#include <mach-o/dyld.h>
#include <unistd.h>
#include <os/log.h>
#include <atomic>

static std::atomic<bool> gHackThreadRunning(false);
static std::atomic<bool> gPatchApplied(false);
static std::atomic<const char*> gCurrentStatus("Patch Initializing...");
static constexpr uintptr_t kCoinPatchInstructionOffset = 0x30DE1F8;
static constexpr uint32_t kCoinPatchInstruction = 0x528F4278; // mov w8, #0xF423F

void* BasicHacks::HacksThread(void* arg) {
    gHackThreadRunning.store(true);
    sleep(10); // Wait for binary to load

    uintptr_t base = (uintptr_t)_dyld_get_image_header(0);
    // Hardcoded offset for the target ARM64 instruction in the game's coin update routine
    // (offset identified during runtime analysis with iGameGod/memory inspection).
    uintptr_t targetAddr = base + kCoinPatchInstructionOffset; 
    
    // ARM64 machine code for: mov w8, #0xF423F (999999 decimal),
    // generated/verified with ARM64 assembler/disassembler tooling (e.g. llvm-mc/objdump).
    uint32_t patchBytes = kCoinPatchInstruction;
    gPatchApplied.store(false, std::memory_order_relaxed);

    while(true) {
        usleep(500000); // 500ms patch loop

        if (KTempVars.SunModToggle) {
            if (KomaruPatch::IsValidPointer(targetAddr)) {
                uint32_t currentValue = static_cast<uint32_t>(KomaruPatch::ReadMem(targetAddr));
                if (!gPatchApplied.load(std::memory_order_relaxed) || currentValue != patchBytes) {
                    if (currentValue != patchBytes) {
                        os_log_debug(OS_LOG_DEFAULT, "Patch value changed (0x%x). Reapplying.", currentValue);
                    }
                    KomaruPatch::WriteMem<uint32_t>(targetAddr, patchBytes);
                    gPatchApplied.store(true, std::memory_order_relaxed);
                }
                gCurrentStatus.store("Coins Patched via Assembly!", std::memory_order_relaxed);
            } else {
                gPatchApplied.store(false, std::memory_order_relaxed);
                gCurrentStatus.store("Patch Failed (Invalid Address)", std::memory_order_relaxed);
            }
        } else {
            gPatchApplied.store(false, std::memory_order_relaxed);
            gCurrentStatus.store("Patch Inactive", std::memory_order_relaxed);
        }
    }
    gPatchApplied.store(false, std::memory_order_relaxed);
    gHackThreadRunning.store(false, std::memory_order_relaxed);
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
const char* BasicHacks::GetDebugInfo() { return "Using Assembly Patch (No-Hook)"; }
