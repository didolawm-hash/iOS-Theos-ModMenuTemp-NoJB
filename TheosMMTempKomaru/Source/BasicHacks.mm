#include "BasicHacks.h"
#include <os/log.h>
#include <mach-o/dyld.h>
#include <unistd.h>
#include <substrate.h> // Ensure you have this header for MSHookFunction

// 1. Target: Hook the Update method
typedef void (*CoinTrayHUDUpdate_t)(void* self);
CoinTrayHUDUpdate_t orig_CoinTrayHUDUpdate = nullptr;

static void* gCoinTrayHUDInstance = nullptr;

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
            statusMessage = "Coins Locked!";
        } else if (!gCoinTrayHUDInstance) {
            statusMessage = "Waiting for HUD...";
        } else {
            statusMessage = "Patch Inactive";
        }
    }
    return NULL;
}

void BasicHacks::Initialize() {
    pthread_t thread;
    pthread_create(&thread, NULL, HacksThread, NULL);
}

bool BasicHacks::GetPatchStatus() { return gCoinTrayHUDInstance != nullptr; }
const char* BasicHacks::GetStatusMessage() { return statusMessage; }
const char* BasicHacks::GetDebugInfo() { 
    static char buf[128];
    snprintf(buf, sizeof(buf), "HUD: %p | Toggled: %d", gCoinTrayHUDInstance, KTempVars.SunModToggle);
    return buf;
}
