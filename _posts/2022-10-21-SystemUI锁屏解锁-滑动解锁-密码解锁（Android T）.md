---
title: 锁屏解锁-滑动解锁/密码解锁
date: 2022-11-28 14:10:00 +0800
categories: [Blogging, Android, 源码分析]
tags: [SystemUI, 源码分析]
render_with_liquid: false
---

本文将以Android T为例，列举锁屏解锁方式及流程。

## 一、无

原生有五种屏幕锁定方式，其中“无”就是禁用了锁屏，在代码中可以调用com.android.internal.widget.LockPatternUtils#isLockScreenDisabled判断锁屏是否被禁用。

```java
// com.android.internal.widget.LockPatternUtils#isLockScreenDisabled
/**
 * Determine if LockScreen is disabled for the current user. This is used to decide whether
 * LockScreen is shown after reboot or after screen timeout / short press on power.
 *
 * @return true if lock screen is disabled
 */
@UnsupportedAppUsage
public boolean isLockScreenDisabled(int userId) {
    if (isSecure(userId)) {
        return false;
    }
    boolean disabledByDefault = mContext.getResources().getBoolean(
            com.android.internal.R.bool.config_disableLockscreenByDefault);
    boolean isSystemUser = UserManager.isSplitSystemUser() && userId == UserHandle.USER_SYSTEM;
    UserInfo userInfo = getUserManager().getUserInfo(userId);
    boolean isDemoUser = UserManager.isDeviceInDemoMode(mContext) && userInfo != null
            && userInfo.isDemo();
    return getBoolean(DISABLE_LOCKSCREEN_KEY, false, userId)
            || (disabledByDefault && !isSystemUser)
            || isDemoUser;
}
```

如果锁屏禁用，则会在com.android.systemui.keyguard.KeyguardViewMediator#doKeyguardLocked中判断，锁屏禁用就不显示锁屏。

```java
     /**
     * Enable the keyguard if the settings are appropriate.
     */
    private void doKeyguardLocked(Bundle options) {
    ... ...
            boolean forceShow = options != null && options.getBoolean(OPTION_FORCE_SHOW, false);
            if (mLockPatternUtils.isLockScreenDisabled(KeyguardUpdateMonitor.getCurrentUser())
                    && !lockedOrMissing && !forceShow) {
                if (DEBUG) Log.d(TAG, "doKeyguard: not showing because lockscreen is off");
                return;
            }
        }

        if (DEBUG) Log.d(TAG, "doKeyguard: showing the lock screen");
        showLocked(options);
    }
```

## 二、滑动解锁

> **Android T开始，锁屏滑动解锁部分较Android S有了变化。**
{: .prompt-warning }

