//
//  MemoryStatistics.c
//  RadLab
//
//  Created by Tim Ruddick on 2/26/13.
//  Copyright (c) 2013 Totally Rad. All rights reserved.
//

#import <stdio.h>
#import <mach/mach.h>
#import <mach/mach_host.h>
#import "MemoryStatistics.h"

#ifndef CONFIGURATION_AppStore

natural_t memoryBytesAvailable() {
    mach_port_t host_port = mach_host_self();
    mach_msg_type_number_t host_size = sizeof(vm_statistics_data_t) / sizeof(integer_t);
    vm_size_t pagesize;
    vm_statistics_data_t vm_stat;

    host_page_size(host_port, &pagesize);

    if (host_statistics(host_port, HOST_VM_INFO, (host_info_t)&vm_stat, &host_size) != KERN_SUCCESS)
        return 0;

    //natural_t mem_used = (vm_stat.active_count + vm_stat.inactive_count + vm_stat.wire_count) * pagesize;
    natural_t mem_free = (natural_t)(vm_stat.free_count * pagesize);
    //natural_t mem_total = mem_used + mem_free;

    return mem_free;
}

natural_t memoryBytesInUse() {
    mach_port_t host_port = mach_host_self();
    mach_msg_type_number_t host_size = sizeof(vm_statistics_data_t) / sizeof(integer_t);
    vm_size_t pagesize;
    vm_statistics_data_t vm_stat;

    host_page_size(host_port, &pagesize);

    if (host_statistics(host_port, HOST_VM_INFO, (host_info_t)&vm_stat, &host_size) != KERN_SUCCESS)
        return 0;

    natural_t mem_used = (natural_t)((vm_stat.active_count + vm_stat.inactive_count + vm_stat.wire_count) * pagesize);

    return mem_used;
}

NSString* stringWithMemoryInfo() {
    mach_port_t host_port = mach_host_self();
    mach_msg_type_number_t host_size = sizeof(vm_statistics_data_t) / sizeof(integer_t);
    vm_size_t pagesize;
    vm_statistics_data_t vm_stat;

    host_page_size(host_port, &pagesize);

    if (host_statistics(host_port, HOST_VM_INFO, (host_info_t)&vm_stat, &host_size) != KERN_SUCCESS)
        return @"no memstats!";

    static const int M = 1024 * 1024;
    const natural_t used = vm_stat.active_count + vm_stat.inactive_count + vm_stat.wire_count;
    NSMutableString* result = [[NSMutableString alloc] initWithFormat:@"f=%zd a=%zd i=%zd w=%zd (u=%zd f+u=%zd)",
      vm_stat.free_count * pagesize / M,
      vm_stat.active_count * pagesize / M,
      vm_stat.inactive_count * pagesize / M,
      vm_stat.wire_count * pagesize / M,
      used * pagesize / M,
      (vm_stat.free_count + used) * pagesize / M];
    return result;
}
#else
NSString* stringWithMemoryInfo() {
    return @"no memstats in iTMS";
}
#endif

NSString* stringWithMemoryBytesAvailable() {
    natural_t count = memoryBytesAvailable();
    return [NSNumberFormatter localizedStringFromNumber:[NSNumber numberWithLongLong:count] numberStyle:NSNumberFormatterDecimalStyle];
}

NSString* stringWithMemoryBytesInUse() {
    natural_t count = memoryBytesInUse();
    return [NSNumberFormatter localizedStringFromNumber:[NSNumber numberWithLongLong:count] numberStyle:NSNumberFormatterDecimalStyle];
}
