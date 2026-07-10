/*
IOS Theos Template Komaru
Jailed (NoJB) Mod Menu Template for iOS Games
By aq9
https://github.com/VenerableCode/iOS-Theos-ModMenuTemp-NoJB
*/

#include "BasicHacks.h"
#include "../MenuLoad/Includes.h"
#include <mach-o/dyld.h>
#include <sys/mman.h>
#include <unistd.h>

bool running = true;
bool isSunPatchApplied = false;

namespace offsets {
    // Relative static offset
    constexpr uintptr_t OFFSET_PlantsVsZombiesSun  = 0x1E61A4;
    
    // REPLACE THIS WITH YOUR REAL ORIGINAL BYTES!
    // Leaving this as 0x00000000 will likely cause a crash when turning the mod OFF.
    constexpr uint32_t ORIGINAL_BYTES              = 0x00000000; 
    
    // Patch bytes (Little-Endian)
    constexpr uint32_t PATCH_BYTES                 = 0x5284E1D5; 
}

void* BasicHacks::HacksThread(void* arg)
{
    usleep(500000); 
    uintptr_t BaseAddr = (uintptr_t)_dyld_get_image_header(0);

    while(running)
    {   
        using namespace offsets;
        usleep(100000);

        if (KTempVars.SunModToggle) 
        {
            if (!isSunPatchApplied) 
            {
                uintptr_t target = BaseAddr + OFFSET_PlantsVsZombiesSun;
                
                // Align to page size for memory protection
                size_t pageSize = sysconf(_SC_PAGE_SIZE);
                uintptr_t pageStart = target & ~(pageSize - 1);

                // Make memory writable
                if (mprotect((void*)pageStart, pageSize, PROT_READ | PROT_WRITE | PROT_EXEC) == 0) {
                    *(uint32_t*)target = PATCH_BYTES;
                    isSunPatchApplied = true;
                }
            }
        } 
        else 
        {
            if (isSunPatchApplied) 
            {
                uintptr_t target = BaseAddr + OFFSET_PlantsVsZombiesSun;
                size_t pageSize = sysconf(_SC_PAGE_SIZE);
                uintptr_t pageStart = target & ~(pageSize - 1);

                // Make memory writable
                if (mprotect((void*)pageStart, pageSize, PROT_READ | PROT_WRITE | PROT_EXEC) == 0) {
                    *(uint32_t*)target = ORIGINAL_BYTES;
                    isSunPatchApplied = false;
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
