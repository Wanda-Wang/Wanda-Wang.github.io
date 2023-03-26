---
title: SystemUIApplication的创建（基于Android T源码）
date: 2022-11-28 14:10:00 +0800
categories: [Blogging, Android, 源码分析]
tags: [SystemUI]
render_with_liquid: false
---

##### **2.2.1 SystemUIApplication的创建**

![](https://wanda-wang.github.io/assets/img/article/SystemUIApplication的创建.jpg)

###### **2.2.1.1 SystemUI清单文件中**

```xml
<application
    android:name=".SystemUIApplication"
    android:appComponentFactory=".SystemUIAppComponentFactory">
</application>
```

清单文件中属性appComponentFactory的值是.SystemUIAppComponentFactory，PMS会将该属性解析到appInfo.appComponentFactory中。

###### **2.1.1.2 ActivityThread**

```java
@UnsupportedAppUsage
private void handleBindApplication(AppBindData data) {
    Application app;
    //... ...
    try {
        // If the app is being launched for full backup or restore, bring it up in
        // a restricted environment with the base application class.
        app = data.info.makeApplicationInner(data.restrictedBackupMode, null);
    //... ...
    try {
        mInstrumentation.callApplicationOnCreate(app);
    } catch (Exception e) {
        if (!mInstrumentation.onException(app, e)) {
            throw new RuntimeException(
              "Unable to create application " + app.getClass().getName()
              + ": " + e.toString(), e);
            }
        }
    } finally {
    //... ...
    }
}
```
{: file='android.app.ActivityThread#handleBindApplication'}

> **@UnsupportedAppUsage**
{: .prompt-info }
不支持外部应用使用被该注解声明的method or field。


> **app = data.info.makeApplicationInner(data.restrictedBackupMode, null);**
{: .prompt-info }
此处调用了android.app.LoadedApk#makeApplicationInner
对应顺序图，向下追溯最终会调用SystemUIApplication的构造函数，获取到SystemUIApplication实例化对象并赋值给app变量。


> **mInstrumentation.callApplicationOnCreate(app);**
{: .prompt-info }
调用android.app.Instrumentation#callApplicationOnCreate，将上一步makeApplicationInner获取到的SystemUIApplication实例传值到Instrumentation中，调用SystemUIApplication的onCreate()



###### **2.2.1.3 LoadedApk**

```java
/**
 * Local state maintained about a currently loaded .apk.
 * @hide
 */
public final class LoadedApk {
    private Application makeApplicationInner(boolean forceDefaultAppClass,
        Instrumentation instrumentation, boolean allowDuplicateInstances) {
    //... ...
    Application app = null;
    try {
    //... ...
        app = mActivityThread.mInstrumentation.newApplication(
                cl, appClass, appContext);
    //... ...
    } catch (Exception e) {
        if (!mActivityThread.mInstrumentation.onException(app, e)) {
            Trace.traceEnd(Trace.TRACE_TAG_ACTIVITY_MANAGER);
            throw new RuntimeException(
                "Unable to instantiate application " + appClass
                + " package " + mPackageName + ": " + e.toString(), e);
        }
    }
    mActivityThread.mAllApplications.add(app);
    mApplication = app;
    // ... ...
    return app;
    }
}
```
{: file='android.app.LoadedApk'}

> **app = mActivityThread.mInstrumentation.newApplication(cl, appClass, appContext);**
{: .prompt-info }
调用android.app.Instrumentation#newApplication(ClassLoader, String, Context)，获取SystemUIApplication实例


以下在分析可以在看过2.2.1.4 Instrumentation后再看：

```java
public AppComponentFactory getAppFactory() {
    return mAppComponentFactory;
}

private AppComponentFactory createAppFactory(ApplicationInfo appInfo, ClassLoader cl) {
    if (mIncludeCode && appInfo.appComponentFactory != null && cl != null) {
        try {
            return (AppComponentFactory)
                    cl.loadClass(appInfo.appComponentFactory).newInstance();
        } catch (InstantiationException | IllegalAccessException | ClassNotFoundException e) {
            Slog.e(TAG, "Unable to instantiate appComponentFactory", e);
        }
    }
    return AppComponentFactory.DEFAULT;
}
```
{: file='android.app.LoadedApk'}

> **return (AppComponentFactory) cl.loadClass(appInfo.appComponentFactory).newInstance();**
{: .prompt-info }
通过反射ClassLoader.loadClass()获取ApplicationInfo实例的appComponentFactory参数，创建appComponentFactory的实例。
在ApplicationInfo类中有成员变量appComponentFactory：

```java
/**
 * The factory of this package, as specified by the &lt;manifest&gt;
 * tag's {@link android.R.styleable#AndroidManifestApplication_appComponentFactory}
 * attribute.
 */
public String appComponentFactory;
```
{: file='android.content.pm.ApplicationInfo#appComponentFactory'}
和清单文件属性也对应上了！




###### **2.2.1.4 Instrumentation**

```java
/**
 * Perform instantiation of the process's {@link Application} object.  The
 * default implementation provides the normal system behavior.
 * 
 * @param cl The ClassLoader with which to instantiate the object.
 * @param className The name of the class implementing the Application
 *                  object.
 * @param context The context to initialize the application with
 * 
 * @return The newly instantiated Application object.
 */
public Application newApplication(ClassLoader cl, String className, Context context)
        throws InstantiationException, IllegalAccessException, 
        ClassNotFoundException {
    Application app = getFactory(context.getPackageName())
            .instantiateApplication(cl, className);
    app.attach(context);
    return app;
}
```
{: file='android.app.Instrumentation'}

> **getFactory(String pkg)**
{: .prompt-info }
根据包名获取factory：

```java
private AppComponentFactory getFactory(String pkg) {
    if (pkg == null) {
        Log.e(TAG, "No pkg specified, disabling AppComponentFactory");
        return AppComponentFactory.DEFAULT;
    }
    if (mThread == null) {
        Log.e(TAG, "Uninitialized ActivityThread, likely app-created Instrumentation,"
                + " disabling AppComponentFactory", new Throwable());
        return AppComponentFactory.DEFAULT;
    }
    LoadedApk apk = mThread.peekPackageInfo(pkg, true);
    // This is in the case of starting up "android".
    if (apk == null) apk = mThread.getSystemContext().mPackageInfo;
    return apk.getAppFactory();
}
```
{: file='android.app.Instrumentation'}
最终还是调用了LoadedApk中的getAppFactory()，返回3看一下是如何获取到factory的。


> **.instantiateApplication(cl, className);**
{: .prompt-tip }
所以最后调用走到了清单文件加的属性android:appComponentFactory=".SystemUIAppComponentFactory"中，先调用instantiateApplication()。因为SystemUIAppComponentFactory没有重写instantiateApplication，且它继承自androidx的AppComponentFactory，所以先看AppComponentFactory



###### **2.2.1.5 androidx.core.app.AppComponentFactory**

```java
    /**
     * @see #instantiateApplicationCompat
     */
    @NonNull
    @Override
    public final Application instantiateApplication(
            @NonNull ClassLoader cl, @NonNull String className)
            throws InstantiationException, IllegalAccessException, ClassNotFoundException {
        return checkCompatWrapper(instantiateApplicationCompat(cl, className));
    }
```
{: file='androidx.core.app.AppComponentFactory'}
```java
    /**
     * Allows application to override the creation of the application object. This can be used to
     * perform things such as dependency injection or class loader changes to these
     * classes.
     * <p>
     * This method is only intended to provide a hook for instantiation. It does not provide
     * earlier access to the Application object. The returned object will not be initialized
     * as a Context yet and should not be used to interact with other android APIs.
     *
     * @param cl        The default classloader to use for instantiation.
     * @param className The class to be instantiated.
     */
    public @NonNull Application instantiateApplicationCompat(@NonNull ClassLoader cl,
            @NonNull String className)
            throws InstantiationException, IllegalAccessException, ClassNotFoundException {
        try {
            return Class.forName(className, false, cl).asSubclass(Application.class)
                    .getDeclaredConstructor().newInstance();
        } catch (InvocationTargetException | NoSuchMethodException e) {
            throw new RuntimeException("Couldn't call constructor", e);
        }
    }
```
{: file='androidx.core.app.AppComponentFactory'}

> **return Class.forName(className, false, cl).asSubclass(Application.class).getDeclaredConstructor().newInstance();**
{: .prompt-info }
instantiateApplication中调了instantiateApplicationCompat，在instantiateApplicationCompat中创建了SystemUIApplication实例，所以在这里SystemUIApplication构造函数被调用：

```
2022-10-13 17:45:05.205 2388-2388/com.android.systemui V/SystemUIService: SystemUIApplication constructed.
```



###### **2.2.1.6 SystemUIAppComponentFactory**

```java
@NonNull
@Override
public Application instantiateApplicationCompat(
        @NonNull ClassLoader cl, @NonNull String className)
        throws InstantiationException, IllegalAccessException, ClassNotFoundException {
    Application app = super.instantiateApplicationCompat(cl, className);
    if (app instanceof ContextInitializer) {
        ((ContextInitializer) app).setContextAvailableCallback(
                context -> {
                    SystemUIFactory.createFromConfig(context);
                    SystemUIFactory.getInstance().getSysUIComponent().inject(
                            SystemUIAppComponentFactory.this);
                }
        );
    }

    return app;
}
```
{: file='com.android.systemui.SystemUIAppComponentFactory#instantiateApplicationCompat'}

> **super.instantiateApplicationCompat**
{: .prompt-info }
父类androidx.core.app.AppComponentFactory，创建SystemUIApplication实例


> **setContextAvailableCallback**
{: .prompt-info }
1. createFromConfig：通过反射创建SystemUIFactory实例
2. 获取SystemUIFactory实例，通过dagger注入SystemUIAppComponentFactory 
3. com.android.systemui.SystemUIApplication#onCreate中调用ContextAvailable回调：
```java
@Override
public void onCreate() {
    super.onCreate();
    //... ...
    mContextAvailableCallback.onContextAvailable(this);
    //... ...
}
```
{: file='com.android.systemui.SystemUIApplication#onCreate'}
