# Optional hardware setup

AMD Radeon, NVIDIA, and Intel graphics expose different information through
different tools. When a reading is missing, the plugin can use an installed tool
for that hardware to fill the gap. Installing one does not guarantee every
reading: some GPUs do not expose a separate temperature or dedicated video
memory.

Follow only the sections that match your hardware. On a mixed-GPU system, each
card can use a different source. The plugin detects tools automatically and
never installs packages or changes permissions itself. After setup, allow about
30 seconds for discovery and retries, or restart the shell:

```bash
omarchy restart shell
```

With multiple GPUs, the popup shows usage for the default OpenGL renderer when
Fastfetch can match it to exactly one device. The tooltip still lists every GPU;
an ambiguous renderer leaves the popup showing the GPU count.

Run the verification commands below as your normal desktop user, without `sudo`.
A command that only works as root will not work inside the plugin. The tooltip
and btop's own GPU panel use separate readers; installing a tool for the tooltip
does not necessarily enable the same readings inside btop.

## CPU, RAM, and standard GPU readings

No additional installation is needed for CPU/RAM usage. Temperatures depend on
the sensors your kernel exposes; missing sensors stay `--` rather than being
replaced by another component's temperature.

Fastfetch supplies GPU names and additional readings where supported. It is
already part of Omarchy; if you previously removed it, restore it with:

```bash
sudo pacman -S --needed fastfetch
```

The plugin also reads available Linux GPU counters directly. These paths need no
vendor monitoring package.

## AMD Radeon GPUs: ROCm SMI

With the `amdgpu` driver, Linux may already expose usage, temperature, and VRAM.
For missing readings, and for AMD support in btop's own GPU panel, install ROCm
SMI:

```bash
sudo pacman -S --needed rocm-smi-lib
/opt/rocm/bin/rocm-smi --showbus --showuse --showtemp --showmeminfo vram --json
```

Restart btop if it was open during installation. On our Radeon RX 6400, this
read-only command works without extra permissions. Removing ROCm SMI leaves the
plugin's kernel-provided readings working. That result does not guarantee the
same coverage on every AMD model.

If the command reports GPU-access permission errors, check the device access
described under [AMD SMI](#amd-gpus-alternative-amd-smi) below. Installing the
monitoring tool does not replace or repair the graphics driver.

## AMD GPUs: alternative AMD SMI

The plugin also supports `amd-smi`, supplied by Arch's
[`amdsmi` package](https://archlinux.org/packages/extra/x86_64/amdsmi/files/).
It is an alternative source for usage, temperature, and VRAM on supported
`amdgpu` devices. You do not need both AMD tools when your readings already
work.

```bash
sudo pacman -S --needed amdsmi
/opt/rocm/bin/amd-smi list --json
/opt/rocm/bin/amd-smi metric --json -u -t -m
```

If it reports missing `render`/`video` groups or denied GPU-device access, an
administrator can grant the standard
[AMD GPU access groups](https://rocm.docs.amd.com/projects/radeon-ryzen/en/latest/docs/install/installrad/native_linux/install-radeon.html):

```bash
sudo usermod -aG render,video "$USER"
```

Log out of the desktop completely and log back in before retrying. This grants
GPU-device access to your account, not just to this plugin. Do not add groups if
the queries already work. AMD SMI also needs a compatible GPU and driver;
permissions cannot make an unsupported device work. This backend is implemented
but has not been hardware-tested here.

## Intel integrated graphics using i915

For Intel graphics using the `i915` driver, the plugin can read usage through
`intel_gpu_top`:

```bash
sudo pacman -S --needed intel-gpu-tools
intel_gpu_top
```

Press Ctrl+C to exit the tool. If it reports `Permission denied` or requests
`CAP_PERFMON`, grant that capability specifically to its executable:

```bash
sudo setcap cap_perfmon=ep /usr/bin/intel_gpu_top
getcap /usr/bin/intel_gpu_top
```

The last command should show `cap_perfmon=ep`. This permits access to
[performance counters](https://www.kernel.org/doc/html/latest/admin-guide/perf-security.html)
without running the tool as root. Reinstalling or upgrading the package can
remove the capability; check and reapply it if usage disappears.

We verified this setup on two Intel Haswell systems, including removing and
reinstalling the package. This reader supplies usage, not GPU temperature.
Integrated graphics can share system RAM with the CPU instead of having
dedicated VRAM. The plugin currently selects this CLI only for `i915`, not `xe`.

For Intel usage, the source order is a kernel `gpu_busy_percent` counter,
`intel_gpu_top` on i915, Fastfetch, XPU-SMI, and finally DRM `fdinfo`. Missing
or failed readers are skipped. The `fdinfo` fallback covers only clients visible
to the current user and may not represent the whole device. Btop's own GPU panel
uses an embedded i915 PMU reader. Any `CAP_PERFMON` granted to the btop
executable applies only to btop and cannot be reused by the plugin.

## NVIDIA GPUs

On supported NVIDIA systems, Omarchy normally installs `nvidia-smi` with the
graphics driver utilities. It can supply usage, temperature, and VRAM. Check
whether it already works:

```bash
nvidia-smi
```

If you use the current NVIDIA driver branch and its utilities are missing:

```bash
sudo pacman -S --needed nvidia-utils
```

[`nvidia-utils` includes `nvidia-smi`](https://archlinux.org/packages/extra/x86_64/nvidia-utils/files/).
The utilities must match your installed driver branch. For example, a legacy
`nvidia-580xx` installation needs its matching `nvidia-580xx-utils` package, not
a blind switch to `nvidia-utils`. Follow your driver setup if the command
reports a driver/library mismatch or cannot communicate with the GPU.

No Intel-style `CAP_PERFMON` setup is normally needed for these
[read-only NVIDIA queries](https://docs.nvidia.com/deploy/nvidia-smi/index.html).
The plugin does not use `nvidia-smi` with Nouveau, and a working CLI still may
report unsupported fields. This backend has not been hardware-tested here.

## Intel discrete and data-center GPUs: XPU-SMI (experimental)

An additional `xpu-smi` adapter is implemented for Intel GPUs supported by that
tool. It can supply usage, temperature, and memory, but it is not a general
upgrade for older Intel integrated graphics.

This is not yet a verified Arch/Omarchy installation recipe. As checked on
2026-09-05, the AUR's
[`xpu-smi-bin` package](https://aur.archlinux.org/packages/xpu-smi-bin) is
orphaned, flagged out of date, and still at version 1.2.35. We do not recommend
installing that package blindly just to fill a missing tooltip value.

A working installation needs the matching Intel GPU driver, Level Zero loader
and GPU compute runtime, and the dependencies required by its XPU-SMI version.
Follow
[Intel's installation guidance](https://github.com/intel/xpumanager#how-to-get-xpu-manager)
for your device and release. Once `xpu-smi` is installed and available on the
desktop session's `PATH`, verify it as your normal user:

```bash
xpu-smi discovery -j
xpu-smi discovery -d 0 -j
xpu-smi stats -d 0 -j
```

Replace `0` with a device listed by discovery. Successful discovery alone is not
enough: statistics must also be readable without root. If access is denied,
follow that release's device-permission guidance; do not assume the
`intel_gpu_top` capability command applies here. We have not verified this
backend's installation, permissions, or live readings on suitable hardware.
