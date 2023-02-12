---
title: Android本地编译：以framework和systemui为例
date: 2022-08-12 14:10:00 +0800
categories: [Blogging, Android]
tags: [Android]
img_path: /assets/img/build/
render_with_liquid: false
---


Google官方文档：https://source.android.com/setup/build/building?hl=zh-cn#build-the-code

Android系统的编译环境目前仅支持Ubuntu及Mac OS。

## 编译前

1. 获取整机的Android源码：在编译前，需要先获取完整的Android源码
2. 开始frameworks和systemui编译前，需要先在整机源码的根目录下执行：

```shell
source build/envsetup.sh或. build/envsetup.sh
lunch product_name-build_variant (product_name：要编译的目标设备，build_variant：编译类型)
```

### **source 与lunch解读**

#### **1. `source build/envsetup.sh`**

- **linux source命令**：

> source命令是一个内置的shell命令，用于从当前shell会话中的文件读取和执行命令。source命令通常用于保留、更改当前shell中的环境变量。简而言之，source一个脚本，将会在当前shell中运行execute命令。
{: .prompt-tip }

- source build/envsetup.sh

语法：

```shell
source [filename] [arguments]
```

其中source可以替换为“.”：

```shell
. [filename] [arguments]
```

所以source build/envsetup.sh就是执行了脚本envsetup.sh。

- **[envsetup.sh 脚本](https://android.googlesource.com/platform/build/+/refs/heads/master/envsetup.sh)**

https://android.googlesource.com/platform/build/+/refs/heads/master/envsetup.sh

执行该脚本会导入若干编译代码的命令，初始化编译环境。在脚本中可以具体查看导入了哪些命令，也可以使用命令`hmm`查看有哪些命令，因为hmm是envsetup.sh中导入命令的function：

![img](p1.png)

图1：脚本中的function hmm()

![img](p2.png)

图2：输入hmm后的输出

envsetup.sh最后执行了vendorsetup.sh。vendorsetup.sh路径在：

```
高通目录：device/qcom/common/vendorsetup.sh
MTK目录：device/mediatek/build/vendorsetup.sh
```

#### **2. `lunch product_name-build_variant`编译目标**

lunch也是envsetup.sh中的function。使用lunch选择目标设备及编译类型，执行后会将这两项选择存储在环境中，以便后续编译。

**目标设备：** 可以运行`lunch`命令查看具体有哪些编译目标，从中选择构建（如果知道目标设备代号可以不用查看lunch menu）：

![img](p3.png)

**编译类型：** 可参考官方文档：https://source.android.com/source/add-device.html#build-variants

| **编译类型**  | **详情**                                                     |
| ------------- | ------------------------------------------------------------ |
| **user**      | 相当于release版本，权限受限，通常不用于自研测试编译。adb默认停用。 原则上进行性能测试请使用user 版本测试 user 版本为提高第一次开机速度，使用了DVM 的预优化，将dex 文件分解成可直接load 运行的odex 文件，ENG 版本不会开启这项优化更少的LOG 打印，uart 的关闭，原则上user 版本的性能要优于eng 版本 |
| **userdebug** | 与“user”类似，但具有 root 权限和调试功能；会安装带有debug标记的模块，adb默认启用。是进行调试时的首选编译类型。 |
| **eng**       | 默认编译类型。相当于debug版本，adb 默认启用                  |

> userdebug build 的运行方式应该与 user build 一样，且能够启用通常不符合平台安全模型的额外调试功能。这就使得 userdebug 版本具有更强大的诊断功能，因此是进行 user 测试的最佳选择。
> 
> eng 编译系统会优先考虑在平台上工作的工程师的工程生产率。eng 编译系统会关闭用于提供良好用户体验的各种优化。除此之外，eng build 的运行方式类似于 user 和 userdebug build，以便设备开发者能够看到代码在这些环境下的运行方式。
{: .card }


## 一、本地编译systemui

执行完envsetup.sh和lunch后就开始编译代码。编译命令有很多，具体也可以查看脚本envsetup.sh有哪些命令。

取个别为例：

| 命令         | 输出                                                         |
| ------------ | ------------------------------------------------------------ |
| `m`          | 可以m -jN并行处理，提高效率。如果没有`-j`，系统会自动选择合适的。`m 模块名`即可构建相应模块。 |
| `mma`/`mm`   | 构建当前目录中的所有模块及其依赖项。可加模块名               |
| `mmma`/`mmm` | 构建提供的目录中的所有模块及其依赖项。                       |
| `m clean`    | 会删除此配置的所有输出和中间文件。此内容与 `rm -rf out/` 相同。 |

如果只编译systemui模块，可以通过两种方式确认模块名：

1. 在SystemUI目录下查看Android.bp文件：找android_app；
2. adb命令adb shell pm path com.android.systemui看一下apk名，如MtkSystemUI.apk。

确认好上述内容后就可以开始编译啦：

如：`mm MtkSystemUI`

编译完成后，执行以下命令将apk推入手机并应用：

```shell
adb root
adb remount
adb reboot
adb root
adb remount
adb shell pm path com.android.systemui(确认apk路径)
adb push ./MtkSystemUI.apk /system/system_ext/priv-app/MtkSystemUI/（第6行输出路径）
adb shell ps | grep  systemui
adb shell kill 第8行输出的进程号
```



## 二、本地编译framework

先看一下platform/frameworks/base目录下的Android.bp文件中frameworks模块命名，如下图描述"framework" module不在设备中，设备中安装的是"framework-minus-apex"：

![img](p4.png)


所以同编译systemui一样，换个module即可：

```shell
source build/envsetup.sh
lunch missi-userdebug
mm framework-minus-apex
```

![img](p5.png)

编译成功后找到手机中framework.jar的目录并push进去即可。



**其它模块类似。**
