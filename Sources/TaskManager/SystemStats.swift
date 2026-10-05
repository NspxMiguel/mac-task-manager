import Darwin
import Foundation

struct SystemSnapshot {
    var cpuUsage: Double      // 0...100
    var memoryUsedGB: Double
    var memoryTotalGB: Double
    var memoryUsedFraction: Double // 0...1
    var diskUsedGB: Double
    var diskTotalGB: Double
    var diskUsedFraction: Double
}

/// Reads real system counters directly via Darwin/Mach APIs (no shelling out).
final class SystemStatsReader {
    private var previousCPUTicks: (user: UInt32, system: UInt32, idle: UInt32, nice: UInt32)?

    func snapshot() -> SystemSnapshot {
        let memory = readMemory()
        let disk = readDisk()
        return SystemSnapshot(
            cpuUsage: readCPUUsage(),
            memoryUsedGB: memory.used,
            memoryTotalGB: memory.total,
            memoryUsedFraction: memory.fraction,
            diskUsedGB: disk.used,
            diskTotalGB: disk.total,
            diskUsedFraction: disk.fraction
        )
    }

    private func readCPUUsage() -> Double {
        var cpuLoad = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &cpuLoad) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }

        let user = cpuLoad.cpu_ticks.0
        let system = cpuLoad.cpu_ticks.1
        let idle = cpuLoad.cpu_ticks.2
        let nice = cpuLoad.cpu_ticks.3

        defer { previousCPUTicks = (user, system, idle, nice) }

        guard let prev = previousCPUTicks else { return 0 }

        let userDiff = Double(user &- prev.user)
        let systemDiff = Double(system &- prev.system)
        let idleDiff = Double(idle &- prev.idle)
        let niceDiff = Double(nice &- prev.nice)
        let totalDiff = userDiff + systemDiff + idleDiff + niceDiff
        guard totalDiff > 0 else { return 0 }

        let busy = userDiff + systemDiff + niceDiff
        return min(max((busy / totalDiff) * 100.0, 0), 100)
    }

    private func readMemory() -> (used: Double, total: Double, fraction: Double) {
        var totalMemBytes: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        sysctlbyname("hw.memsize", &totalMemBytes, &size, nil, 0)

        var vmStats = vm_statistics64()
        var vmCount = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(vmCount)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &vmCount)
            }
        }

        // Memory is sold and shown in binary units: an 18 GB Mac has 18 GiB.
        // Dividing by 1e9 made it read 19.3 GB.
        let gib = 1_073_741_824.0
        let pageSize = Double(vm_kernel_page_size)
        guard result == KERN_SUCCESS else { return (0, Double(totalMemBytes) / gib, 0) }

        // Activity Monitor's "Memory Used" = App Memory + Wired + Compressed,
        // where App Memory is anonymous memory minus what the system may purge.
        // `active_count` mixes in file cache and leaves out inactive app pages.
        let appPages = Double(vmStats.internal_page_count) - Double(vmStats.purgeable_count)
        let used = (max(appPages, 0) + Double(vmStats.wire_count) + Double(vmStats.compressor_page_count)) * pageSize
        let totalGB = Double(totalMemBytes) / gib
        let usedGB = used / gib
        let fraction = totalGB > 0 ? min(max(usedGB / totalGB, 0), 1) : 0
        return (usedGB, totalGB, fraction)
    }

    private func readDisk() -> (used: Double, total: Double, fraction: Double) {
        // "Available for important usage" is what Finder and System Settings
        // show: free space plus purgeable caches the system will clear on
        // demand. Raw free blocks undercount it on APFS.
        let keys: Set<URLResourceKey> = [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey]
        guard let values = try? URL(fileURLWithPath: "/").resourceValues(forKeys: keys),
              let total = values.volumeTotalCapacity,
              let available = values.volumeAvailableCapacityForImportantUsage
        else { return (0, 0, 0) }
        let totalBytes = Double(total)
        let usedBytes = max(totalBytes - Double(available), 0)
        let totalGB = totalBytes / 1e9
        let usedGB = usedBytes / 1e9
        let fraction = totalGB > 0 ? min(max(usedGB / totalGB, 0), 1) : 0
        return (usedGB, totalGB, fraction)
    }
}
