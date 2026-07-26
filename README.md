# OpenWorker 中文汉化（Windows 版）

为 [OpenWorker](https://github.com/andrewyng/openworker) 桌面端提供完整中文界面汉化，适用于 Windows 10 / 11（x64）。

汉化以**独立补丁层**实现：翻译引擎在页面加载前注入到 Tauri WebView，按词表实时把英文界面文字替换为中文。它不修改原软件的业务逻辑，因此**本体升级后只需重新运行一次构建脚本即可同步新版本**，已翻译的内容不会丢失。

---

## 特性

- **全界面中文**：DOM 级实时替换，覆盖绝大多数界面文字（侧边栏、设置、对话、自动化、连接器等）。
- **与本体分离**：汉化是叠加在官方源码上的补丁，升级 OpenWorker 后重新构建即可，无需重复翻译。
- **一键构建**：自动检测编译环境 → 克隆指定版本源码 → 注入汉化 → 复制后端 sidecar → 编译并打包安装包。
- **语音输入自动降级**：Windows 上 `whisper` 语音模块编译困难时，构建脚本会自动切换为「关闭语音输入」版本，文字汉化不受影响。

---

## 目录结构

```
.
├── patch/                    # 汉化补丁源码（开发文件）
│   ├── zh-CN.json            # 中英词表（翻译的源数据，维护它即可）
│   ├── zh-CN-inject.js       # DOM 翻译引擎（注入到 Tauri 初始化脚本）
│   ├── inject_to_init.py     # 将翻译引擎写入 src-tauri/src/lib.rs
│   ├── regen_dict.py         # 从 zh-CN.json 重新生成 zh-CN-inject.js 词表
│   ├── disable_stt.py        # 语音模块降级桩（编译失败时自动启用）
│   ├── build_zh.ps1          # 主构建脚本（PowerShell）
│   └── 一键编译中文版.bat     # Windows 启动器（双击即用）
│
├── openworker/               # OpenWorker 上游源码（构建时自动克隆，不纳入版本库）
├── dist/                     # 编译产物安装包（通过 GitHub Release 发布，不纳入版本库）
│
├── LICENSE
├── README.md
└── .gitignore
```

---

## 快速使用（普通用户）

1. 进入本仓库的 **Releases** 页面，下载 `OpenWorker_0.1.6_x64-setup.exe`。
2. 双击安装，流程与安装普通 Windows 软件一致。
3. 启动 OpenWorker 后即可看到中文界面。

> 若你只是想用中文版，不需要克隆本仓库源码，直接下载 Release 里的安装包即可。

---

## 从源码构建（贡献者 / 版本更新）

### 前置环境

构建需要以下工具链全部就绪，缺一不可：

| 工具 | 说明 | 获取方式 |
|------|------|----------|
| Rust（stable + MSVC） | 编译 Tauri 后端 | https://rustup.rs （安装时选 MSVC） |
| Node.js LTS（20+） | 编译前端 | https://nodejs.org |
| Python 3.10+ | 运行注入脚本 | https://python.org |
| Visual Studio 2022 | C++ 编译器（cl.exe） | 安装器选「桌面开发 with C++」工作负载 |
| CMake | 构建依赖 | VS2022 勾选「C++ CMake 工具」，或 `winget install Kitware.CMake` |
| LLVM / libclang | bindgen 需要 | VS2022 勾选「C++ Clang 工具」，或 `winget install LLVM.LLVM` |

此外，构建时需要本机已安装一份官方 OpenWorker（用于复制后端 `sidecar` 文件夹），构建脚本会自动在常见路径中查找，找不到时会提示你手动输入。

### 构建步骤

1. 双击 `patch\一键编译中文版.bat`。
2. 脚本依次自动完成：
   - 检测并加载 VS C++ 环境；
   - 克隆 / 重置 OpenWorker 指定版本源码；
   - 从 `zh-CN.json` 同步词表，并注入汉化引擎到 `lib.rs`；
   - 复制官方安装的 `sidecar` 后端；
   - 编译并打包 NSIS 安装包。
3. 安装包生成在 `dist\`，或 `openworker\surfaces\gui\src-tauri\target\release\bundle\nsis\`。

### 命令行构建（可选）

```powershell
cd patch
powershell -ExecutionPolicy Bypass -File build_zh.ps1
```

---

## 如何更新到新版本

当 OpenWorker 发布新版本（例如 `v0.1.7`）时：

1. 编辑 `patch\build_zh.ps1`，把其中的分支版本号
   ```powershell
   git clone --branch v0.1.6 --recurse-submodules ...
   ```
   改为新版本，例如 `v0.1.7`。
2. 若新界面出现了未翻译的英文文字，编辑 `patch\zh-CN.json` 补充对应词条
   （格式：`"English text": "中文"`），然后运行：
   ```powershell
   cd patch
   python regen_dict.py
   ```
   该脚本会把词表重新写入 `zh-CN-inject.js`。
3. 重新双击 `一键编译中文版.bat` 构建。
4. 在 GitHub 发布新的 Release，上传生成的 `OpenWorker_<版本>_x64-setup.exe`。

> 词表是翻译的唯一数据源。直接改 `zh-CN.json` 即可，不需要手动编辑 `zh-CN-inject.js`。

---

## 自定义 / 修正翻译

- **补充或修正某条翻译**：编辑 `patch\zh-CN.json`，运行 `python patch\regen_dict.py`，重新构建。
- **某条不希望被翻译**：从 `zh-CN.json` 删除该词条即可。
- 翻译引擎对「精确匹配的整段文字」生效；动态拼接或来自 API 的文本（如第三方集成名称）可能不会被翻译，这是已知限制。

---

## 注意事项 / 已知问题

以下是在 Windows 上构建与使用时容易遇到的问题，已在本项目中处理或规避，列出供参考：

1. **编译环境必须齐全**：Rust / Node / Python / VS2022 C++ / CMake / libclang 任一缺失都会导致构建失败。脚本会在第一步逐一检测并给出提示。
2. **项目路径不要含中文或空格**：构建脚本运行时会自动把整个项目复制到纯英文路径 `E:\ow-zh-build` 再编译；你也可以一开始就放在如 `D:\openworker-cn` 这样的纯英文路径下。
3. **后端 sidecar 路径必须正确**：安装包内部已正确打包 sidecar。若你直接运行裸 `exe`，必须保证 `sidecar` 文件夹与 `exe` 在**同一级目录**，且**不能多嵌套一层**（例如 `exe` 旁边应是 `sidecar\...`，而不是 `sidecar\sidecar\...`）。早期版本曾因路径多嵌套一层导致程序卡在启动画面。
4. **汉化注入方式**：翻译引擎必须注入到 Tauri 的初始化脚本（页面加载前执行），这样才能在 React 渲染前及渲染过程中持续生效。这是汉化能够真正显示出来的关键，请勿改为其他注入时机。
5. **NSIS 打包偶尔失败**：多数情况与 sidecar 路径有关。构建脚本在检测到打包失败时会自动回退重试；最终即使只有裸 `exe` 也能用（旁边放好 `sidecar` 文件夹即可）。
6. **语音输入（STT）在 Windows 上编译困难**：`whisper` 依赖在 Windows 原生编译极容易失败，脚本会自动降级为「关闭语音输入」的版本。**文字汉化完全不受影响**，仅语音转文字功能不可用。
7. **不要用「精确字符串替换」方案**：另一种常见的汉化思路是对源码做精确字符串替换（即 Mac 版做法），但 OpenWorker 前端文字分散、且经过构建压缩，覆盖率极低（实测约 10%），不建议采用。
8. **更新不丢翻译**：因为翻译是独立补丁层，本体升级只需重新构建，已维护的词表会一直沿用。

---

## 许可证

本项目采用 **MIT License**，详见 [LICENSE](./LICENSE)。

本汉化基于 OpenWorker 上游源码（MIT, © Andrew Ng）构建，致谢原项目。

## 致谢

- OpenWorker 原项目：<https://github.com/andrewyng/openworker>
