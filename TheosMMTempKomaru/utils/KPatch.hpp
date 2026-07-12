/*
IOS Theos Template Komaru
Jailed (NoJB) Mod Menu Template for iOS Games
By aq9
https://github.com/VenerableCode/iOS-Theos-ModMenuTemp-NoJB
*/


#pragma once

#include <iostream>
#include <cstring>
#include <mach/mach.h>
#include <mach/vm_map.h>

class KomaruPatch {
public:
    static bool IsValidPointer(uintptr_t address) {
        return address > 0x100000000 && address < 0x3000000000;
    }

    static uintptr_t ReadMem(uintptr_t address) {
        if (!IsValidPointer(address)) {
            return 0;
        }
        return *reinterpret_cast<uintptr_t*>(address);
    }

    static void ReadMem(uintptr_t address, void* buffer, size_t size) {
        if (!IsValidPointer(address)) {
            return;
        }
        memcpy(buffer, reinterpret_cast<void*>(address), size);
    }

    template <typename T>
    static void WriteMem(uintptr_t address, const T& value) {
        if (!IsValidPointer(address)) {
            return;
        }
        *reinterpret_cast<T*>(address) = value;
    }

    static void WriteMem(uintptr_t address, const void* data, size_t size) {
        if (!IsValidPointer(address)) {
            return;
        }
        vm_protect(mach_task_self(), (vm_address_t)address, size, false, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
        memcpy(reinterpret_cast<void*>(address), data, size);
        vm_protect(mach_task_self(), (vm_address_t)address, size, false, VM_PROT_READ | VM_PROT_EXECUTE);
    }
};
