#pragma once

#include <iostream>
#include <cstring>
#include <mach/mach.h>
#include <mach/vm_map.h>

class KomaruPatch {
public:
    // Increased range to ensure we don't block valid memory regions
    static bool IsValidPointer(uintptr_t address) {
        return address > 0x1000 && address < 0xFFFFFFFFFFFFFFFF;
    }

    static void WriteMem(uintptr_t address, const void* data, size_t size) {
        if (!IsValidPointer(address)) return;

        // 1. Get the current page size to align memory correctly
        size_t pageSize = 0x4000; // iOS ARM64 page size
        uintptr_t pageStart = address & ~(pageSize - 1);
        size_t pageOffset = address - pageStart;
        size_t protSize = (pageOffset + size + pageSize - 1) & ~(pageSize - 1);

        // 2. Change protection to READ/WRITE/EXECUTE to allow patching
        vm_protect(mach_task_self(), (vm_address_t)pageStart, protSize, false, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
        
        // 3. Copy the bytes
        memcpy(reinterpret_cast<void*>(address), data, size);
        
        // 4. Flush the Instruction Cache so the CPU sees the new code immediately
        // This is the step most mod menus miss!
        sys_icache_invalidate((void*)address, size);
        
        // 5. Restore protection to READ/EXECUTE
        vm_protect(mach_task_self(), (vm_address_t)pageStart, protSize, false, VM_PROT_READ | VM_PROT_EXECUTE);
    }
};
