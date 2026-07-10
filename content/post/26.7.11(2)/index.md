---
title: Zephyr 入门（二）：设备树是什么，应用怎样使用它
slug: zephyr-lesson-2-devicetree
date: 2026-07-10T00:40:00+08:00
draft: false
categories:
  - 嵌入式开发
tags:
  - Zephyr
  - 设备树
  - RTOS
  - 嵌入式
---

# Lesson 2: 设备树是什么，应用怎样使用它

上一课的闪灯程序里有这样一行：

```c
GPIO_DT_SPEC_GET(DT_ALIAS(led0), gpios)
```

它看起来没有写 GPIO 端口和引脚号，却能找到板上的 LED。这一课就把这条线拆开：`led0` 从哪里来，它怎样变成具体硬件，以及为什么换一块兼容的板后，应用代码有机会不改。

## 设备树是在替应用保管硬件细节

假设一块板把用户 LED 接在 `gpio0` 的 12 号引脚，另一块板把它接在 `gpio1` 的 7 号引脚。如果在应用中写死端口和引脚：

```c
HAL_GPIO_TogglePin(GPIOC, GPIO_PIN_13);
```

这段代码就把“闪灯逻辑”和“这块板的接线”绑在了一起。换板时，功能本身没变，仍然只是闪灯，却要回到业务代码里找引脚号。

Zephyr 的做法是把接线关系放进设备树。应用只说“我想操作默认 LED”或“我想使用这个 I2C 传感器”；设备树负责回答它接在哪个控制器、占用哪个引脚、地址和中断是什么。可以把它看成开发板附带的一张硬件清单：应用不必记住仓库里每个零件的位置，只需要按清单取用。

```text
应用 C 代码
    使用 led0、uart0、传感器节点等逻辑入口
        |
设备树
    记录控制器、引脚、总线、地址、中断和连接关系
        |
驱动
    根据这些参数操作实际外设
```

设备树不会凭空让所有程序跨板运行。目标板需要有对应硬件描述和驱动；但当两块板都提供相同的逻辑入口时，应用不再需要关心 LED 实际接到 P0.13 还是 P1.7。

## 一份设备树从哪里拼出来

以一块 STM32 开发板为例，最终设备树通常不是单个文件，而是几层描述叠加的结果。以下路径都相对于 `zephyr/` 源码根目录：

```text
boards/<厂商>/<开发板>/<开发板>.dts
    板级硬件：板载 LED、按键、晶振、默认串口、外接器件等。

dts/<架构>/<厂商>/<SoC 系列>/*.dtsi
    SoC 硬件：片内 UART、GPIO、I2C、SPI、时钟、中断和内存地址。

dts/bindings/
    binding YAML：说明 compatible 对应的设备类型、属性和参数格式。
```

可以这样理解它们的分工：SoC 的 `.dtsi` 先说明“芯片里有几路 I2C、每路在哪个地址”；开发板的 `.dts` 再说明“这块板把 LED 接到了哪个引脚”；应用 overlay 最后补充“这次项目要在 I2C0 上接一个传感器”。

应用不应该直接改 Zephyr 自带的板级 DTS，否则升级 Zephyr 或切换版本时很难维护。通常在应用目录里添加 overlay：

```text
<application>/app.overlay
<application>/boards/<board>.overlay
```

构建后要看的不是某一层输入，而是最终合并结果：

```text
build/zephyr/zephyr.dts
build/zephyr/include/generated/devicetree_generated.h
```

如果你在 overlay 中改了 LED 引脚，实际却没有变化，先打开 `build/zephyr/zephyr.dts` 搜索 `led0` 或节点标签。它才是本次构建真正采用的硬件清单。

## 先分清四个容易混淆的名字

同一个设备在 DTS 中可能有几种名字，刚开始很容易看花：

```text
节点名          DTS 树中的名字，例如 led_0、serial@4000xxxx。
节点标签        供 DTS 内部引用的名字，例如 led0:、uart0:，引用时写 &led0。
属性            节点的参数，例如 gpios、reg、status、compatible。
alias           /aliases 下给应用的逻辑名字，例如 led0、sw0。
```

