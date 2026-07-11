#include "BasicHacks.h"
#include "../MenuLoad/Includes.h"
#include <mach-o/dyld.h>
#include <atomic>
#include <os/log.h>
#include <pthread/pthread.h>
#include <stdio.h>
#include <substrate.h>
#include <unistd.h>

// 1. Target: Hook the Update method
typedef void (*CoinTrayHUDUpdate_t)(void* self);
CoinTrayHUDUpdate_t orig_CoinTrayHUDUpdate = nullptr;

enum HackStatus : int {
    kThreadNotStarted = 0,
    kWaitingForGameLoad,
    kWaitingForHUD,
    kCoinsLocked,
    kPatchInactive,
};

static const char* const kStatusMessages[] = {
    "Thread not started",
    "Waiting for game load...",
    "Waiting for HUD...",
    "Coins Locked!",
    "Patch Inactive",
};
static constexpr unsigned int kStatusMessageCount = sizeof(kStatusMessages) / sizeof(kStatusMessages[0]);
static constexpr unsigned int kInitialLoadDelaySeconds = 10;
static_assert(kStatusMessageCount == (kPatchInactive + 1), "Status messages must match HackStatus values");

static void* gCoinTrayHUDInstance = nullptr;
static std::atomic<bool> gHackThreadRunning(false);
static std::atomic<int> gHackStatus(kThreadNotStarted);

// 2. The Hook: Captures the instance during the game's update loop
void Hook_CoinTrayHUDUpdate(void* self) {
    if (gCoinTrayHUDInstance == nullptr) {
        gCoinTrayHUDInstance = self;
        os_log(OS_LOG_DEFAULT, "KTemp: HUD Instance captured via Update: %p", self);
    }
    
    // Call the original function so the game functions normally
    if (orig_CoinTrayHUDUpdate) orig_CoinTrayHUDUpdate(self);
}

void* BasicHacks::HacksThread(void* arg) {
    (void)arg;
    gHackThreadRunning.store(true);
    gHackStatus.store(kWaitingForGameLoad);
    sleep(kInitialLoadDelaySeconds);
    
    uintptr_t base = (uintptr_t)_dyld_get_image_header(0);
    // 0x30DECBC is the RVA for CoinTrayHUD.Update()
    uintptr_t updateAddr = base + 0x30DECBC; 
    
    os_log(OS_LOG_DEFAULT, "KTemp: Attempting to hook Update at: 0x%lx", updateAddr);
    
    // Attach the hook
    MSHookFunction((void*)updateAddr, (void*)Hook_CoinTrayHUDUpdate, (void**)&orig_CoinTrayHUDUpdate);

    while(true) {
        usleep(200000); // 200ms patching loop

        if (KTempVars.SunModToggle && gCoinTrayHUDInstance != nullptr) {
            uintptr_t coinAddr = (uintptr_t)gCoinTrayHUDInstance + 0x4C;
            
            // Direct memory write
            *(int*)coinAddr = 999999; 
            
            // Update status for your UI
            gHackStatus.store(kCoinsLocked);
        } else if (!gCoinTrayHUDInstance) {
            gHackStatus.store(kWaitingForHUD);
        } else {
            gHackStatus.store(kPatchInactive);
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

bool BasicHacks::GetPatchStatus() { return gCoinTrayHUDInstance != nullptr; }
bool BasicHacks::IsThreadRunning() { return gHackThreadRunning.load(); }
const char* BasicHacks::GetStatusMessage() {
    int status = gHackStatus.load();
    if (status < 0 || static_cast<unsigned int>(status) >= kStatusMessageCount) {
        return "Unknown";
    }
    return kStatusMessages[status];
}
const char* BasicHacks::GetDebugInfo() { 
    static char buf[128];
    snprintf(buf, sizeof(buf), "HUD: %p | Toggled: %d", gCoinTrayHUDInstance, KTempVars.SunModToggle);
    return buf;
}
