# NPU 驱动运维手册（Orion O6 / CIX P1 Zhouyi V3）— 内核更新时怎么办

**现状（2026-11-28）**：`sky1-zhouyi-v3-driver-dkms 6.2.0-2`，pin 的是 fork `Reonarudo/sky1-zhouyi-v3-driver@f91f8dd`（基于 cixtech `p1_7.0_v6.2.0` / 分支 `cix_mainline_upstream_dev`）。本地 devfreq 补丁已在 pkgrel 2 删除——fork 自 `85db667` 起 devfreq 运行时可选。

## 1. 内核升级时自动发生什么

| 步骤 | 由谁做 | 条件 |
| --- | --- | --- |
| 新内核 + `linux-aarch64-headers` 安装 | pacman（`linux-aarch64` 升级时通常一起） | headers 必须与新内核**同版本** |
| DKMS 为新内核重建 `aipu.ko` | pacman hook `70-dkms-install.hook` / `70-dkms-upgrade.hook` → `dkms install`/`autoinstall` | 需 `base-devel`、`gcc`、headers |
| 开机加载 | `/usr/lib/modules-load.d/aipu.conf` + udev modalias `acpi:CIXH4000` | — |

任何一环失败，**重启后 NPU 就没了**（`/dev/aipu` 不存在，`lsmod | grep aipu` 为空）。

## 2. 每次内核升级/重启后：跑自检（免 root）

```bash
~/src/cix-npu/pkgbuilds/sky1-zhouyi-v3-driver/npu-driver-check.sh            # 健康检查，exit 0 = 健康
~/src/cix-npu/pkgbuilds/sky1-zhouyi-v3-driver/npu-driver-check.sh --upstream # 另查 fork 是否有新提交
```
检查项：headers 与内核同版本、dkms+hooks、源码树、当前内核的 aipu.ko 已构建、vermagic 匹配、已加载、`/dev/aipu`、开机自加载、dmesg 探测日志。

## 3. 常见故障与处置

| 症状 | 原因 | 处置 |
| --- | --- | --- |
| `FAIL headers for <kver> missing` | headers 没跟内核一起升 | `doas pacman -S linux-aarch64-headers`，然后 `doas dkms autoinstall` |
| `not built for <kver>`，看 `/var/lib/dkms/zhouyi-aipu/*/make.log` | 新内核 API 变化导致编译失败（最常见的"需要持续更新"场景） | 看 make.log 的第一个 error；对照 fork 的 `cix_mainline_upstream_dev` 适配层（`driver/armchina-npu/sky1/`、`oslayer/linux/`）；通常是几个内核 API 改名（如 `class_create`、`strlcpy`、`timer`、`dma_map` 签名） |
| 模块构建了但没加载 | `modprobe aipu` 报错或 dmesg 有 probe 失败 | `dmesg | grep -i aipu`；当前固件下会看到 `devfreq unavailable (-17), continuing without it` 这是**正常** |
| 开机不加载 | modules-load.d 文件丢失 | `pacman -Qkk sky1-zhouyi-v3-driver-dkms` 查文件；重装 |
| NPU 挂死 / 任务不完成 | 回到了 stock 驱动的 job-completion 问题 | 确认 `dmesg | grep 'AIPU KMD'` 的版本是 fork（`v6.2.0.r<commit>`），不是 stock |

## 4. 跟进上游 fork 的新提交

1. `npu-driver-check.sh --upstream` 看 fork HEAD 是否比安装的新。
2. 读 fork 提交说明（devfreq、packaging、job completion 修复等），决定是否升级。
3. 改 `PKGBUILD`：`_fork=<短 sha>`、`source=...#commit=<全 sha>`、`pkgrel+=1`；`makepkg -f`（本机原生构建，无需交叉工具链）。
4. `doas pacman -U sky1-zhouyi-v3-driver-dkms-*.pkg.tar.*`（nopass；DKMS hooks 自动重建）。
5. 换掉正在跑的旧模块：`doas modprobe -r aipu && doas modprobe aipu`（或重启），然后跑 `npu-driver-check.sh` + 一次 NPU 探测（`~/src/npu-vllm/probe_zhouyi.py`，见下）。
6. 本仓库 `git commit`；推送到 `HougeLangley/aarch64-pkgbuilds`（需 GitHub token）。

cixtech 上游若发布新 tag（当前 `p1_7.0_v6.2.0`）或新分支，优先看 fork 是否已 rebase；未 rebase 时再评估 stock 分支是否已包含 job-completion / 中断掩码修复（历史上 stock 6.2.0 会让所有 tinygrad 任务挂死）。

## 5. 回滚

旧版 pkgrel 1 的 PKGBUILD 在本仓库 git 历史（提交 `a0c790d`）；`git checkout a0c790d -- sky1-zhouyi-v3-driver/ && makepkg -f && doas pacman -U ...`。或临时禁用：`doas pacman -R sky1-zhouyi-v3-driver-dkms`（NPU 不可用，系统不受影响）。

## 6. NPU 功能探测（驱动换了之后必跑）

```bash
cd ~/src/npu-vllm && export TG=$PWD/src/tinygrad-zhouyi DEV=ZHOUYI \
  ZHOUYI_TOOLCHAIN_DIR=$PWD/src/apt_cix_trixie/x_cix-npu-onnxruntime_2.0.0_arm64/usr/share/cix/lib/onnxruntime \
  LIBCLANG_PATH=/usr/lib/libclang.so ZHOUYI_AIPU_HEADER=/usr/include/misc/armchina_aipu.h
env-tg/bin/python probe_zhouyi.py     # 期望末行 PROBE_OK，max|err|=0
```

## 7. 文件位置

| 项 | 路径 |
| --- | --- |
| PKGBUILD / dkms.conf / aipu.conf / 自检脚本 | `~/src/cix-npu/pkgbuilds/sky1-zhouyi-v3-driver/` |
| DKMS 源码树 | `/usr/src/zhouyi-aipu-6.2.0.r<commit>/` |
| DKMS 构建日志 | `/var/lib/dkms/zhouyi-aipu/<ver>/<kernel>/make.log` |
| 模块 | `/lib/modules/<kver>/updates/dkms/aipu.ko` |
| UAPI 头（用户态，tinygrad 用） | `/usr/include/misc/armchina_aipu.h` |
| 开机加载 | `/usr/lib/modules-load.d/aipu.conf` |
| 开关 | BIOS：Device Manager → Platform Configuration → *Enable ACPI SCMI*（打开后 devfreq 可用，可调 NPU 频率；关闭则固定固件时钟） |
