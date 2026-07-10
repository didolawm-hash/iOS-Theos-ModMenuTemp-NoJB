/*
IOS Theos Template Komaru
Jailed (NoJB) Mod Menu Template for iOS Games
*/

#include "BasicHacks.h"
#include "../MenuLoad/Includes.h"
#include <mach-o/dyld.h>
#include <sys/mman.h>
#include <unistd.h>

bool running = true;
bool isCoinPatchApplied = false;

namespace offsets {
    // Relative static offset for Bullet Heroes
    constexpr uintptr_t OFFSET_BulletHeroesCoin = 0x3121AB0;
    
    // Original bytes (Make sure to verify these in a clean game!)
    constexpr uint32_t ORIGINAL_BYTES           = 0x00000000; 
    
    // Your patch bytes (Converted to Little-Endian)
    constexpr uint32_t PATCH_BYTES              = 0x0B133108; 
}

void* BasicHacks::HacksThread(void* arg)
{
    sleep(5); // Allow game to load
    uintptr_t BaseAddr = (uintptr_t)_dyld_get_image_header(0);

    while(running)
    {   
        using namespace offsets;
        usleep(100000);

        if (KTempVars.CoinModToggle) // Ensure this variable name matches your MenuLayout
        {
            if (!isCoinPatchApplied) 
            {
                uintptr_t target = BaseAddr + OFFSET_BulletHeroesCoin;
                size_t pageSize = sysconf(_SC_PAGE_SIZE);
                uintptr_t pageStart = target & ~(pageSize - 1);

                if (mprotect((void*)pageStart, pageSize, PROT_READ | PROT_WRITE | PROT_EXEC) == 0) {
                    *(uint32_t*)target = PATCH_BYTES;
                    isCoinPatchApplied = true;
                }
            }
        } 
        else 
        {
            if (isCoinPatchApplied) 
            {
                uintptr_t target = BaseAddr + OFFSET_BulletHeroesCoin;
                size_t pageSize = sysconf(_SC_PAGE_SIZE);
                uintptr_t pageStart = target & ~(pageSize - 1);

                if (mprotect((void*)pageStart, pageSize, PROT_READ | PROT_WRITE | PROT_EXEC) == 0) {
                    *(uint32_t*)target = ORIGINAL_BYTES;
                    isCoinPatchApplied = false;
                }
            }
        }
    } 
    return NULL; 
}

void BasicHacks::Initialize()
{
    pthread_t BasicHacksThread;
    pthread_create(&BasicHacksThread, nullptr, HacksThread, nullptr);
}