可以把节点标签理解为设备树内部的“书签”，而 alias 更像留给应用的快捷入口。两者名字可以相同，但不是同一个概念。尤其要记住：`DT_ALIAS(led0)` 查的是 `/aliases` 中的 `led0`，不是节点名，也不是节点标签。

## 例子：从 `led0` 找到真实引脚

下面是一段简化的板级 DTS。它把真实 LED 映射为通用别名：

```dts
/ {
    leds {
        compatible = "gpio-leds";

        user_led: led_0 {
            gpios = <&gpio0 12 GPIO_ACTIVE_HIGH>;
        };
    };

    aliases {
        led0 = &user_led;
    };
};
```

这里的 `user_led` 是节点标签，`led_0` 是节点名。真正描述接线的是 `gpios`：LED 连到 `gpio0` 的 12 号引脚，高电平有效。`aliases` 则给它起了一个跨板更好使用的名字 `led0`。

应用只要取这个别名：

```c
#include <zephyr/drivers/gpio.h>

#define LED_NODE DT_ALIAS(led0)
static const struct gpio_dt_spec led = GPIO_DT_SPEC_GET(LED_NODE, gpios);
```

这段代码并不是运行时去读取一个配置文件。宏会在编译期一路展开：

```text
DT_ALIAS(led0)
    -> /aliases 中的 led0
    -> user_led 节点
    -> gpios 属性
    -> GPIO 控制器、12 号引脚、有效电平
    -> struct gpio_dt_spec
```

随后就可以调用 `gpio_pin_configure_dt()`、`gpio_pin_set_dt()` 或 `gpio_pin_toggle_dt()`。若另一块板把默认 LED 定义为 `led0`，它可以接在完全不同的引脚上，而这段应用逻辑不必知道。

## 例子：给项目接一个 I2C 传感器

再看一个更接近项目的场景：开发板已经有 `i2c0`，但板级 DTS 没有写你的 BME280 传感器。此时不需要复制整份板级 DTS，只要在应用的 `app.overlay` 中补上一段：

```dts
&i2c0 {
    status = "okay";

    bme280: sensor@76 {
        compatible = "bosch,bme280";
        reg = <0x76>;
    };
};
```

这段话可以顺着读：找到已有的 `i2c0`；确保它启用；在这条总线上声明一个地址是 `0x76` 的设备；它遵循 `bosch,bme280` 这份 binding 的规则。`bme280:` 是节点标签，因此 C 代码可以按标签取到设备：

```c
#include <zephyr/device.h>

const struct device *sensor = DEVICE_DT_GET(DT_NODELABEL(bme280));
```

设备树到这里解决的是“传感器接在哪里、是什么类型”。它还不保证传感器一定可用：对应的驱动必须被 Kconfig 编译进固件，运行前也应该用 `device_is_ready(sensor)` 检查设备是否准备好。下一课的 Kconfig 正好解释这个条件。

## DTS、DTSI、overlay 和 binding 各自负责什么

回看上面的两个例子，这四类文件的边界就比较清楚了：

```text
SoC .dtsi
    描述芯片内部已有的外设资源，好比芯片的数据手册。

板级 .dts
    描述开发板怎样使用这些资源，例如 LED 和按键接在哪里。

应用 overlay
    描述当前应用新增、启用或修改的硬件，例如接入自己的传感器。

binding YAML
    定义某种 compatible 允许哪些属性、数据格式和约束，像一份填写规则。
```

构建系统把它们合并成 `build/zephyr/zephyr.dts`，再生成 C 宏头文件。设备树不是运行时配置文件，所有宏都在编译期展开；改了 overlay 后必须重新构建，固件里的描述才会更新。

## 本课结论

设备树回答“硬件有什么、怎样连接、参数是什么”，应用代码再用设备树宏把这些信息交给驱动 API。读设备树时，先从板级 `.dts` 看这块板怎样接线；需要了解片内资源时再追到 SoC `.dtsi`；不清楚某个属性怎么写时查 binding；改完后始终以 `build/zephyr/zephyr.dts` 为准。

下一课会看 Kconfig：设备树已经说清“这里接着一颗 BME280”，Kconfig 还要决定“它的驱动是否真的进入这次固件”。
