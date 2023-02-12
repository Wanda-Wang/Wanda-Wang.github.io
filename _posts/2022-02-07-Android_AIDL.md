---
title: AIDL源码分析及使用
date: 2022-02-07 14:10:00 +0800
categories: [Blogging, Android]
tags: [Android]
render_with_liquid: false
---


## 一、概述

### 1.Binder机制浅析

Binder通信采用C/S架构，从组件视角来说，由**Client、Server、ServiceManager 以及 Binder 驱动**构成，其中 ServiceManager 用于管理系统中的各种服务。Binder通信的大概调用流程如下：

![图1](https://zxzm0aor6j.feishu.cn/space/api/box/stream/download/asynccode/?code=YTNkMmUzZDViZTYwZGEzNDlmMDhiZjIyY2FhMDAxNTRfVVFHWXpndGI5WGwxN096ZUI2OTFuZE1CTlkwZ0EzZkFfVG9rZW46Ym94Y25XU0lNSFVFRXd1QzdpeTZSVEVEWnFnXzE2NzYyMjY1ODg6MTY3NjIzMDE4OF9WNA)



- Client发起请求（Blocking），拿到服务端的Proxy（代理接口），调用Proxy中的方法；
- Proxy的方法会将Client传递的参数打包为Parcel对象，然后Proxy把该Parcel对象发送给内核中的Binder Driver；
- Server读取Binder Driver中的请求数据，将发送给自己的请求数据解包，处理后返回结果；
- Proxy拿到结果返回给Client。

Proxy中定义的方法和Server中定义的方法是一一对应的，整个调用过程是同步的，Server在处理时，Client处于Blocking。而AIDL就是Proxy的接口定义语言。

### 2.AIDL简介

AIDL (Android Interface Definition Language) 是一种接口定义语言。可以利用它定义Client与Server（两个进程）均认可的接口，以便二者进行进程间通信（IPC）。在 Android 中，一个进程通常无法访问另一个进程的数据。因此，为进行通信，进程需将其对象分解成可供操作系统理解的原语，并将其编组为可操作的对象。编写执行该编组操作的代码较为繁琐，因此 Android通过AIDL 处理此问题。简单来说，就是Android为了简化应用层进行IPC操作，提供了AIDL。

AIDL并非真正的编程语言，只是定义两个进程间通信的接口而已。而符合通信协议的Java代码则是由Android SDK的aidl工具生成，生成的java文件与aidl文件同名，在build/generated目录下。在该生成的接口中包含一个Stub的内部类，Stub实现了IBinder接口和自定义的通信接口，所以可以作为Service的onBind()方法的返回值。

## 二、AIDL实现简单的进程间通信

具体步骤：

1. **创建.aidl文件**
2. **自定义Serice，实现stub，作为onBind()方法的返回值**：Android SDK工具根据.aidl文件以Java编程语言生成一个接口 。这个接口有一个Stub的内部抽象类，它继承了Binder并实现了AIDL接口中的方法。必须继承这个 Stub类并实现这些方法。
3. **客户端绑定Service，并实现ServiceConnection接口**：和本地Service不同，绑定远程Service的ServiceConnection并不能直接获取Service的onBind( )方法返回的IBinder对象，只能返回onBind( )方法所返回的代理对象，需要调用Stub.asInterface()。

注意事项：

**1.默认情况下，AIDL支持以下数据类型**：

- Java中的基本类型（int，long，char，boolean，float，double，byte，short）
- String
- CharSequence
- List List中的所有元素都必须是以上支持的数据类型之一，或者是您声明的其他AIDL生成的接口或可接受的元素之一。 列表可以选择性地用作“通用”类（例如List）。对方收到的实际具体类始终是一个ArrayList，尽管生成的方法是使用List接口。

- Map Map中的所有元素都必须是此列表中受支持的数据类型之一，或者是您声明的其他AIDL生成的接口或可接受元素之一。 通用映射（如Map形式的映射）不被支持。对方接收的实际具体类总是一个HashMap，尽管该方法是使用Map接口生成的。

对于上面没有列出的每种附加类型，即使它们在与接口相同的包中定义，**也必须包含一条import语句。**

2.在定义AIDL接口时，注意：

- 方法可以采用零个或多个参数，并返回一个值或void。
- 所有非原始参数都需要一个指向数据的方向标签。in，out或者inout。基本数据默认是in的，不能以其他方式。

**警告：**应该将方向限制在真正需要的地方，因为编组参数非常昂贵。

- 包含在.aidl文件中的所有代码注释都包含在生成的IBinder接口中（导入和包装语句之前的注释除外）。
- 只支持方法，不能在AIDL中公开静态字段。

> 具体实现如下：
{: .prompt-warning }

### 1.创建.aidl文件

在java同级目录下创建一个aidl的文件夹，并在该文件夹中新建一个aidl文件（new->AIDL->AIDL File），通常aidl接口文件以“I”起头命名：

![img](https://zxzm0aor6j.feishu.cn/space/api/box/stream/download/asynccode/?code=MmUyOWY0NTJhZmY2YTUzNzc0Nzc1NGYyY2EyNGUwNmRfZ29mRkgwRU5XNkxLc1hWeVZRTXhFbW9sb3JjaVhlbXhfVG9rZW46Ym94Y25NNXlqQWNWY1BUeHBKU2xFcFZsNDNVXzE2NzYyMjY1ODg6MTY3NjIzMDE4OF9WNA)

在AIDL中添加跨进程需要的方法：

```java
interface IRemoteService {

    void setPause(String pause);

    void setPlay(String play);
}
```

AIDL 文件定义好了。在Android Studio中点击Make build进行build，build结束后会在build/generated/aidl_source_output_dir/目录下生成与AIDL文件同名的java文件：

![img](https://zxzm0aor6j.feishu.cn/space/api/box/stream/download/asynccode/?code=M2VhMDc0OGJlNjBlNjIzOTMwNTFiYWVhMjM0MGFjOWVfSU5MVHBUUk9zWmlNeFl0cVJ1YVVQa2xUTHRwcUk5cExfVG9rZW46Ym94Y25pcnp3eTVUQTVxd3phYXhxaWN1Yk9iXzE2NzYyMjY1ODg6MTY3NjIzMDE4OF9WNA)

### **AIDL源码分析**

对比下图理解更有助于理解源码：

![img](https://zxzm0aor6j.feishu.cn/space/api/box/stream/download/asynccode/?code=MDgzMWQwMWVkODMwMTY0NThiOTMzNjQ3YTNlODY3MmZfWkF3NXJWc0NYM1hsdDRxZ0E2NlozVzNmNDNROXlVY2VfVG9rZW46Ym94Y241blM5Smh0MzQ3MmpWSmw4RHRPOFRkXzE2NzYyMjY1ODg6MTY3NjIzMDE4OF9WNA)

1.在文件开头就有注释，该文件是自动生成的，不要修改。所以如果要为跨进程通信添加新的方法，只需要在IRemoteService.aidl文件中添加再build即可。

```java
/*
 * This file is auto-generated.  DO NOT MODIFY.
 */
package com.wanda.musicplayer;
// Declare any non-default types here with import statements
```

2.**IInterface**：IRemoteService继承自IInterface，所有Binder通信的接口必须继承IInterface接口

```java
public interface IRemoteService extends android.os.IInterface {
    /**
     * Default implementation for IRemoteService.
     */
    public static class Default implements com.wanda.musicplayer.IRemoteService {
        @Override
        public void setPause(java.lang.String pause) throws android.os.RemoteException {
        }

        @Override
        public void setPlay(java.lang.String play) throws android.os.RemoteException {
        }

        @Override
        public android.os.IBinder asBinder() {
            return null;
        }
    }
    ... ...
```

3.**Stub**继承了Binder类并实现了IRemoteService。而学过activity与service通信的都知道，在Service中的onBind方法会返回一个Binder对象，而Stub继承了Binder，又是一个抽象类，所以Stub可以作为我们跨进程通信时，服务端自定义Binder的父类。

```java
public static abstract class Stub extends android.os.Binder implements com.wanda.musicplayer.IRemoteService {
```

4.**DESCRIPTOR**：Binder的唯一标识，通常是包名+接口名组成的字符串

```java
private static final java.lang.String DESCRIPTOR = "com.wanda.musicplayer.IRemoteService";
```

5.**asInterface：**asInterface将服务端Binder转换为客户端所需的AIDL接口类型对象。在方法中首先会调用queryLocalInterface(DESCRIPTOR)，参数是binder的唯一标识，用来查询本地接口。如果能查询到本地接口IRemoteService（客户端和服务端处于同一进程），就返回本地接口，不跨进程通信。**如果查询不到本地接口，就构造Proxy代理对象并返回，通过代理对象可以跨进程通信。**

```java
public static com.wanda.musicplayer.IRemoteService asInterface(android.os.IBinder obj) {
            if ((obj == null)) {
                return null;
            }
            android.os.IInterface iin = obj.queryLocalInterface(DESCRIPTOR);
            // 5.1. 如果能查询到本地接口IRemoteService，就返回本地接口，不跨进程通信。
            if (((iin != null) && (iin instanceof com.wanda.musicplayer.IRemoteService))) {
                return ((com.wanda.musicplayer.IRemoteService) iin);
            }
            // 5.2. 如果查询不到本地接口，就返回代理对象，通过代理对象可以跨进程通信。
            return new com.wanda.musicplayer.IRemoteService.Stub.Proxy(obj);
}
```

6.**asBinder()：**用于返回当前Binder对象

```java
        //6. asBinder()用于返回当前Binder对象
        @Override
        public android.os.IBinder asBinder() {
            return this;
        }
```

7.**Proxy代理类：**构造Proxy时，把服务端的Binder对象赋值给mRemote，Proxy中实现了自定义方法：setPause和setPlay ，通过调用mRemote的transact方法，最后走到Stub的onTransact，完成对服务端Binder的调用。

8.**onTransact与transact**

（1）每个AIDL中定义的方法都有一个int code来标识：

```java
static final int TRANSACTION_setPause = (android.os.IBinder.FIRST_CALL_TRANSACTION + 0);
static final int TRANSACTION_setPlay = (android.os.IBinder.FIRST_CALL_TRANSACTION + 1);
```

（2）Proxy中实现了setPause和setPlay，其中分别调用了mRemote.transact()方法，transact的第一个参数code是每个方法的唯一标识。客户端远程请求Binder并写入参数，通过transact传入服务端。

```java
private static class Proxy implements com.wanda.musicplayer.IRemoteService {
    private android.os.IBinder mRemote;

    Proxy(android.os.IBinder remote) {
        mRemote = remote;
    }

    @Override
    public android.os.IBinder asBinder() {
        return mRemote;
    }

    public java.lang.String getInterfaceDescriptor() {
        return DESCRIPTOR;
    }

    @Override
    public void setPause(java.lang.String pause) throws android.os.RemoteException {
        android.os.Parcel _data = android.os.Parcel.obtain();
        android.os.Parcel _reply = android.os.Parcel.obtain();
        try {
            _data.writeInterfaceToken(DESCRIPTOR);
            _data.writeString(pause);
            boolean _status = mRemote.transact(Stub.TRANSACTION_setPause, _data, _reply, 0);
            if (!_status && getDefaultImpl() != null) {
                getDefaultImpl().setPause(pause);
                return;
            }
            _reply.readException();
        } finally {
            _reply.recycle();
            _data.recycle();
        }
    }

    @Override
    public void setPlay(java.lang.String play) throws android.os.RemoteException {
        android.os.Parcel _data = android.os.Parcel.obtain();
        android.os.Parcel _reply = android.os.Parcel.obtain();
        try {
            _data.writeInterfaceToken(DESCRIPTOR);
            _data.writeString(play);
            boolean _status = mRemote.transact(Stub.TRANSACTION_setPlay, _data, _reply, 0);
            if (!_status && getDefaultImpl() != null) {
                getDefaultImpl().setPlay(play);
                return;
            }
            _reply.readException();
        } finally {
            _reply.recycle();
            _data.recycle();
        }
    }

    public static com.wanda.musicplayer.IRemoteService sDefaultImpl;
}
```

（3）onTransact运行在服务端的Binder线程池中，当客户端发起跨进程请求时，请求会通过底层封装后，交由onTransact处理，服务端通过code来判断客户端请求的方法是什么，接着从data取出目标方法需要的参数（如果目标方法有参数的话），然后执行目标方法，执行完之后就向reply中写入返回值（如果目标方法有返回值的话），这就是这个方法的执行过程，如果此方法返回false，那么客户端请求失败。

```java
@Override
public boolean onTransact(int code, android.os.Parcel data, android.os.Parcel reply, int flags) throws android.os.RemoteException {
    java.lang.String descriptor = DESCRIPTOR;
    switch (code) {
        case INTERFACE_TRANSACTION: {
            reply.writeString(descriptor);
            return true;
        }
        case TRANSACTION_setPause: {
            data.enforceInterface(descriptor);
            java.lang.String _arg0;
            _arg0 = data.readString();
            this.setPause(_arg0);
            reply.writeNoException();
            return true;
        }
        case TRANSACTION_setPlay: {
            data.enforceInterface(descriptor);
            java.lang.String _arg0;
            _arg0 = data.readString();
            this.setPlay(_arg0);
            reply.writeNoException();
            return true;
        }
        default: {
            return super.onTransact(code, data, reply, flags);
        }
    }
}
```

所以，aidl通信体现着代理模式的设计思想，RemoteService具体实现了Stub，Proxy是Stub在本地的Client代理对象，Proxy与Stub依靠transact和onTransact通信，Proxy与Stub的封装设计最终很方便地完成了客户端与服务端的跨进程通信

### 2.实现接口

和本地service通信同理，需要一个Binder对象来进行通信。而IRemoteService.aidl build生成的IRemoteService.java中的抽象类Stub刚好继承Binder类并实现了IRemoteService接口，所以谷歌都已经帮你生成好了，咱们直接用呗：

```java
private final IRemoteService.Stub mBinder = new IRemoteService.Stub() {

    @Override
    public void setPause(String pause) throws RemoteException {
        Log.d(TAG, "setPause: ");
    }

    @Override
    public void setPlay(String play) throws RemoteException {
        Log.d(TAG, "setPlay: ");
    }
};
```

> 在实现 AIDL 接口时，您应注意遵守以下规则：
>
> - 由于无法保证在主线程上执行传入调用，因此您一开始便需做好多线程处理的准备，并对您的服务进行适当构建，使其达到线程安全的标准。
> - 默认情况下，RPC 调用是同步调用。如果您知道服务完成请求的时间不止几毫秒，则不应从 Activity 的主线程调用该服务，因为这可能会导致ANR— 通常，您应从客户端内的单独线程调用服务。
> - 您引发的任何异常都不会回传给调用方。

### 3.向客户端公开接口

（1）继承Service并实现onBind()，return步骤2的Stub实例mBinder：

```java
public class RemoteService extends Service {
    private static final String TAG = "RemoteService";

    @Override
    public void onCreate() {
        super.onCreate();
    }

    @Override
    public IBinder onBind(Intent intent) {
        // Return the interface
        return mBinder;
    }

    private final IRemoteService.Stub mBinder = new IRemoteService.Stub() {

        @Override
        public void setPause(String pause) throws RemoteException {
            Log.d(TAG, "setPause: ");
        }

        @Override
        public void setPlay(String play) throws RemoteException {
            Log.d(TAG, "setPlay: ");
        }
    };
}
```

（2）将服务端的aidl文件及目录一起拷贝到客户端同级目录：

![img](https://zxzm0aor6j.feishu.cn/space/api/box/stream/download/asynccode/?code=ZmM0NmM1YTFkOTg0MmMyODI1NDlmNmY1NDljNDMyN2ZfZ3E0QmdwZ2FtUTRPRUZnN2R0NFVUU2VWcUpYeVZiSXpfVG9rZW46Ym94Y253TkNPY3ladzZMYmZjazgyeXFCWTJnXzE2NzYyMjY1ODg6MTY3NjIzMDE4OF9WNA)

客户端需要有IRemoteService访问权限，因此如果Client与Service是跨进程的，则Client的同级目录也必须包含相同的aidl文件。

（3）客户端创建ServiceConnection对象，并bindService()，此时客户端onServiceConnected() 回调会接受到服务端onBind() 方法所返回的 binder 实例，注意这里用到了上文说的*asInterface哦*：

```TypeScript
private IRemoteService mRemoteService;

private ServiceConnection mRemoteConn = new ServiceConnection() {
    @Override
    public void onServiceConnected(ComponentName name, IBinder service) {
        Log.i(TAG, "RemoteService-onServiceConnected");
        mRemoteService = IRemoteService.Stub.asInterface(service);
    }

    @Override
    public void onServiceDisconnected(ComponentName name) {
        Log.i(TAG, "RemoteService-onServiceDisconnected");
    }
};
```

### 4.声明软件包可见性

以 Android 11（API 级别 30）或更高版本为目标平台，在默认情况下，系统会自动让部分应用对您的应用可见，但会过滤掉其他应用。如果您的应用以 Android 11 或更高版本为目标平台，并且需要与并非自动可见的应用交互，请在您应用的清单文件中添加 `<queries>` 元素。在 `<queries>` 元素中，按软件包名称、按 intent 签名或按提供程序授权指定其他应用，如以下部分所述。

官方文档：[声明软件包可见性需求](https://developer.android.com/training/package-visibility/declaring?hl=zh-cn#provider-authority)

1. 通过 `<queries>` 指定包名：

```xml
<manifest package="com.wanda.servicedemo">
    <queries>
        <package android:name="com.wanda.musicplayer" />
    </queries>
    ...
</manifest>
```

2. 通过`<queries>` 过滤intent的action：

```xml
<manifest package="com.wanda.servicedemo">
    <queries>
        <intent>
            <action android:name="android.intent.action.REMOTE_SERVICE" />
        </intent>
    </queries>
    ...
</manifest>
```

3. 所有应用可见权限：

```xml
<manifest package="com.wanda.servicedemo">
    <uses-permission android:name="android.permission.QUERY_ALL_PACKAGES"/>
    ...
</manifest>
```

> 下面列举了一些适合添加 `QUERY_ALL_PACKAGES` 权限的用例：
>
> - 无障碍应用
> - 浏览器
> - 设备管理应用
> - 安全应用
> - 防病毒应用
