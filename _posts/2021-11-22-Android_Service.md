---
title: Android Service 及 IntentService源码解析
date: 2021-11-22 14:10:00 +0800
categories: [Blogging, Android, 源码分析]
tags: [Android]
img_path: /assets/img/service/
render_with_liquid: false
---

## 一、简介

官方定义：

> Service 是一种可在后台执行长时间运行操作而不提供界面的应用组件。Service可由其他应用组件启动，而且即使用户切换到其他应用，Service仍将在后台继续运行。此外，组件可通过绑定到服务与之进行交互，甚至是执行进程间通信 (IPC)。例如，服务可在后台处理网络事务、播放音乐，执行文件 I/O 或与内容提供程序进行交互。

Service的两种方式：

- startService()
- bindService()

|                    | **创建service**                                              | **销毁service**                                              | **service与启动它的组件之间的通信方式**                      | **service的生命周期** |
| ------------------ | ----------------------------------------------------------- | ------------------------------------------------------------ | ------------------------------------------------------------ | --------------------- |
| **startService()** | 在其他组件调用 startService() 时<br/>创建，然后无限期运行         | stopSelf() 来自行停止运行。<br/>其他组件调用 stopService() <br/>来停止此Service。<br/>Service停止后，系统会将<br/>其销毁 | 应用组件与服务间<br/>的唯一通信模式便是使用<br/> startService() <br/>传递的 Intent，启动service<br/>后该service就处于<br/>独立运行状态 | 图1左                 |
| **bindService()**  | 该服务在其他组件（客户端）调<br/>用bindService()时创建<br/>（其他组件<br/>不包括BroadcastReceiver） | 所有与Service绑定的组件<br/>都被销毁，或者它们都调用<br/>了unbindService()方法后，<br/>系统会销毁Service | 在Service中实现 onBind() <br/>回调方法返回 IBinder，从<br/>而定义与Service进行通信的<br/>接口；在与Service绑定的组件中<br/>通过 ServiceConnection进行通信。 | 图1右                 |

备注：同一个Service可能有组件调用了startService()启动它，又有组件调用bindService()与它绑定。当同一个Service与其他组件同时存在这两种联系时，必须既要所有组件取消绑定也要stopService() 或 stopSelf()才会停止Service。

![图1](service_1.png)
_图1_

## 二、创建Service

**2个步骤：**

1. 创建一个类继承自Service(或它的子类)，重写里面的一些关键的回调方法，如onStartCommand()，onBind()等
2. 在清单文件里面为其声明，并根据需要配置一些属性

在清单文件里进行声明时，只有android:name属性是必需的。但是适当添加其它属性可以让开发进行地更加顺利，所以了解一下注册一个Service可以声明哪些属性也是很有必要的。

```xml
<service android:description="string resource"
         android:directBootAware=["true" | "false"]
         android:enabled=["true" | "false"]
         android:exported=["true" | "false"]
         android:foregroundServiceType=["connectedDevice" | "dataSync" |
                                        "location" | "mediaPlayback" | "mediaProjection" |
                                        "phoneCall"]
         android:icon="drawable resource"
         android:isolatedProcess=["true" | "false"]
         android:label="string resource"
         android:name="string"
         android:permission="string"
         android:process="string" >
    . . .
</service>
```

- `android:description`向用户描述Service的字符串。
- `android:directBootAware`服务是否*支持直接启动*，即其是否可以在用户解锁设备之前运行。默认false。
- `android:enabled`系统是否可实例化Service。默认为true，表示可以。只有在 <application> 和 <service> 属性都为“true”（因为它们都默认使用该值）时，系统才能启用服务。
- `android:exported`其他应用的组件是否能调用服务或与之交互 。如果为false，则只有与Service同一个应用或者相同user ID的应用可以开启或绑定此Service。它的默认值取决于Service是否有Intent Filters。如果一个filter都没有，就意味着只有指定了Service的准确的类名才能调用，也就是说这个Service只能应用内部使用——其他的应用不知道它的类名。这种情况下exported的默认值就为false。反之，只要有了一个filter，就意味着Service是考虑到外界使用的情况的，这时exported的默认值就为true。
- `android:foregroundServiceType`阐明服务是满足特定用例要求的前台服务，可以将多个前台服务类型分配给特定服务。
- `android:icon`表示Service的icon
- `android:isolatedProcess` 如果设置为true，这个Service将运行在一个从系统中其他部分分离出来的特殊进程中，只能通过Service API来与它进行通信。默认为false。
- `android:label`可向用户显示的服务名称。
- `android:name`实现服务的 Service 子类的名称。此名称应为完全限定类名称（例如“com.example.project.RoomService”）。没有默认值。必须指定。
- `android:permission` 其他组件必须具有所填的权限才能启动这个Service。
- `android:process`android:process=":remote"，代表在应用程序里，此时有":"号，当需要该service时，会自动创建新的进程。而如果是android:process="remote"，没有":"分号的，则创建全局进程，不同的应用程序共享该进程。//Service运行的进程的name。正常情况下，应用的所有组件都会在为应用创建的默认进程中运行。该名称与应用软件包的名称相同。