S版本及历史版本滑动解锁只能在手指抬起时触发（ACTION_UP），但Android T版本滑动解锁在上滑（ACTION_MOVE）到一定阈值就会触发，不再需要抬手了。且T版本滑动解锁不再调showBouncer，大大简化了滑动解锁流程。以下将着重讲解T上的滑动解锁，历史版本可以看网上文档，如：[上滑解锁流程 - 安卓R](https://blog.csdn.net/SSSxCCC/article/details/119252286)。

那Android T上如何实现滑动解锁的——

1. ### 顺序图

![](https://wanda-wang.github.io/assets/img/unlock/滑动解锁全流程.jpg)

其中showSurfaceBehindKeyguard()会跨进程调用ActivityTaskManagerService#keyguardGoingAway：ActivityTaskManager.getService().keyguardGoingAway(flags)，使得WMS会调用RemoteAnimationRunner#onAnimationStart，也会使锁屏消失，由于是跨进程操作，所以抽出这部分顺序图：

![](https://wanda-wang.github.io/assets/img/unlock/2.jpg)

1. ### 滑动到解锁具体流程

> **touch event**
{: .prompt-info }


从touch事件开始，锁屏的touch事件主要通过NotificationPanelView处理，NotificationPanelView继承PanelView继承FrameLayout。

NotificationPanelView和PanelView上有很多复杂的touch事件，为了弱化view对复杂逻辑的控制，Google将NotificationPanelView和PanelView的touch事件全都放在NotificationPanelViewController和PanelViewController的**TouchHandler**中，而TouchHandler一开始也是在PanelView#onInterceptTouchEvent中调用：

```java
//com.android.systemui.statusbar.phone.PanelView#onInterceptTouchEvent
@Override
public boolean onInterceptTouchEvent(MotionEvent event) {
    return mTouchHandler.onInterceptTouchEvent(event);
}
```

在PanelView#onInterceptTouchEvent中调用TouchHandler.onInterceptTouchEvent(event)，将touch事件全都拦截处理了，所以**PanelView相关的touch事件全都在TouchHandler中实现**。

TouchHandler不过多介绍，想看源码的：[NotificationPanelViewController#createTouchHandler](https://android.googlesource.com/platform/frameworks/base/+/master/packages/SystemUI/src/com/android/systemui/statusbar/phone/NotificationPanelViewController.java#:~:text=protected TouchHandler createTouchHandler() {)、[PanelViewController.TouchHandler](https://android.googlesource.com/platform/frameworks/base/+/master/packages/SystemUI/src/com/android/systemui/statusbar/phone/PanelViewController.java#:~:text=public class TouchHandler implements View.OnTouchListener {)

> **ACTION_MOVE触发滑动解锁**
{: .prompt-info }


```java
//com.android.systemui.statusbar.phone.PanelViewController.TouchHandler
public class TouchHandler implements View.OnTouchListener {

        @Override
        public boolean onTouch(View v, MotionEvent event) {
                case MotionEvent.ACTION_MOVE:
                    addMovement(event);
                    float h = y - mInitialTouchY;

                    // If the panel was collapsed when touching, we only need to check for the
                    // y-component of the gesture, as we have no conflicting horizontal gesture.
                    if (Math.abs(h) > getTouchSlop(event)
                            && (Math.abs(h) > Math.abs(x - mInitialTouchX)
                            || mIgnoreXTouchSlop)) {
                        mTouchSlopExceeded = true;
                        if (mGestureWaitForTouchSlop && !mTracking && !mCollapsedAndHeadsUpOnDown) {
                            if (mInitialOffsetOnTouch != 0f) {
                                startExpandMotion(x, y, false /* startTracking */, mExpandedHeight);
                                h = 0;
                            }
                            cancelHeightAnimator();
                            onTrackingStarted();
                        }
                    }
                    float newHeight = Math.max(0, h + mInitialOffsetOnTouch);
                    newHeight = Math.max(newHeight, mMinExpandHeight);
                    if (-h >= getFalsingThreshold()) {
                        mTouchAboveFalsingThreshold = true;
                        mUpwardsWhenThresholdReached = isDirectionUpwards(x, y);
                    }
                    if ((!mGestureWaitForTouchSlop || mTracking) && !isTrackingBlocked()) {
                        // Count h==0 as part of swipe-up,
                        // otherwise {@link NotificationStackScrollLayout}
                        // wrongly enables stack height updates at the start of lockscreen swipe-up
                        mAmbientState.setSwipingUp(h <= 0);
                        setExpandedHeightInternal(newHeight);
                    }
                    break;
                    ... ...
}
```

当满足没有手势冲突、QS没有展开、bouncer没有消失、已响应滑动事件等情况时，才调用setExpandedHeightInternal。


> **setExpandedHeightInternal**
{: .prompt-info }

```java
// com.android.systemui.statusbar.phone.PanelViewController#setExpandedHeightInternal
public void setExpandedHeightInternal(float h) {
    if (isNaN(h)) {
        Log.wtf(TAG, "ExpandedHeight set to NaN");
    }
    mNotificationShadeWindowController.batchApplyWindowLayoutParams(()-> {
        if (mExpandLatencyTracking && h != 0f) {
            DejankUtils.postAfterTraversal(
                    () -> mLatencyTracker.onActionEnd(LatencyTracker.ACTION_EXPAND_PANEL));
            mExpandLatencyTracking = false;
        }
        float maxPanelHeight = getMaxPanelHeight();
        if (mHeightAnimator == null) {
            // Split shade has its own overscroll logic
            if (mTracking && !mInSplitShade) {
                float overExpansionPixels = Math.max(0, h - maxPanelHeight);
                setOverExpansionInternal(overExpansionPixels, true /* isFromGesture */);
            }
            mExpandedHeight = Math.min(h, maxPanelHeight);
        } else {
            mExpandedHeight = h;
        }

        // If we are closing the panel and we are almost there due to a slow decelerating
        // interpolator, abort the animation.
        if (mExpandedHeight < 1f && mExpandedHeight != 0f && mClosing) {
            mExpandedHeight = 0f;
            if (mHeightAnimator != null) {
                mHeightAnimator.end();
            }
        }
        mExpansionDragDownAmountPx = h;
        mExpandedFraction = Math.min(1f,
                maxPanelHeight == 0 ? 0 : mExpandedHeight / maxPanelHeight);
        onHeightUpdated(mExpandedHeight);
        updatePanelExpansionAndVisibility();
    });
}
```
- **onHeightUpdated**: onHeightUpdated中通过调用positionClockAndNotifications()，在上滑过程动态定位锁屏时钟和通知布局。

- **updatePanelExpansionAndVisibility**: 更新PanelExpansion状态和PanelView可见性。


> **PanelViewController#updatePanelExpansionAndVisibility**
{: .prompt-info }

```java
public void updatePanelExpansionAndVisibility() {
    mPanelExpansionStateManager.onPanelExpansionChanged(
            mExpandedFraction, isExpanded(), mTracking, mExpansionDragDownAmountPx);
    updateVisibility();
}

/** Update the visibility of {@link PanelView} if necessary. */
public void updateVisibility() {
    mView.setVisibility(shouldPanelBeVisible() ? VISIBLE : INVISIBLE);
}
```
- **onPanelExpansionChanged**: 更新PanelView展开状态。
- **updateVisibility**: 更新PanelView可见性：
```java
// com.android.systemui.statusbar.phone.NotificationPanelViewController#shouldPanelBeVisible
@Override
protected boolean shouldPanelBeVisible() {
boolean headsUpVisible = mHeadsUpAnimatingAway || mHeadsUpPinnedMode;
return headsUpVisible || isExpanded() || mBouncerShowing;
}
```

> **CentralSurfacesImpl#onPanelExpansionChanged**
{: .prompt-info }
```java
private void onPanelExpansionChanged(PanelExpansionChangeEvent event) {
    float fraction = event.getFraction();
    boolean tracking = event.getTracking();
    dispatchPanelExpansionForKeyguardDismiss(fraction, tracking);

    if (fraction == 0 || fraction == 1) {
        if (getNavigationBarView() != null) {
            getNavigationBarView().onStatusBarPanelStateChanged();
        }
        if (getNotificationPanelViewController() != null) {
            getNotificationPanelViewController().updateSystemUiStateFlags();
        }
    }
}
```
- **dispatchPanelExpansionForKeyguardDismiss**: 锁屏关注这个方法。

------
> **CentralSurfacesImpl#onPanelExpansionChanged**
{: .prompt-info }

```java
private void dispatchPanelExpansionForKeyguardDismiss(float fraction, boolean trackingTouch) {
    if (!isKeyguardShowing()
            || isOccluded()
            || !mKeyguardStateController.canDismissLockScreen()
            || mKeyguardViewMediator.isAnySimPinSecure()
            || (mNotificationPanelViewController.isQsExpanded() && trackingTouch)) {
        return;
    }

    // Otherwise, we should let the keyguard know about this if we're tracking touch, or if we
    // are already animating the keyguard dismiss (since we will need to either finish or cancel
    // the animation).
    if (trackingTouch
            || mKeyguardViewMediator.isAnimatingBetweenKeyguardAndSurfaceBehindOrWillBe()
            || mKeyguardUnlockAnimationController.isUnlockingWithSmartSpaceTransition()) {
        mKeyguardStateController.notifyKeyguardDismissAmountChanged(
                1f - fraction, trackingTouch);
    }
}
```
- **return**: 以下情况不会解锁：
1. 锁屏不可见
2. 锁屏闭塞（比如锁屏上有其它应用遮挡了）
3. 有锁屏密码，需要输入密码再解锁
4. Sim 锁定，需要输入sim卡密码
5. QS处于展开状态，此时上滑是隐藏QS，而非解锁
   

- **notifyKeyguardDismissAmountChanged**: 当在锁屏界面上滑或锁屏和app/Launcher之间的动画在运行或由于SmartSpace跳转使锁屏正在解锁时，通知锁屏解锁程度发生变化，调用相关回调。

------
> **KeyguardStateControllerImpl#notifyKeyguardDismissAmountChanged**
{: .prompt-info }
```java
@Override
public void notifyKeyguardDismissAmountChanged(float dismissAmount,
        boolean dismissingFromTouch) {
    mDismissAmount = dismissAmount;
    mDismissingFromTouch = dismissingFromTouch;
    new ArrayList<>(mCallbacks).forEach(Callback::onKeyguardDismissAmountChanged);
}
```
- **new ArrayList<>(mCallbacks).forEach(Callback::onKeyguardDismissAmountChanged);**:调用onKeyguardDismissAmountChanged相关实现，目前SystemUI中只有KeyguardUnlockAnimationController#onKeyguardDismissAmountChanged实现了该回调。
   
------
> **KeyguardUnlockAnimationController#onKeyguardDismissAmountChanged**
{: .prompt-info }

```java
    override fun onKeyguardDismissAmountChanged() {
        if (!willHandleUnlockAnimation()) {
            return
        }

        if (keyguardViewController.isShowing && !playingCannedUnlockAnimation) {
            showOrHideSurfaceIfDismissAmountThresholdsReached()

            // If the surface is visible or it's about to be, start updating its appearance to
            // reflect the new dismiss amount.
            if ((keyguardViewMediator.get().requestedShowSurfaceBehindKeyguard() ||
                    keyguardViewMediator.get()
                        .isAnimatingBetweenKeyguardAndSurfaceBehindOrWillBe) &&
                    !playingCannedUnlockAnimation) {
                updateSurfaceBehindAppearAmount()
            }
        }
    }
```
- **willHandleUnlockAnimation()**: 

```java
/**
 * Run Keyguard animation as remote animation in System UI instead of local animation in
 * the server process.
 *
 * 0: Runs all keyguard animation as local animation
 * 1: Only runs keyguard going away animation as remote animation
 * 2: Runs all keyguard animation as remote animation
 *
 * Note: Must be consistent with WindowManagerService.
 */
private static final String ENABLE_REMOTE_KEYGUARD_ANIMATION_PROPERTY =
        "persist.wm.enable_remote_keyguard_animation";
private static final int sEnableRemoteKeyguardAnimation =
        SystemProperties.getInt(ENABLE_REMOTE_KEYGUARD_ANIMATION_PROPERTY, 2);
/**
 * @see #ENABLE_REMOTE_KEYGUARD_ANIMATION_PROPERTY
 */
public static boolean sEnableRemoteKeyguardGoingAwayAnimation =
        sEnableRemoteKeyguardAnimation >= 1;
```
```kotlin
fun willHandleUnlockAnimation(): Boolean {
    return KeyguardService.sEnableRemoteKeyguardGoingAwayAnimation
}
```
如果WindowManagerService赋值0，锁屏消失的远程动画处于禁用状态，则`return;`。
其中WMS赋值`persist.wm.enable_remote_keyguard_animation`：
0-锁屏动画全都运行SystemUI锁屏自己本地动画;
1-只有锁屏消失动画由WMS运行; 
2-锁屏所有动画均运行WMS的远程动画。

- **playingCannedUnlockAnimation**: 正在执行CannedUnlock动画，这个动画是在通过非滑动解锁方式进行解锁时执行，比如指纹解锁、长按lock icon会执行该动画解锁。
- **showOrHideSurfaceIfDismissAmountThresholdsReached()**: 当需要执行远程锁屏消失动画、锁屏正在显示且是滑动解锁时，才执行该方法。
- **updateSurfaceBehindAppearAmount()**: 根据锁屏消失程度更新锁屏后的surface显示程度。
   
------
> **KeyguardUnlockAnimationController#showOrHideSurfaceIfDismissAmountThresholdsReached**
{: .prompt-info }

```java
    /**
     * Lets the KeyguardViewMediator know if the dismiss amount has crossed a threshold of interest,
     * such as reaching the point in the dismiss swipe where we need to make the surface behind the
     * keyguard visible.
     */
    private fun showOrHideSurfaceIfDismissAmountThresholdsReached() {
        if (!featureFlags.isEnabled(Flags.NEW_UNLOCK_SWIPE_ANIMATION)) {
            return
        }

        // If we are playing the canned unlock animation, we flung away the keyguard to hide it and
        // started a canned animation to show the surface behind the keyguard. The fling will cause
        // panel height/dismiss amount updates, but we should ignore those updates here since the
        // surface behind is already visible and animating.
        if (playingCannedUnlockAnimation) {
            return
        }

        if (!keyguardStateController.isShowing) {
            return
        }

        val dismissAmount = keyguardStateController.dismissAmount

        if (dismissAmount >= DISMISS_AMOUNT_SHOW_SURFACE_THRESHOLD &&
            !keyguardViewMediator.get().requestedShowSurfaceBehindKeyguard()) {

            keyguardViewMediator.get().showSurfaceBehindKeyguard()
        } else if (dismissAmount < DISMISS_AMOUNT_SHOW_SURFACE_THRESHOLD &&
                keyguardViewMediator.get().requestedShowSurfaceBehindKeyguard()) {
            // We're no longer past the threshold but we are showing the surface. Animate it
            // out.
            keyguardViewMediator.get().hideSurfaceBehindKeyguard()
            fadeOutSurfaceBehind()
        }

        finishKeyguardExitRemoteAnimationIfReachThreshold()
    }
```
- **当滑动程度到达解锁阈值时：**
1. 使锁屏后的surface可见
2. 隐藏锁屏/解锁
- **showSurfaceBehindKeyguard()：**
```java
public void showSurfaceBehindKeyguard() {
    mSurfaceBehindRemoteAnimationRequested = true;

    try {
        int flags = KEYGUARD_GOING_AWAY_FLAG_NO_WINDOW_ANIMATIONS
                | KEYGUARD_GOING_AWAY_FLAG_WITH_WALLPAPER;

        // If we are unlocking to the launcher, clear the snapshot so that any changes as part
        // of the in-window animations are reflected. This is needed even if we're not actually
        // playing in-window animations for this particular unlock since a previous unlock might
        // have changed the Launcher state.
        if (KeyguardUnlockAnimationController.Companion.isNexusLauncherUnderneath()) {
            flags |= KEYGUARD_GOING_AWAY_FLAG_TO_LAUNCHER_CLEAR_SNAPSHOT;
        }

        ActivityTaskManager.getService().keyguardGoingAway(flags);
        mKeyguardStateController.notifyKeyguardGoingAway(true);
    } catch (RemoteException e) {
        mSurfaceBehindRemoteAnimationRequested = false;
        e.printStackTrace();
    }
}
```
跨进程调用ActivityTaskManagerService的keyguardGoingAway方法，使得ActivityTaskManagerService知道锁屏正在消失，从而使锁屏后的surface可见。
尤其需要注意这行：`ActivityTaskManager.getService().keyguardGoingAway(flags);`，调用keyguardGoingAway后，WMS也会准备surface（
performSurfacePlacement），从而WMS会跨进程调用RemoteAnimationRunner的onAnimationStart方法：
```java
// com.android.server.wm.RemoteAnimationController#goodToGo
mService.mAnimator.addAfterPrepareSurfacesRunnable(() -> {
    try {
        linkToDeathOfRunner();
        ProtoLog.d(WM_DEBUG_REMOTE_ANIMATIONS, "goodToGo(): onAnimationStart,"
                        + " transit=%s, apps=%d, wallpapers=%d, nonApps=%d",
                AppTransition.appTransitionOldToString(transit), appTargets.length,
                wallpaperTargets.length, nonAppTargets.length);
        mRemoteAnimationAdapter.getRunner().onAnimationStart(transit, appTargets,
                wallpaperTargets, nonAppTargets, mFinishedCallback);
    } catch (RemoteException e) {
        Slog.e(TAG, "Failed to start remote animation", e);
        onAnimationFinished();
    }
    if (ProtoLogImpl.isEnabled(WM_DEBUG_REMOTE_ANIMATIONS)) {
        ProtoLog.d(WM_DEBUG_REMOTE_ANIMATIONS, "startAnimation(): Notify animation start:");
        writeStartDebugStatement();
    }
});
```
```java
// com.android.server.wm.RemoteAnimationController#goodToGo
mService.mAnimator.addAfterPrepareSurfacesRunnable(() -> {
    try {
        linkToDeathOfRunner();
        ProtoLog.d(WM_DEBUG_REMOTE_ANIMATIONS, "goodToGo(): onAnimationStart,"
                        + " transit=%s, apps=%d, wallpapers=%d, nonApps=%d",
                AppTransition.appTransitionOldToString(transit), appTargets.length,
                wallpaperTargets.length, nonAppTargets.length);
        mRemoteAnimationAdapter.getRunner().onAnimationStart(transit, appTargets,
                wallpaperTargets, nonAppTargets, mFinishedCallback);
    } catch (RemoteException e) {
        Slog.e(TAG, "Failed to start remote animation", e);
        onAnimationFinished();
    }
    if (ProtoLogImpl.isEnabled(WM_DEBUG_REMOTE_ANIMATIONS)) {
        ProtoLog.d(WM_DEBUG_REMOTE_ANIMATIONS, "startAnimation(): Notify animation start:");
        writeStartDebugStatement();
    }
});
```
**锁屏的onAnimationStart实现中，会调用startKeyguardExitAnimation，这也能使锁屏解锁成功！**

   PS: 我尝试过，在滑动解锁中即使去掉`ActivityTaskManager.getService().keyguardGoingAway(flags);`这行也能解锁成功哦，说明滑动解锁并不完全依赖于startKeyguardExitAnimation，而startKeyguardExitAnimation实际上也会走到下面这些步骤：
所以滑动解锁走了一些重复步骤。
   

------
> **KeyguardUnlockAnimationController#finishKeyguardExitRemoteAnimationIfReachThreshold**
{: .prompt-info }

```java
private fun finishKeyguardExitRemoteAnimationIfReachThreshold() {
    // no-op if keyguard is not showing or animation is not enabled.
    if (!KeyguardService.sEnableRemoteKeyguardGoingAwayAnimation ||
            !keyguardViewController.isShowing) {
        return
    }

    // no-op if animation is not requested yet.
    if (!keyguardViewMediator.get().requestedShowSurfaceBehindKeyguard() ||
            !keyguardViewMediator.get().isAnimatingBetweenKeyguardAndSurfaceBehindOrWillBe) {
        return
    }

    val dismissAmount = keyguardStateController.dismissAmount
    if (dismissAmount >= 1f ||
            (keyguardStateController.isDismissingFromSwipe &&
                    // Don't hide if we're flinging during a swipe, since we need to finish
                    // animating it out. This will be called again after the fling ends.
                    !keyguardStateController.isFlingingToDismissKeyguardDuringSwipeGesture &&
                    dismissAmount >= DISMISS_AMOUNT_EXIT_KEYGUARD_THRESHOLD)) {
        setSurfaceBehindAppearAmount(1f)
        keyguardViewMediator.get().onKeyguardExitRemoteAnimationFinished(false /* cancelled */)
    }
}
```
当满足锁屏显示、远程锁屏消失动画启用、已请求显示锁屏后的surface、正在执行锁屏-app/launcher间的动画等条件时，执行onKeyguardExitRemoteAnimationFinished。

   
------
> **KeyguardViewMediator#onKeyguardExitRemoteAnimationFinished**
{: .prompt-info }


```java
    /**
     * Called when we're done running the keyguard exit animation.
     *
     * This will call {@link #mSurfaceBehindRemoteAnimationFinishedCallback} to let WM know that
     * we're done with the RemoteAnimation, actually hide the keyguard, and clean up state related
     * to the keyguard exit animation.
     *
     * @param cancelled {@code true} if the animation was cancelled before it finishes.
     */
    public void onKeyguardExitRemoteAnimationFinished(boolean cancelled) {
        if (!mSurfaceBehindRemoteAnimationRunning && !mSurfaceBehindRemoteAnimationRequested) {
            return;
        }

        // Block the panel from expanding, in case we were doing a swipe to dismiss gesture.
        mKeyguardViewControllerLazy.get().blockPanelExpansionFromCurrentTouch();
        final boolean wasShowing = mShowing;
        InteractionJankMonitor.getInstance().end(CUJ_LOCKSCREEN_UNLOCK_ANIMATION);

        // Post layout changes to the next frame, so we don't hang at the end of the animation.
        DejankUtils.postAfterTraversal(() -> {
            onKeyguardExitFinished();

            if (mKeyguardStateController.isDismissingFromSwipe() || wasShowing) {
                mKeyguardUnlockAnimationControllerLazy.get().hideKeyguardViewAfterRemoteAnimation();
            }

            finishSurfaceBehindRemoteAnimation(cancelled);
            mSurfaceBehindRemoteAnimationRequested = false;

            // The remote animation is over, so we're not going away anymore.
            mKeyguardStateController.notifyKeyguardGoingAway(false);

            // Dispatch the callback on animation finishes.
            mUpdateMonitor.dispatchKeyguardDismissAnimationFinished();
        });

        mKeyguardUnlockAnimationControllerLazy.get().notifyFinishedKeyguardExitAnimation(
                cancelled);
    }
```

------
> **KeyguardViewMediator#onKeyguardExitRemoteAnimationFinished**
{: .prompt-info }


```kotlin
/**
 * Asks the keyguard view to hide, using the start time from the beginning of the remote
 * animation.
 */
fun hideKeyguardViewAfterRemoteAnimation() {
    if (keyguardViewController.isShowing) {
        // Hide the keyguard, with no fade out since we animated it away during the unlock.

        keyguardViewController.hide(
            surfaceBehindRemoteAnimationStartTime,
            0 /* fadeOutDuration */
        )
    } else {
        Log.e(TAG, "#hideKeyguardViewAfterRemoteAnimation called when keyguard view is not " +
                "showing. Ignoring...")
    }
}
```

最终调用了StatusBarKeyguardViewManager#hide，解锁结束，锁屏就消失了。

------
   

## 三、密码解锁（Pattern/PIN/Password）

Android T滑动解锁不需要抬手，只要手指滑动到阈值就会解锁。但是密码解锁仍是上滑到阈值并抬手后才会完全显示锁屏密码界面(bouncer)。锁屏上滑显示密码解锁界面的流程和滑动解锁流程大致相同，重点看输入密码后解锁的流程。

1. 锁屏后KeyguardBouncer开始prepare，inflate密码解锁相关布局。
2. 锁屏界面上滑显示bouncer，密码解锁布局开始可见：

![](https://wanda-wang.github.io/assets/img/unlock/3.jpg)

1. 抬手验证密码成功并解锁：

![](https://wanda-wang.github.io/assets/img/unlock/4.jpg)
