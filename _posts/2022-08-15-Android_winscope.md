---
title: Android闪屏问题分析及Winscope使用
date: 2022-08-15 14:10:00 +0800
categories: [Blogging, Android]
tags: [Android]
img_path: /assets/img/winscope/
render_with_liquid: false
---


## 1.最有用的办法：抓取winscope

### 第一步 本地编译生成winscope.html

（该步一劳永逸，只需要执行一次，如果不想执行，可以直接下载本文中的winscope.html文件并直接跳过该步骤）：先下载整机代码，执行源码目录prebuilts/misc/common/winscope的脚本：update_winscope.sh来获取最新版winscope.html，执行前需要在源码主目录下source、lunch，如：

```shell
source build/envsetup.sh
lunch missi-userdebug
prebuilts/misc/common/winscope/update_winscope.sh
```

update_winscope.sh执行成功，SUCCESS结果包含了winscop.html目录：

![img](1.png)

更新后的winscope.html：
[winscope](/assets/file/winscope.html)

### 第二步 运行winscope_proxy.py

找到源码中的**winscope_proxy.py**文件，如我的目录在：/development/tools/winscope/adb_proxy/winscope_proxy.py。

或者可以打开winscope.html，下载winscope_proxy.py：
[winscope_proxy](/assets/file/winscope_proxy.py)

本地执行：
```shell
python3.x winscope_proxy.py(其中x换为python3的版本，如python3.9)
```

执行winscope_proxy.py后，点击RETRY即可抓取



### 第三步 复现问题并抓取trace

**抓取trace。**

**方法一：**

winscope.html中START TRACE->复现问题->END TRACE，winscope.html便会自己打开trace及录屏（前提需要手机为userdebug版本）效果如下：

![img](2.png)

**方法二：**

通过**快捷设置**记录跟踪情况，请执行以下操作：

1. 启用开发者选项。
2. 依次转到**开发者选项** > **快捷设置开发者图块**。
3. 启用 **WinScope 跟踪**。
4. 打开**快捷设置**。
5. 点按 **Winscope 跟踪**以启用跟踪。
6. 在设备上执行窗口转换。
7. 窗口转换完成后，打开**快捷设置**，然后点按 **Winscope 跟踪记录**以停用跟踪记录。

跟踪记录会被写入 `/data/misc/wmtrace/wm_trace.winscope` 和 `/data/misc/wmtrace/layers_trace.winscope`，同时还会包含在错误报告中。



### 第四步 查看trace

trace已经抓取成功，可以切换到复现那一帧，查看 WindowManager和 SurfaceFlinger是否存在异常。还能看到windowmanager对应log：

![img](3.png)

### 抓winscope常见问题

1. 执行update_winscope.sh时，发生Fail：

![img](4.png)

解决办法：安装yarn

```Shell
sudo apt remove cmdtest
sudo apt remove yarn
curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
sudo apt update
sudo apt install yarn
```

安装后执行：`which yarn`查看是否成功

1. 执行update_winscope.sh时，报错：

![img](5.png)

解决办法：执行source和lunch

1. 执行update_winscope.sh时，报错：

![img](6.png)

看报错信息，node版本太低导致，可以用 node -v查看一下node版本：

![img](7.png)

https://linuxize.com/post/how-to-install-node-js-on-ubuntu-20-04/

解决办法：

```shell
1. 先安装npm:
sudo apt update
sudo apt install nodejs npm
2. 用npm安装Node工具包n,使用该工具包将node升级到最新版本：
sudo npm install n -g
sudo n stable
```



## 2.逐帧观察录屏法（通常解决闪屏问题的第一步）

推荐一个很好用的逐帧查看视频的应用：avidemux

linux可以直接下载appimage：

https://sourceforge.net/projects/avidemux/files/avidemux/ 



## 3.打开WindowManager debug_log看日志

1 **打开WM_DEBUG_SCREEN_ON动态log**：

adb shell wm logging enable-text WM_DEBUG_SCREEN_ON

2 **打开PhoneWindowManager.DEBUG_WAKEUP**：

高通机器：只能通过修改代码的方法实现，将frameworks/base/services/core/java/com/android/server/policy/PhoneWindowManager.java的DEBUG_WAKEUP = false改为DEBUG_WAKEUP = true即可；

mtk机器：可以通过命令adb shell dumpsys window -d enable DEBUG_WAKEUP打开。