## 三、startService()

### （1）生命周期及相关方法解析

1. `startService(Intent intent)` 其它组件调用来启动service
   1. 参数：Intent-需要包含具体启动的service的完整类名
   2. 当调用startService()后：Service首次启动，则先调用onCreate()，再调用onStartCommand()；Service已经启动，则直接调用onStartCommand()
2. `onCreate()`当Service第一次被创建后立即回调该方法，该方法在整个生命周期 中只会调用一次！
3. `onDestory()`当Service停止后会回调该方法，该方法只会回调一次！
4. `public int onStartCommand (Intent intent,int flags,int startId)`
   1. 当客户端调用startService(Intent)方法时会回调，可多次调用startService()方法， 但不会再创建新的Service对象，而是继续复用前面产生的Service对象，但会继续回调 onStartCommand()方法！
   2. 参数：


| 参数                | 含义                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
|-------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Intent intent** | 在其他组件调用startService()方法启动Service时，传递的一个Intent参数，<br/>然后Service将会在onStartCommand()中接收这个Intent                                                                                                                                                                                                                                                                                                                                                                           |
| **int flags**     | 表示启动请求时是否有额外数据，可选值： <br/>`0`，`START_FLAG_REDELIVERY`，`START_FLAG_RETRY`<br/><br/>**`0`**在正常创建Service的情况下，onStartCommand传入的flags为0<br/>**`START_FLAG_REDELIVERY`**如果onStartCommand()方法的返回值是START_REDELIVER_INTENT，<br/>并且Service被系统kill后，则会重新创建Service，并且调用onStartCommand()<br/>时，<会重传intent，而传入的flags就是START_FLAG_REDELIVERY<br/>**`START_FLAG_RETRY`**Service创建时，onStartCommand()方法未被调用或者没有正<br/>常返回的异常情况下， 再次尝试创建，传入的flags就为START_FLAG_RETRY |
| **int startId**   | startId 用来代表这个唯一的启动请求。可以在stopSelfResult(int startId)中传入这个startId，用来终止Service。                                                                                                                                                                                                                                                                                                                                                                                          |

- 返回值：

| 返回值                            | 含义                                                                                                                                               |
|--------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------|
| **START_STICKY**               | 当Service被系统kill后，系统将会尝试重新创建此Service，一旦创建成<br/>功后将回调onStartCommand方法，但Intent将是null，除非有挂起的Intent，<br/>如PendingIntent。这个状态下比较适用于不执行命令、但无限期运行并等<br/>待作业的媒体播放器或类似服务。 |
| **START_NOT_STICKY**           | 当Service因内存不足而被系统kill后，即使系统内存再次空闲时，系统也<br/>不会尝试重新创建此Service。除非再次调用startService启动此Service。                                                             |
| **START_REDELIVER_INTENT**     | 当Service被系统kill后，系统会自动重启该服务，并重传最后一个 Intent。<br/>适用于主动执行应该立即恢复的作业（例如下载文件）的服务。                                                                          |
| **START_STICKY_COMPATIBILITY** | START_STICKY的兼容版本，不能保证Service被kill后会重启                                                                                                           |

1. `stopSelf()` 自行停止Service运行（自杀式）。
2. `stopSelfResult(int startId)` 只有startId和最后一次启动请求相匹配，Service才会被停止。比如：我们想终止Service的时候又来了个启动请求，这时候是不应该终止的，而我们还没拿到最新请求的startId，如果用stopService的话就直接终止了，而用stopSelfResult方法就会及时避免终止。
3. `stopService(Intent service)` 其它组件调用来停止Service运行（他杀式）。无论启动了多少次Service，只需调用一次StopService即可停掉Service。

