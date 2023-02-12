---
title: MVC、MVP、MVVM架构
date: 2023-02-07 14:10:00 +0800
categories: [Blogging, 架构]
tags: [架构]
img_path: /assets/img/MVC/
render_with_liquid: false
---


## 1.MVC

### 1.1 概述

MVC是Model—View—Controller的简称。MVC模式将代码分为三部分：

- Model：数据层，处理业务逻辑，监听网络和数据库接口；
- View：UI层，包含可见的组件，显示布局、显示数据、提供交互；
- Controller：逻辑层，关联View与Model，处理应用逻辑、响应用户交互、更新数据。

![img](1.jpg)

### 1.2 SystemUI中的MVC

以SystemUI锁屏密码为例：M-KeyguardSecurityModel可以获取锁屏密码类型数据、V-KeyguardSecurityContainer锁屏密码界面、C-KeyguardSecurityContainerController相关逻辑控制。

### 1.3 MVC优缺点

> **优点**
> 
> - 耦合性降低，提高代码的可测试性，同时可扩展性提高，使新功能的实现变简单，减少了代码之间的互相影响
> - Model和Controller可以进行单元测试
> - 如果View遵守单一职责原则（将交互请求转给Controller处理，显示从Model获取的数据，不实现相关逻辑），则可以通过UI测试检查View的功能
{: .prompt-tip }


> **缺点**
> 
> - 在Android中，Activity/Fragment既有View的性质，也具有Controller的性质，导致Activity/Fragment很臃肿。MVC中View会与Model直接交互，所以Activity/Fragment与Model的耦合性很高。
> - 即使正确应用了MVC，代码层也相互依赖
{: .prompt-danger }


## 2.MVP

### 2.1 概述

在使用MVC时，可能会遇到困难，如：

- 大多数核心业务逻辑都在Controller中，则Controller会变得越来越臃肿，代码会越来越难以维护；
- 由于紧密耦合的UI和数据访问机制，且Activity/Fragment既有View的性质，也具有Controller的性质，容易在更改应用功能时出现问题。

而MVP克服了这些挑战，提供了更干净、可维护、模块化的代码框架。MVP是Model-View-Presenter的简称。MVP架构代码也由三部分组成：

- Model：数据层。处理业务逻辑，以及与数据库和网络层通信。
- View：UI层。显示数据，为用户提供交互。
- Presenter：从Model提供的接口获取数据，并处理相关逻辑，调用View接口将数据显示到用户界面。并管理视图状态，根据View的输入通知处理逻辑。完成View与Model之间的交互。

![img](2.jpg)

### 2.2 架构要点

- View-Presenter及Presenter-Model通过interface（或者叫Contract）进行通信。
- 一个Presenter每次只管理一个View，所以Presenter和View是一对一的关系。
- Model和View完全分离不知道彼此存在，耦合度低。

### 2.3 MVP优缺点

> **优点**
> 
> - View和Model耦合度降低，易于维护及测试，也能更好遵守单一职责原则。
> - 交互逻辑都在Presenter中处理，则View的代码更简洁易改，且一个View可以用于多个其它View之中，而不需要修改Presenter内部逻辑。Model也可以封装复用，能更高效地使用Model。
{: .prompt-tip }


> **缺点**
>
> - 随着功能和界面越来越复杂、业务逻辑不断增加，会导致View的接口越来越庞大，Presenter中充斥着非常多的业务回调方法，会导致Presenter越来越臃肿。
> - 业务逻辑无法重用：
{: .prompt-danger }
> 假设 **A** 界面对应的 **Presenter** 中实现了一个复杂的业务链， 此时 **B** 页面也需要这个复杂业务链，**B** 的 **Presenter** 又无法直接使用 **A** 界面的 **Presenter**， 这就出现业务无法重用的问题，**B** 界面的 **Presenter** 还得要把业务链重新写一遍，然后对成功失败的回调进行处理。

## 3.MVVM

虽然MVP克服了部分MVC的缺点，但MVP架构随着代码和业务逻辑的增加，Presenter也会越来越臃肿，且MVP也不是Google官方架构。随着Google开始对android项目架构做出指导后，便有了MVVM架构，在一定程度上解决了MVP存在的问题，使代码更加结构化、更干净整齐。MVVM是Model-View-ViewModel的简称，其架构也由三部分组成：

- Model：数据层。与MVP的区别在于Model层不再通过回调通知业务逻辑层数据改变，而是通过观察者模式实现。
- View：UI层，负责将Model层的数据做可视化的处理，同时与ViewModel层交互。
- ViewModel：视图模型，主要负责业务逻辑的处理，同时与 Model 层 和 View层交互。与MVP的Presenter相比，ViewModel不再依赖View，使得解耦更加彻底。
