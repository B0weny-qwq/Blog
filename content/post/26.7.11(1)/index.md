这一系列想从 Zephyr 入门开始，补上之前一直想写却没动笔的内容。

# Lesson 1: 认识 Zephyr 工程

Zephyr 是一个面向资源受限设备的开源实时操作系统（RTOS）。它有线程、调度和同步这些内核能力，但它想管的不只是“任务怎么调度”：驱动、硬件描述、配置、板级支持和构建流程也被放进了同一套体系。

先想一个最常见的练习：每隔一秒翻转一次 LED。用 FreeRTOS 时，任务里的延时可以写成 `vTaskDelay()`；但 LED 在哪个引脚、GPIO 时钟怎样开、引脚怎样初始化，仍要由 STM32 HAL、TI DriverLib 或其他厂商库处理。任务代码可以不变，换一块板后，`HAL_GPIO_TogglePin(GPIOC, GPIO_PIN_13)` 这类外设代码和初始化往往还是得跟着改。

Zephyr 希望把这部分差异挪到应用代码之外。应用更接近下面这种写法：

```c
static const struct gpio_dt_spec led = GPIO_DT_SPEC_GET(DT_ALIAS(led0), gpios);

gpio_pin_toggle_dt(&led);
```

这里没有出现 `GPIOC` 或 `PIN_13`。应用只说“切换这块板的默认 LED”；`led0` 到底接在哪个 GPIO 控制器、哪个引脚，以及应该选用哪一个 GPIO 驱动，由开发板的设备树和 Kconfig 配置决定。换到另一块已支持、也提供 `led0` 的板时，这段闪灯逻辑可以保持不动，只需要重新选择目标板构建。

这不是魔法，也不是硬件差异消失了。可以把设备树看成一张接线和设备清单：它把“LED 接在 P0.13”这样的事实放在板级描述里，而不是散落在应用业务代码中。DMA、低功耗、特殊时钟等功能仍然要面对具体芯片的能力和限制；只是普通应用不必反复触碰同一组寄存器和引脚号。

这也是 Zephyr 值得学习、同时需要先熟悉工程体系的原因。它适合 MCU、传感器节点、可穿戴设备等需要实时性和较小资源占用的场景，也覆盖了从小型开发板到部分带 MMU 的平台。刚接触时，最容易困惑的往往不是 API，而是应用、配置、设备树和驱动究竟怎样配合。

这一课先不急着读内核。先建立整体印象：一份闪灯应用从哪些文件得到“这块板有什么”，又如何变成可以烧录的固件。理解了这条线，再回头读线程和调度会顺得多。

## 1. 先看整个工作区

用 West 初始化后的工作区通常长这样：

```text
workspace/
├── .west/                  West 工作区配置
├── zephyr/                 Zephyr RTOS 源码
├── modules/                第三方模块，例如 CMSIS、芯片 HAL
└── my-application/         自己的应用工程
```

可以把这个目录想成一个项目工地：`my-application` 是你正在写的产品代码，`zephyr` 是公共框架和基础设施，`modules` 放着芯片厂商和第三方提供的零件。Zephyr SDK 不在工地里，它安装在开发电脑上，提供交叉编译器、链接器等工具；它不属于 Zephyr 源码，也不会被烧录进开发板。

刚开始最值得盯住的是两处：

```text
my-application/            应用代码、应用配置、设备树覆盖
zephyr/                    RTOS、驱动、设备树、板级支持和构建规则
```

`west`、SDK 和 `modules/hal/<vendor>/` 当然都重要，但前期不需要急着读实现。它们的作用分别是管理多个仓库、提供工具链，以及承载厂商 HAL；应用通常会通过 Zephyr 的驱动间接使用这些 HAL。

## 2. West 到底负责什么

Git 管理单个仓库的历史，West 管理的是一组彼此有依赖关系的仓库。可以把它理解为项目的“装配清单”：`zephyr/west.yml` 记录 CMSIS、芯片 HAL 等模块该放在哪里、要使用哪个版本。执行：

```bash
west update
```

West 会把工作区同步到清单指定的状态。比如同一个 Zephyr 版本需要某个版本的 STM32 HAL，`west update` 会按清单取回匹配版本，避免每个人手动拼一套不兼容的仓库。它还把构建、烧录和调试入口统一起来：

```bash
west build -b <board> <application-directory>
west flash
west debug
```

不过 West 本身不编译 C 代码。真正干活的是 Zephyr 的 CMake 构建系统、构建工具和交叉编译器；West 更像是把这些步骤组织到同一个命令入口下。