### （2）demo

1.自定义Service，重写相关方法：

```java
public class DemoStartService extends Service {
    private static final String TAG = DemoStartService.class.getSimpleName();

    @Override
    public IBinder onBind(Intent intent) {
        // TODO: Return the communication channel to the service.
        Log.i(TAG, "onBind");
        return null;
    }

    @Override
    public void onCreate() {
        Log.i(TAG, "onCreate");
        super.onCreate();
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        Log.i(TAG, "onStartCommand");
        return super.onStartCommand(intent, flags, startId);
    }

    @Override
    public void onDestroy() {
        Log.i(TAG, "onDestroy");
        super.onDestroy();
    }
}
```

2.在清单文件中注册：

```xml
<service
    android:name=".DemoStartService"
    android:enabled="true"
    android:exported="true">
    <intent-filter>
        <action android:name="com.wanda.servicedemo.action.START_SERVICE"/>
    </intent-filter>
</service>
```

3.在其他组件（这里是Activity）中调用startService( )和stopService( )

```java
public class MainActivity extends AppCompatActivity implements View.OnClickListener {

    private static final String TAG = MainActivity.class.getSimpleName();
    private Button mStartServiceButton;
    private Button mStopServiceButton;
    private Intent mIntent;
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);
        mIntent=new Intent(this,DemoStartService.class);
        initViews();
        mStartServiceButton.setOnClickListener(this);
        mStopServiceButton.setOnClickListener(this);
    }

    private void initViews(){
        mStartServiceButton=findViewById(R.id.startService);
        mStopServiceButton=findViewById(R.id.stopService);
    }

    //点击按钮进行startService和stopService操作
    @Override
    public void onClick(View view) {
        switch (view.getId()){
            case R.id.startService:
                Log.i(TAG, "onClick: startService");
                startService(mIntent);
                break;
            case R.id.stopService:
                Log.i(TAG, "onClick: stopService");
                stopService(mIntent);
                break;
        }
    }
}
```

运行截图：

![图2](service_2.png)
_图2_

![图3](service_3.png)
_图3_

从log中可以看出，通过调用startService()启动后Service的生命周期，以及在Service创建后多次调用startService()都会回调 onStartCommand()（如：图3）。并且Service在启动后，Service的生命周期不受其他组件的影响，即使启动它的Activity已经销毁了，Service也仍在运行（如：图4）。

![图4](service_4.png)
_图4_

## 四、bindService()

应用组件通过调用 bindService() 与Service绑定，从而创建长期连接。如需与其他组件进行交互，或需要进程间通信 (IPC) ，则应通过bindService()创建绑定服务。

当首次使用bindService()绑定Service时，系统会实例化一个Service实例，并调用其onCreate()和onBind()方法，然后调用者就可以通过IBinder和Service进行交互了，此后如果再次使用bindService绑定Service，系统不会创建新的Sevice实例，也不会再调用onBind()方法，只会直接把IBinder对象传递给其他后来增加的客户端。（下文demo中有验证）

如果要解除与Service的绑定，只需调用unbindService()，此时onUnbind()和onDestory()将会被调用。假如有多个客户端绑定同一个Service，当所有的客户端都和service解除绑定后，系统会销毁Service。（除非Service也被startService()方法开启）

bindService模式下的Service是与调用者相互关联的，在bindService后，一旦调用者销毁，那么Service也立即终止。

### （1）生命周期及相关方法解析

#### 1.`boolean bindService(Intent service, ServiceConnection conn, int flags)`

注：BroadcastReceiver不能调用该方法。但是可以在已经动态注册的BroadcastReceiver中调用此方法，因为此BroadcastReceiver的寿命捆绑在另一个对象上（注册它的对象）。

- 参数

