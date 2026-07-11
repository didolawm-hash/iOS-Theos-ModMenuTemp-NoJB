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

static void* gCoinTrayHUDInstance = nullptr;
static std::atomic<bool> gHackThreadRunning(false);
static std::atomic<const char*> gStatusMessage("Thread not started");

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
    gStatusMessage.store("Waiting for game load...");
    sleep(10); // Wait longer to ensure game is fully loaded
    
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
            gStatusMessage.store("Coins Locked!");
        } else if (!gCoinTrayHUDInstance) {
            gStatusMessage.store("Waiting for HUD...");
        } else {
            gStatusMessage.store("Patch Inactive");
        }
    }
    return NULL;
}

void BasicHacks::Initialize() {
    pthread_t thread;
    pthread_create(&thread, NULL, HacksThread, NULL);
}

bool BasicHacks::IsValidPointer(uintptr_t Offset) {
    return KomaruPatch::IsValidPointer(Offset);
}

bool BasicHacks::GetPatchStatus() { return gCoinTrayHUDInstance != nullptr; }
bool BasicHacks::IsThreadRunning() { return gHackThreadRunning.load(); }
const char* BasicHacks::GetStatusMessage() { return gStatusMessage.load(); }
const char* BasicHacks::GetDebugInfo() { 
    static char buf[128];
    snprintf(buf, sizeof(buf), "HUD: %p | Toggled: %d", gCoinTrayHUDInstance, KTempVars.SunModToggle);
    return buf;
}