## 3. 一份应用怎样变成固件

还是以闪灯程序为例。`main.c` 只写“翻转 LED”，但编译器还不知道这颗 LED 接在哪里、GPIO 驱动要不要编进去。应用代码并不是直接丢给编译器，而是先经过配置和硬件描述的合并：

```text
src/main.c
          |
          v
CMakeLists.txt
  find_package(Zephyr ...): 引入 Zephyr 构建系统
  target_sources(...):      将应用源文件加入 app 目标
          |
          v
prj.conf
  选择需要的 Kconfig 功能，例如 GPIO、日志、线程
          |
          v
板级 DTS + SoC DTSI + 应用 overlay
  描述目标硬件，以及应用对硬件描述的修改
          |
          v
生成最终设备树、最终 Kconfig 和设备树 C 宏
          |
          v
交叉编译并链接
          |
          v
zephyr.elf / zephyr.bin
```

构建目录不是可以完全忽略的临时垃圾，它像是构建系统交卷前留下的草稿。比如你把 `led0` 指到另一个引脚，却发现灯没有变化；这时先看最终合并出的设备树，而不是靠猜。遇到“明明改了配置却没生效”这类问题，也先来这里确认：

```text
build/zephyr/zephyr.dts
    最终合并后的设备树。

build/zephyr/.config
    最终生效的 Kconfig 配置。

build/zephyr/include/generated/devicetree_generated.h
    设备树生成的 C 宏。
```

## 4. Zephyr 和 Zephyr SDK 别混在一起

```text
Zephyr：      会被编译进目标设备的 RTOS、驱动和板级支持源码。
Zephyr SDK：  在开发主机上执行编译、汇编、链接和二进制转换的工具链。
```

它们之间的关系可以简单理解为：

```text
应用源码 + Zephyr 源码
          |
          |  Zephyr SDK 提供交叉编译器、链接器等工具
          v
zephyr.elf / zephyr.bin
          |
          v
烧录到目标开发板并运行
```

所以日常开发主要修改应用源码、`prj.conf` 和设备树；SDK 通常只在安装、升级或排查工具链问题时才需要关注。

## 5. `zephyr/` 目录该从哪儿看

```text
kernel/             线程、调度、定时器、同步机制
drivers/            GPIO、UART、I2C、SPI 等驱动框架
boards/             开发板定义
soc/                芯片和 SoC 支持
dts/                通用设备树定义与 bindings
include/zephyr/     应用可包含的 API 头文件
cmake/、scripts/    构建和代码生成规则
```

第一次打开 `zephyr/` 时很容易被目录数量劝退。不建议马上扎进 `kernel/`：先从自己的 `main.c` 出发，找到它使用的 `led0`，再看它在最终设备树里落到了哪个 GPIO。等这条“代码如何落到硬件上”的路走通，再读内核时，看到的就不再是一堆孤立文件。

## 6. Zephyr 能支持哪些硬件

Zephyr 不是给任意 MCU 都能直接编译运行的通用库。把一个 STM32 的应用拿去给一颗新的 Cortex-M 芯片编译，并不因为两者都是 Cortex-M 就会成功。要支持一颗芯片，架构、SoC、开发板定义、设备树 binding、驱动和工具链必须一起就位：

```text
应用代码
  |
Zephyr 通用 API
  |
驱动 + 设备树 binding
  |
SoC 支持 + 启动代码 + 中断/时钟/内存配置
  |
具体 MCU 硬件
```

这有点像两辆车都使用同一款发动机，并不代表仪表、线束和控制器可以直接互换。判断某个 MCU 是否受支持，不能只看它是不是 Cortex-M；外设、时钟、中断控制器、内存布局、启动方式和所需驱动是否完成适配，同样关键。

### 移植一颗新 MCU 为什么费工夫

移植不只是让 `main()` 跑起来，通常还要补齐下面这些环节：

```text
CPU 架构层        异常入口、上下文切换、中断模型
启动与内存        启动代码、向量表、链接脚本、Flash/RAM 布局
SoC 基础设施      时钟、复位、中断控制器、系统定时器
硬件描述          DTS、pinmux/pinctrl、设备树 bindings
外设驱动          GPIO、UART、SPI、I2C、DMA 等驱动及其 Kconfig
构建与调试        交叉工具链、烧录、调试器配置
```

同一 CPU 架构的异常和上下文切换部分可能可以复用，但真正花时间的通常是 SoC 基础设施、设备树和外设驱动。厂商 HAL 也不能自动解决问题：它只是提供了操作硬件的底层能力，还需要接入 Zephyr 的驱动模型、Kconfig 和设备树体系，应用才能通过统一 API 使用它。

