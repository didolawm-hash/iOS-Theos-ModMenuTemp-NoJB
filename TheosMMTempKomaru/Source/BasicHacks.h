/*
IOS Theos Template Komaru
Jailed (NoJB) Mod Menu Template for iOS Games
By aq9
https://github.com/VenerableCode/iOS-Theos-ModMenuTemp-NoJB
*/



#pragma once

#include <stdint.h>

class BasicHacks {
public:
    BasicHacks(const BasicHacks&) = delete;

    static BasicHacks& GetInstance() {
        static BasicHacks Instance;
        return Instance;
    }

    static bool IsValidPointer(uintptr_t address);
    static void* HacksThread(void* arg);
    static bool GetPatchStatus(); // Returns true if patch is applied
    static bool IsThreadRunning(); // Returns true if hack thread is running
    static const char* GetStatusMessage(); // Returns detailed status message
    static const char* GetDebugInfo(); // Returns debug information with addresses

    void Initialize();

private:
    BasicHacks() { }
};

static BasicHacks& BasicCheats = BasicHacks::GetInstance();