| 参数                                                                                                      | 含义                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
|---------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Intent service**                                                                                      | 明确标识需要连接的服务。                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| **[ServiceConnection conn](https://developer.android.com/reference/android/content/ServiceConnection)** | 一个ServiceConnection对象，用来监听访问者与Service间的连接情况。 <br/>连接成功回调该对象中的onServiceConnected (ComponentName name, IBinder service)方法；<br/>连接丢失则回调onServiceDisconnected (ComponentName name)方法，<br/>通常发生在Service所在的进程由于异常终止或者其他原因终止，<br/>导致Service与访问者间断开连接时，主动通过unBindService()方法断开并不会调用上述方法!<br/>**onServiceConnected** (ComponentName name, IBinder service)ComponentName name：<br/>已连接的Service的具体组件名称IBinder service：IBinder对象，实现与Service之间的通信。<br/>Service的onBind()方法返回的IBinder对象会传递到此参数，<br/>我们就可以通过这个IBinder对象与Service进行通信。<br/>**onServiceDisconnected** (ComponentName name)ComponentName name：连接丢失的Service的具体组件名称                                                                                                                                                                                                                                                                                       |
| **int flags**                                                                                           | 绑定时的选项。<br/>可能是 0, `BIND_AUTO_CREATE`, `BIND_DEBUG_UNBIND`, `BIND_NOT_FOREGROUND`, `BIND_ABOVE_CLIENT`, `BIND_ALLOW_OOM_MANAGEMENT`, `BIND_WAIVE_PRIORITY`, `BIND_IMPORTANT`, `BIND_ADJUST_WITH_ACTIVITY`, `BIND_NOT_PERCEPTIBLE`, `BIND_INCLUDE_CAPABILITIES`<br/>以下各个flag的含义稍作了解：<br/>BIND_AUTO_CREATE：若绑定服务时服务未启动，则会自动启动服务。 注意，这种情况下服务的onStartCommand仍然未被调用（它只会在显式调用startService时才会被调用）。<br/>BIND_DEBUG_UNBIND：使用此标志绑定服务之后的unBindService方法会无效。 这种方法会引起内存泄露，只能在调试时使用。<br/>BIND_NOT_FOREGROUND：被绑定的服务进程优先级不允许被提到FOREGROUND级别。<br/>BIND_ABOVE_CLIENT：Service 进程比client本身的进程还重要，如果当绑定服务期间遇到OOM需要杀死进程，client进程会先于服务进程被杀死。<br/>BIND_ALLOW_OOM_MANAGEMENT：允许内存管理系统管理 Service 的进程，在内存不足时可以被kill。<br/>BIND_WAIVE_PRIORITY：不影响 Service 进程的优先级的情况下，允许 Service 进程被加入后台队列中。<br/>BIND_IMPORTANT：被绑定的服务进程优先级会被提到FOREGROUND级别。<br/>BIND_ADJUST_WITH_ACTIVITY：如果从一个 Activity 绑定，则这个 Service 进程的优先级和 Activity 是否对用户可见有关。 |

- 返回值

| 返回值     | 含义                                                                                                                                  |
|---------|-------------------------------------------------------------------------------------------------------------------------------------|
| boolean | true：系统正在启动你的client有权绑定的Servicefalse：如果系统不能找到Service或者你的client没有权限去绑定该Service如果这个值是true，则稍后应调用unbindService(ServiceConnection)以释放连接 |


- 抛出

| 抛出                | 解释                                |
|-------------------|-----------------------------------|
| SecurityException | 如果调用方没有访问该Service的权限或找不到该Service。 |



#### 2.`unbindService (ServiceConnection conn)`

- 参数

| 参数                     | 含义                                         |
|------------------------|--------------------------------------------|
| ServiceConnection conn | 之前提供给bindService()的ServiceConnection，值不能为空 |


#### 3.`IBinder onBind (Intent intent)`

当其他组件想通过bindService()绑定Service时，系统会回调这个方法。在自定义的Service中重写该方法时，需要返回一个IBinder对象，供客户端与服务进行通信，但如果Service不允许绑定，则可以返回null。

- 参数

| 参数            | 含义                                                          |
|---------------|-------------------------------------------------------------|
| Intent intent | 调用bindService()时传入的用来绑定该Service的Intent，这里不会看到Intent中包含的其它内容 |



- 返回值

| 返回值     | 含义                                             |
|---------|------------------------------------------------|
| IBinder | 可当客户端与Service连接成功后，客户端通过该IBinder对象与Service进行通信 |



#### 4.`boolean onUnbind (Intent intent)`

默认实现不执行任何操作，并返回false。

- 参数


| 参数            | 含义                                     |
|---------------|----------------------------------------|
| Intent intent | 调用bindService()时传入的用来绑定该Service的Intent |



- 返回值

| 返回值     | 含义                               |
|---------|----------------------------------|
| boolean | true：表示希望客户端下一次绑定时能够调用onRebind() |



#### 5.`onRebind (Intent intent)`

服务未被销毁，再次绑定时回调。前提是 onUnbind() 方法返回true。

### （2）demo：Activity与Service通信

**Step 1：**在自定义的Service中继承Binder，实现自己的Binder对象

**Step 2：**通过onBind()方法返回自己的Binder对象

```java
public class DemoStartService extends Service {
    private static final String TAG = DemoStartService.class.getSimpleName();
    private int mCount;
    private boolean mQuit;
    private MyBinder mBinder = new MyBinder();

    public DemoStartService() {
    }

    @Override
    public IBinder onBind(Intent intent) {
        // TODO: Return the communication channel to the service.
        Log.i(TAG, "onBind");
        return mBinder;
    }

    @Override
    public void onCreate() {
        Log.i(TAG, "onCreate");
        super.onCreate();
        new Thread() {
            public void run() {
                while (!mQuit) {
                    try {
                        Thread.sleep(1000);
                    } catch (InterruptedException e) {
                        e.printStackTrace();
                    }
                    mCount++;
                }
            }
        }.start();
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        Log.i(TAG, "onStartCommand");
        return super.onStartCommand(intent, flags, startId);
    }

    @Override
    public void onDestroy() {
        Log.i(TAG, "onDestroy");
        super.onDestroy();
    }

    public class MyBinder extends Binder {
        public int getCount() {
            return mCount;
        }
    }
}
```

**Step 3：**在绑定该Service的类中定义一个ServiceConnection对象，重写两个方法：onServiceConnected()和onServiceDisconnected()，然后直接读取传递过来的IBinder参数即可。

```java
public class MainActivity extends AppCompatActivity implements View.OnClickListener {

    private static final String TAG = MainActivity.class.getSimpleName();
    private Button mStartServiceButton;
    private Button mStopServiceButton;
    private Button mBindServiceButton;
    private Button mUnbindServiceButton;
    private Button mGetAccountButton;
    private Intent mIntent;
    private DemoStartService.MyBinder mBinder;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);
        Log.i(TAG, "onCreate");
        mIntent = new Intent(this, DemoStartService.class);
        initViews();

    }

    private void initViews() {
        mStartServiceButton = findViewById(R.id.startService);
        mStopServiceButton = findViewById(R.id.stopService);
        mBindServiceButton = findViewById(R.id.bindService);
        mUnbindServiceButton = findViewById(R.id.unbindService);
        mGetAccountButton = findViewById(R.id.getAccount);

        mStartServiceButton.setOnClickListener(this);
        mStopServiceButton.setOnClickListener(this);
        mBindServiceButton.setOnClickListener(this);
        mUnbindServiceButton.setOnClickListener(this);
        mGetAccountButton.setOnClickListener(this);
    }

    //点击按钮进行startService和stopService操作
    @Override
    public void onClick(View view) {
        switch (view.getId()) {
            case R.id.startService:
                Log.i(TAG, "onClick: startService");
                startService(mIntent);
                break;
            case R.id.stopService:
                Log.i(TAG, "onClick: stopService");
                stopService(mIntent);
                break;
            case R.id.bindService:
                Log.i(TAG, "onClick: bindService");
                bindService(mIntent, mConn, BIND_AUTO_CREATE);
                break;
            case R.id.unbindService:
                Log.i(TAG, "onClick: unbindService");
                unbindService(mConn);
                break;
            case R.id.getAccount:
                Log.i(TAG, "onClick: count = " + mBinder.getCount());
        }
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        Log.i(TAG, "onDestroy");
    }

    private ServiceConnection mConn = new ServiceConnection() {

        //Activity与Service连接成功时回调该方法
        @Override
        public void onServiceConnected(ComponentName name, IBinder service) {
            Log.i(TAG, "onServiceConnected");
            mBinder = (DemoStartService.MyBinder) service;
        }

        //Activity与Service断开连接时回调该方法
        @Override
        public void onServiceDisconnected(ComponentName name) {
            Log.i(TAG, "onServiceDisconnected");
        }
    };
}
```

运行截图：

![图5](service_5.png)
_图5_

- 再添加一个Acticity绑定该Service：

![图6](service_6.png)
_图6_

- 从图6日志中可以看出，当首次使用bindService()绑定Service时，系统会实例化一个Service实例，并调用其onCreate()和onBind()方法，此后如果再次使用bindService()绑定Service，系统不会创建新的Sevice实例，也不会再调用onBind()方法，只会直接把IBinder对象传递给其他后来增加的客户端。
- 当所有与Service绑定的组件都调用了unbindService()方法后，系统会销毁Service：

![图7](service_7.png)
_图7_


## 五、IntentService

### （1）定义

IntentService 是Service的子类，用于处理后台异步请求任务。由于Service在主线程，不能进行耗时操作，因此Google提供了IntentService，内部维护了一个子线程来进行操作。用户通过调用 Context.startService(Intent) 发送请求，Service根据请求启动，在IntentService内维护了一个工作线程来处理耗时操作，**当任务执行完后，IntentService会自动停止。**

所有的请求都在同一个工作线程上处理，一次处理一个请求，所以处理完所有的请求可能会花费很长的时间，但由于 IntentService 是另外创建子线程来工作，所以不会阻碍主线程，防止出现ANR。

> **使用场景：**可以用来处理后台长时间的耗时操作，如：文件下载、音乐播放。IntentService已经在Android API 30弃用（对应Android 11）：在Android 8.0增加了[Background execution limits](https://developer.android.google.cn/about/versions/oreo/android-8.0-changes#back-all)，而IntentService受其影响，所以可以考虑使用[WorkManager](https://developer.android.com/reference/androidx/work/WorkManager.html)或[JobIntentService](https://developer.android.com/reference/android/support/v4/app/JobIntentService.html)。
{: .prompt-danger }

### （2）IntentService的使用

以下demo通过IntentService实现在后台循环播放音乐。

#### **2个步骤**

##### **setp1**

创建IntentService的子类，实现onHandleIntent()等方法，并在清单文件中注册

```java
//创建IntentService的子类
public class MusicPlayerService extends IntentService {

    private static final String ACTION_PLAY_MUSIC = "com.wanda.servicedemo.action.PLAY_MUSIC";
    private static final String TAG = MusicPlayerService.class.getSimpleName();

    private MediaPlayer mMediaPlayer;

    public MusicPlayerService() {
        super("MusicPlayerService");
    }

    public static void startPlayer(Context context) {
        Log.i(TAG, "startPlayer");
        Intent intent = new Intent(context, MusicPlayerService.class);
        intent.setAction(ACTION_PLAY_MUSIC);
        context.startService(intent);
    }

    @Override
    protected void onHandleIntent(Intent intent) {
        if (intent != null) {
            final String action = intent.getAction();
            Log.i(TAG, "onHandleIntent: action = " + action);
            if (ACTION_PLAY_MUSIC.equals(action)) {
                handleActionPlayMusic();
            }
        }
    }

    private void handleActionPlayMusic() {
        boolean isMainThread = Looper.getMainLooper().getThread() == Thread.currentThread();
        //打印handle此任务的出当前线程名
        Log.i(TAG, "handleActionPlayMusic： Current Thread is " +
                Thread.currentThread().getName() + 
                " , is MainThread: " + isMainThread);
        if (mMediaPlayer == null) {
            mMediaPlayer = MediaPlayer.create(this, R.raw.record);
            mMediaPlayer.setLooping(true);
            mMediaPlayer.start();
        }
    }

    @Override
    public void onCreate() {
        Log.i(TAG, "onCreate");
        super.onCreate();
    }

    @Override
    public int onStartCommand(@Nullable Intent intent, int flags, int startId) {
        Log.i(TAG, "onStartCommand");
        return super.onStartCommand(intent, flags, startId);
    }

    @Override
    public void onStart(@Nullable Intent intent, int startId) {
        Log.i(TAG, "onStart");
        super.onStart(intent, startId);
    }

    @Override
    public void onDestroy() {
        Log.i(TAG, "onDestroy");
        super.onDestroy();
    }
}
```

并在清单文件中注册：

```XML
<service
    android:name=".MusicPlayerService"
    android:exported="false"></service>
```

##### **setp2**

在 Activity 中通过调用 startService(Intent) 方法发送任务请求

```java
//在Activity添加Button启动IntentService（仅展示部分代码）
case R.id.startIntentService:
    Log.i(TAG, "onClick: startIntentService");
    MusicPlayerService.startPlayer(this);
    break;
```

![图8](service_8.png)
_图8_

从图8日志中可以看出，IntentService在执行完任务后就会自行销毁执行onDestroy()。

### （3）IntentService源码分析

虽然IntentService已经在Android API 30弃用，但是我们还是需要学习其原理。在分析IntentService源码前，需要提前学习Handler相关知识，这可以使我们对IntentService理解得更透彻。如果你已经学习过了Handler，那接下来可以跟我一起分析源码啦。

先看看IntentService类import了什么：

```java
import android.annotation.Nullable;
//WorkerThread注解：表示只能在WorkThread上调用被该注解标记的方法，也就是标记@WorkThread的方法只能在子线程上运行。如果被该注解标记的元素是一个类，那么类中的所有方法都应该在WorkThread上调用。
import android.annotation.WorkerThread;
//UnsupportedAppUsage注解：简单理解为不支持外部应用使用被此注释声明的变量或方法等。
import android.compat.annotation.UnsupportedAppUsage;
import android.content.Intent;
//引入Hnadler说明在IntentService内部的工作方式和Handler息息相关
import android.os.Handler;
import android.os.HandlerThread;
import android.os.IBinder;
import android.os.Looper;
import android.os.Message;
```

接下来看看IntentService是怎么具体实现的吧：

```java
//注解Deprecated表示IntentService被弃用。实际上IntentService在Android API 30（Android 11）被弃用，因为IntentService受Android 8.0推出的后台执行限制所影响。
@Deprecated
public abstract class IntentService extends Service {
    private volatile Looper mServiceLooper;
    @UnsupportedAppUsage
    private volatile ServiceHandler mServiceHandler;
    private String mName;
    private boolean mRedelivery;

    //创建了一个内部类，继承自Handler
    private final class ServiceHandler extends Handler {
        public ServiceHandler(Looper looper) {
            super(looper);
        }

        @Override
        public void handleMessage(Message msg) {
        //处理我们重写的该方
        onHandleIntent((Intent)msg.obj)
        //当执行完任务后，Service就销毁
        stopSelf(msg.arg1);
        }
    }
    
    /**
    * 构造函数
    *
    * @param name 用于命名所在的工作线程名称
    */
    public IntentService(String name) {
        super();
        mName = name;
    }


    /**
     * 设置Intent是否重传，通常在构造函数中调用。
     *
     * 当enabled为true，onStartCommand(Intent,int,int)将返回START_REDELIVER_    INTENT，
     * 且如果在onHandleIntent(Intent)返回前，进程就终止了，则进程将重启并重传intent。
     * 当enabled为false(默认)，onStartCommand(Intent,int,int)将返回START_NOT_STICKY，
     * 如果进程终止，Intent也随之终止。
     *
     */
    public void setIntentRedelivery(boolean enabled) {
        mRedelivery = enabled;
    }

    @Override
    public void onCreate() {
        super.onCreate();
        //HandlerThread就是一个带有Handler的Thread，这里就是创建了一个线程
        HandlerThread thread = new HandlerThread("IntentService[" + mName + "]");
        thread.start();
        //获取这个线程的Looper
        mServiceLooper = thread.getLooper();
        //创建了一个Handler，并给Handler指定了thread的looper，说明此Handler将执行此子线程上的任务
        mServiceHandler = new ServiceHandler(mServiceLooper);
    }

    //将关于Intent的消息发送到队列中给Handler处理
    @Override
    public void onStart(@Nullable Intent intent, int startId) {
        Message msg = mServiceHandler.obtainMessage();
        msg.arg1 = startId;
        msg.obj = intent;
        mServiceHandler.sendMessage(msg);
    }

    //IntentService中不需要重写该方法
    @Override
    public int onStartCommand(@Nullable Intent intent, int flags, int startId) {
        onStart(intent, startId);
        return mRedelivery ? START_REDELIVER_INTENT : START_NOT_STICKY;
    }

    @Override
    public void onDestroy() {
        mServiceLooper.quit();
    }

    @Override
    @Nullable
    public IBinder onBind(Intent intent) {
        return null;
    }
    
    @WorkerThread
    protected abstract void onHandleIntent(@Nullable Intent intent);
}
```

总结：

1. 在 onCreate() 方法中，新建了一个 HandlerThread 对象(thread)，并用HandlerThread创建的Looper创建了一个Handler对象(mServiceHanlder)，使mServiceHanlder和thread的Looper相关联；
2. 在 onStart() 方法中，将 Intent指定到Message，发送给 mServiceHandler，此Intent就是我们通过 startService(Intent) 传入的 Intent。
3. mServiceHanlder 接收到任务请求，调用 onHandleIntent() 方法处理任务请求，处理完所有请求后，调用 stopSelf() 销毁IntentService。

