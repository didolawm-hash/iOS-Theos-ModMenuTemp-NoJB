#include "BasicHacks.h"
#include <os/log.h>
#include <mach-o/dyld.h>

// 1. Declare the hook target
typedef void (*CoinTrayHUDAwake_t)(void* self);
CoinTrayHUDAwake_t orig_CoinTrayHUDAwake = nullptr;

static void* gCoinTrayHUDInstance = nullptr;

// 2. The Hook
void Hook_CoinTrayHUDAwake(void* self) {
    os_log(OS_LOG_DEFAULT, "KTemp: HUD Instance Captured: %p", self);
    gCoinTrayHUDInstance = self;
    if (orig_CoinTrayHUDAwake) orig_CoinTrayHUDAwake(self);
}

void* BasicHacks::HacksThread(void* arg) {
    sleep(5); // Give game time to load

    // 3. Hook initialization
    uintptr_t base = (uintptr_t)_dyld_get_image_header(0); // Simple base
    // Use your exact offset from your dump.cs
    uintptr_t awakeAddr = base + 0x30DE208; 
    
    // MSHookFunction now works because of the injected iGameGod framework
    MSHookFunction((void*)awakeAddr, (void*)Hook_CoinTrayHUDAwake, (void**)&orig_CoinTrayHUDAwake);

    while(true) {
        usleep(100000); 
        // 4. Memory Patching using the captured instance
        if (KTempVars.SunModToggle && gCoinTrayHUDInstance) {
            uintptr_t coinAddr = (uintptr_t)gCoinTrayHUDInstance + 0x4C;
            *(int*)coinAddr = 999999; // Force value
        }
    }
    return NULL;
}

void BasicHacks::Initialize() {
    pthread_t thread;
    pthread_create(&thread, NULL, HacksThread, NULL);
}
