# aarch64-pkgbuilds

OrionO6 (Arch Linux ARM, aarch64) 自维护软件包集合。每个子目录以**包名**命名，包含完整 PKGBUILD 及构建所需全部支持文件。

> 构建目标：Radxa Orion O6（CIX CD8180 / Cortex-A720+A520），Arch Linux ARM。

## 包列表

| 包 | 版本 | 说明 | 更新方式 |
|---|---|---|---|
| `linux-aarch64-rt` | 7.2.2-2 | RT 实时内核：PREEMPT_RT + sched-ext + BTF + FTRACE，Clang/LLVM + ThinLTO 编译 | 跟随 ALARM linux-aarch64 pkgver |
| `obsidian` (appimage) | 1.13.7-1 | Obsidian 笔记软件（arm64 AppImage 版），desktop 文件名自动探测 | 跟随 GitHub releases（跳过移动-only 发布） |
| `flclash-bin` | 0.8.96-1 | FlClash 代理客户端（aarch64 启用），quickjs 桥接仅 x86_64 | 跟随 GitHub releases |
| `cix-npu-driver` (`-dkms` + `-uapi-headers`) | 6.2.0-1 | Orion O6 NPU（ArmChina Zhouyi Z3，3 核 × 4 TEC）内核驱动 `aipu.ko`，DKMS 随内核自动重编；源码取自 fork 的 tag `p1_7.0_v6.2.0`（= 上游 `cix_mainline_upstream_dev`） | 跟随上游 `cix_mainline_upstream_dev` 分支 / tag |

## 使用方式

### 安装

每个包目录内含完整 PKGBUILD，直接：

```bash
git clone https://github.com/HougeLangley/aarch64-pkgbuilds.git
cd aarch64-pkgbuilds/linux-aarch64-rt   # 或 obsidian / flclash-bin / cix-npu-driver
makepkg -si
```

### 各包构建依赖

```bash
# linux-aarch64-rt（内核编译，约 90 分钟，需要 LLVM 工具链）
sudo pacman -S --needed base-devel clang llvm lld pahole xmlto docbook-xsl kmod inetutils bc git dtc python
# obsidian / flclash-bin（二进制重打包，秒级）
sudo pacman -S --needed base-devel
# cix-npu-driver（DKMS 源码包，打包秒级；dkms 在 pacman hook 里编译模块，约 1 分钟）
sudo pacman -S --needed base-devel git linux-aarch64-headers dkms
```

### 注意事项

- **linux-aarch64-rt** 与官方 linux-aarch64 共存安装过，但当前系统仅安装 RT 内核（单内核无回退，用户确认方案）。GRUB 默认条目已锁定 RT。
- **linux-aarch64-rt 的 config-rt** 基于 ALARM 官方 config 改造：`PREEMPT_RT=y`、`SCHED_CLASS_EXT=y`、`DEBUG_INFO_BTF=y`、`CONFIG_FTRACE` 家族、`LTO_CLANG_THIN=y`。FTRACE 是 scx 调度器的硬依赖（ALARM 默认关闭）。
- **obsidian** 的 PKGBUILD 内含 desktop 文件名**动态探测**补丁（上游 1.13.7 起 desktop 文件名从 `obsidian.desktop` 改为 `md.obsidian.Obsidian.desktop`，AUR 原包未跟进）。
- **flclash-bin** 的 aarch64 支持为本仓库新增（AUR 原版仅 x86_64）：官方 arm64 deb + 官方 SHA256SUMS 校验；`libquickjs_c_bridge_plugin.so` 仅 x86_64 提供（AUR 维护者的二进制补丁），arm64 缺省不影响主体功能。
- **obsidian / flclash-bin 安装后即生效；linux-aarch64-rt 需要重启**（GRUB 菜单选 `Arch Linux, with Linux linux-aarch64-rt`）。
- **cix-npu-driver 的分支选型**（在 Orion O6 / SKY1 EDK2 固件 / UEFI+ACPI 启动 / ALARM 主线内核 7.3.6 上实测）：上游 `cix_k6.6.89_*` 与 `cix_p1_k6.6_master` 只服务 CIX 自家 6.6.89 下游内核；`cix_mainline_upstream_dev`（tag `p1_7.0_v6.2.0`）的 `sky1.c` 同时带 ACPI HID `CIXH4000`（`_SB_.NPU0`）匹配和 ≥7.0 内核的 API 适配（`pm_runtime_put` 返回 void），是主线内核**唯一可用**的分支；`cix_mainline_dev` 的驱动代码与它完全一致，只多了 Debian 打包目录。
- **cix-npu-driver 为什么关掉 devfreq**：O6 的 EDK2 固件在 ACPI 表里**没有描述 SCMI 设备**（22 个 `PRP0001` 节点全是 DDR ctrl / ramoops / regulator / LED），主线内核上 `/sys/bus/scmi_protocol/devices` 为空；而驱动的 devfreq 初始化依赖 SCMI perf 域并把失败当致命错误。因此包内 `dkms.conf` 以 `BUILD_NPU_DEVFREQ=n` 覆盖上游，NPU 核心跑固件默认时钟。
- **cix-npu-driver 安装后即生效**：模块带 `acpi:CIXH4000` alias，udev 按 modalias 开机自动加载（已用 `udevadm trigger` 实测），不需要 `modules-load.d`；设备节点 `/dev/aipu`（misc 10:258）权限 0666。验证：`dkms status` / `lsmod | grep aipu` / `ls -l /dev/aipu` / `dmesg | grep -i aipu`。sysfs 接口在 `/sys/devices/platform/CIXH4000:00/{ext_registers,gm_policy,wakeup}`。
- **cix-npu-driver 的上游同步**：`https://github.com/HougeLangley/cix_opensource__npu_driver` fork 的 7 条分支与 `cixtech` 上游逐 SHA 对齐（`cix_mainline_dev` 顶部保留本仓库的 COPR/RPM 打包提交），升级时改 PKGBUILD 里的 `_tag` 即可。

## 自动更新

三个包均有 Hermes cron 监控（本机）：

| 包 | 行为 |
|---|---|
| obsidian | 每 12h 检查 → 自动改 PKGBUILD → makepkg → pacman -U → Telegram 通知 |
| linux-aarch64-rt | 每 24h 检查 ALARM 上游 → 自动构建安装 → **Telegram 通知重启**（重启由用户手动执行） |
| flclash-bin | 每 12h 检查 GitHub releases → 自动构建安装 → Telegram 通知 |

## 构建日志

- obsidian: `~/.hermes/logs/obsidian-update.log`
- 内核: 构建目录 `~/vllm/kernel-rt/`

## License

各包遵循其上游项目的 license（PKGBUILD 内声明）。
