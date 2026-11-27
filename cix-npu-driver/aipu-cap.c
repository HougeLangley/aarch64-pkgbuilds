// Minimal userspace smoke test for the CIX Orion O6 NPU (ArmChina Zhouyi) driver.
// Opens /dev/aipu as an unprivileged user and queries capabilities through the
// kernel ioctl interface, which is the same entry point every NPU runtime uses.
//
// Build: gcc -O2 -Wall -o aipu-cap aipu-cap.c   (needs cix-npu-uapi-headers)
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <sys/ioctl.h>
#include <unistd.h>
#include <misc/armchina_aipu.h>

static const char *isa_name(unsigned int v)
{
    switch (v) {
    case AIPU_ISA_VERSION_ZHOUYI_V1:   return "zhouyi-v1";
    case AIPU_ISA_VERSION_ZHOUYI_V2_0: return "zhouyi-v2_0";
    case AIPU_ISA_VERSION_ZHOUYI_V2_1: return "zhouyi-v2_1";
    case AIPU_ISA_VERSION_ZHOUYI_V2_2: return "zhouyi-v2_2";
    case AIPU_ISA_VERSION_ZHOUYI_V3:   return "zhouyi-v3";
    case AIPU_ISA_VERSION_ZHOUYI_V3_1: return "zhouyi-v3_1";
    case AIPU_ISA_VERSION_ZHOUYI_V3_2: return "zhouyi-v3_2";
    default:                           return "unknown";
    }
}

int main(void)
{
    int fd = open("/dev/aipu", O_RDWR);
    if (fd < 0) {
        fprintf(stderr, "open /dev/aipu: %s\n", strerror(errno));
        return 1;
    }

    struct aipu_cap cap;
    memset(&cap, 0, sizeof(cap));
    if (ioctl(fd, AIPU_IOCTL_QUERY_CAP, &cap) < 0) {
        fprintf(stderr, "AIPU_IOCTL_QUERY_CAP: %s\n", strerror(errno));
        close(fd);
        return 1;
    }

    printf("partitions      : %u (homogeneous=%u)\n", cap.partition_cnt, cap.is_homogeneous);
    printf("asid count      : %u\n", cap.asid_cnt);
    for (unsigned int i = 0; i < cap.asid_cnt && i < 4; i++)
        printf("  asid%u base   : 0x%llx\n", i, (unsigned long long)cap.asid_base[i]);
    printf("ISA version     : %u (%s)\n", cap.partition_cap.version, isa_name(cap.partition_cap.version));
    printf("partition #0    : arch=0x%x config=0x%x clusters=%u\n", cap.partition_cap.arch,
           cap.partition_cap.config, cap.partition_cap.cluster_cnt);
    for (unsigned int c = 0; c < cap.partition_cap.cluster_cnt && c < 8; c++)
        printf("  cluster %u     : cores=%u enabled=%u TECs/core=%u\n", c,
               cap.partition_cap.clusters[c].core_cnt, cap.partition_cap.clusters[c].en_core_cnt,
               cap.partition_cap.clusters[c].tec_cnt);
    printf("gm0/gm1 size    : %u / %u bytes\n", cap.gm0_size, cap.gm1_size);

    close(fd);
    return 0;
}