## 7. Zephyr 怎样把 API 接到硬件上

Zephyr 希望应用表达“我要控制这块板定义的 LED”，而不是直接写寄存器地址或厂商专属的 GPIO 端口。比如：

```c
gpio_pin_toggle_dt(&led);
```

这句 API 最终能改变引脚电平，靠的是下面几层接力：

```text
应用：             使用 GPIO API
设备树：           指定 LED 对应哪个 GPIO 控制器和引脚
GPIO 驱动：         将 API 调用转换为该控制器的操作
SoC/厂商 HAL：      访问具体外设寄存器
硬件：             改变引脚电平
```

其中三件事尤其重要。统一 API 是应用看到的操作面板，例如 GPIO、UART、I2C、SPI API；设备树像硬件清单，描述“板上有什么、连在哪里”；Kconfig 像装配选项，决定哪些功能和驱动会被编译进固件。

抽象并不意味着硬件差异消失。目标板已经有相应 DTS 描述和驱动时，同一份应用代码才可能少改甚至不改地迁移；DMA、低功耗、特殊时钟和厂商私有外设功能仍然需要结合具体 SoC 的限制来处理。

## 8. 与 FreeRTOS 的应用开发模型对比

Zephyr 和 FreeRTOS 都能做实时嵌入式应用，区别主要不在“有没有线程和队列”，而在于平台覆盖的范围。前者更像一套带标准接口和装配规则的平台，后者的 Kernel 则专注把实时内核做好：

```text
FreeRTOS Kernel
    重点提供任务调度、队列、信号量、软件定时器等内核能力。

Zephyr
    除了内核，还把驱动模型、设备树、Kconfig、板级支持和构建流程
    作为同一平台的一部分。
```

这并不代表 FreeRTOS 不能用驱动或厂商库。实际项目里，它常和厂商的启动代码、HAL、手写或厂商提供的外设驱动一起使用，只是这些组件不由 FreeRTOS Kernel 统一定义和管理。若项目只固定在一块板上，这种方式完全合理；当要支持多块板、维护多种芯片，或希望复用驱动和配置时，Zephyr 试图用一套接口、配置和硬件描述把这些部分串起来。

| 问题 | FreeRTOS 项目中常见做法 | Zephyr 项目中常见做法 |
| --- | --- | --- |
| 创建任务/线程 | `xTaskCreate()` | `K_THREAD_DEFINE()` 或 `k_thread_create()` |
| 延时 | `vTaskDelay()` | `k_sleep()` 或 `k_msleep()` |
| 队列与同步 | Queue、Semaphore、Event Group | `k_msgq`、`k_sem`、`k_event` 等对象 |
| 外设选择 | 厂商 HAL、手写寄存器配置或项目代码 | 通用驱动 API + DTS + Kconfig |
| 引脚和外设实例 | 通常在 BSP、初始化代码或应用中配置 | 主要由设备树描述 |
| 编译开关 | `FreeRTOSConfig.h` 加上工程配置 | Kconfig，例如 `prj.conf` |
| 换一块板 | 常需要调整 BSP、时钟、引脚和驱动初始化 | 若目标板已被支持，通常通过板选择和 DTS/overlay 调整 |

API 名称不能机械地一一替换，两者的对象模型、内存管理方式和配置选项并不完全相同。学习入口也不同：FreeRTOS 往往从任务和调度开始；Zephyr 更适合先弄清应用如何经过配置、设备树和驱动连接到硬件，再进入内核。

## 9. 推荐的阅读顺序

别从目录树里盲目挑文件。继续沿着“闪灯”这个小目标往下追，读完每一步都能马上验证：

1. 应用的 `CMakeLists.txt`：应用如何进入 Zephyr 构建系统。
2. 应用的 `prj.conf`：应用请求启用哪些功能。
3. 目标板的 `.dts`：板上有哪些硬件资源。
4. 应用的 `src/main.c`：应用如何调用 Zephyr API。
5. 构建生成的 `zephyr.dts`、`.config` 和 `devicetree_generated.h`：这次构建最终做了什么。

下一课会把 `led0` 这条线拆开，看看它如何一路找到真实引脚：

```text
DT_ALIAS(led0) -> LED 节点 -> gpios 属性 -> GPIO 控制器与引脚 -> GPIO 驱动
```

顺着这条链路读下去，再进入驱动、初始化和内核，关系会清楚得多。
