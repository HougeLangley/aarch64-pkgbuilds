# aarch64-pkgbuilds

OrionO6 (Arch Linux ARM, aarch64) 自维护软件包集合。每个子目录以**包名**命名，包含完整 PKGBUILD 及构建所需全部支持文件。

> 构建目标：Radxa Orion O6（CIX CD8180 / Cortex-A720+A520），Arch Linux ARM。

## 包列表

| 包 | 版本 | 说明 | 更新方式 |
|---|---|---|---|
| `linux-aarch64-rt` | 7.2.2-2 | RT 实时内核：PREEMPT_RT + sched-ext + BTF + FTRACE，Clang/LLVM + ThinLTO 编译 | 跟随 ALARM linux-aarch64 pkgver |
| `obsidian` (appimage) | 1.13.7-1 | Obsidian 笔记软件（arm64 AppImage 版），desktop 文件名自动探测 | 跟随 GitHub releases（跳过移动-only 发布） |
| `flclash-bin` | 0.8.96-1 | FlClash 代理客户端（aarch64 启用），quickjs 桥接仅 x86_64 | 跟随 GitHub releases |

## 使用方式

### 安装

每个包目录内含完整 PKGBUILD，直接：

```bash
git clone https://github.com/HougeLangley/aarch64-pkgbuilds.git
cd aarch64-pkgbuilds/linux-aarch64-rt   # 或 obsidian / flclash-bin
makepkg -si
```

### 各包构建依赖

```bash
# linux-aarch64-rt（内核编译，约 90 分钟，需要 LLVM 工具链）
sudo pacman -S --needed base-devel clang llvm lld pahole xmlto docbook-xsl kmod inetutils bc git dtc python
# obsidian / flclash-bin（二进制重打包，秒级）
sudo pacman -S --needed base-devel
```

### 注意事项

- **linux-aarch64-rt** 与官方 linux-aarch64 共存安装过，但当前系统仅安装 RT 内核（单内核无回退，用户确认方案）。GRUB 默认条目已锁定 RT。
- **linux-aarch64-rt 的 config-rt** 基于 ALARM 官方 config 改造：`PREEMPT_RT=y`、`SCHED_CLASS_EXT=y`、`DEBUG_INFO_BTF=y`、`CONFIG_FTRACE` 家族、`LTO_CLANG_THIN=y`。FTRACE 是 scx 调度器的硬依赖（ALARM 默认关闭）。
- **obsidian** 的 PKGBUILD 内含 desktop 文件名**动态探测**补丁（上游 1.13.7 起 desktop 文件名从 `obsidian.desktop` 改为 `md.obsidian.Obsidian.desktop`，AUR 原包未跟进）。
- **flclash-bin** 的 aarch64 支持为本仓库新增（AUR 原版仅 x86_64）：官方 arm64 deb + 官方 SHA256SUMS 校验；`libquickjs_c_bridge_plugin.so` 仅 x86_64 提供（AUR 维护者的二进制补丁），arm64 缺省不影响主体功能。
- **obsidian / flclash-bin 安装后即生效；linux-aarch64-rt 需要重启**（GRUB 菜单选 `Arch Linux, with Linux linux-aarch64-rt`）。

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
