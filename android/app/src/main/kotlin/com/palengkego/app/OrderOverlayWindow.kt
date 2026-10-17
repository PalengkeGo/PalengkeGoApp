package com.palengkego.app

import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.animation.ValueAnimator
import android.os.Build
import android.provider.Settings
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.view.WindowManager
import android.view.animation.DecelerateInterpolator
import android.widget.FrameLayout
import android.widget.TextView

/** Android-only chathead shown while PalengkeGo is in the background. */
internal object OrderOverlayWindow {
    private var windowManager: WindowManager? = null
    private var bubble: FrameLayout? = null
    private var badge: TextView? = null

    fun show(context: Context, count: Int) {
        if (count <= 0) {
            hide()
            return
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
            !Settings.canDrawOverlays(context)
        ) return

        val currentBubble = bubble
        if (currentBubble != null) {
            badge?.text = countLabel(count)
            currentBubble.contentDescription =
                "${countLabel(count)} active orders. Tap to open PalengkeGo."
            return
        }

        val manager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        windowManager = manager
        val size = dp(context, 58)
        val root = FrameLayout(context).apply {
            clipChildren = false
            clipToPadding = false
            background = GradientDrawable(
                GradientDrawable.Orientation.TL_BR,
                intArrayOf(0xFF0A604B.toInt(), 0xFF064333.toInt())
            ).apply {
                shape = GradientDrawable.OVAL
                setStroke(dp(context, 2), 0xFFFFFFFF.toInt())
            }
            elevation = dp(context, 8).toFloat()
            contentDescription = "${countLabel(count)} active orders. Tap to open PalengkeGo."
            importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_YES
        }
        root.addView(TextView(context).apply {
            text = "🧾"
            textSize = 25f
            gravity = Gravity.CENTER
            contentDescription = null
        }, FrameLayout.LayoutParams(size, size))

        val countBadge = TextView(context).apply {
            text = countLabel(count)
            textSize = 10f
            setTextColor(0xFFFFFFFF.toInt())
            gravity = Gravity.CENTER
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(0xFFEF4444.toInt())
            }
            elevation = dp(context, 2).toFloat()
        }
        val badgeSize = dp(context, 20)
        root.addView(countBadge, FrameLayout.LayoutParams(badgeSize, badgeSize).apply {
            gravity = Gravity.TOP or Gravity.END
            topMargin = -dp(context, 3)
            marginEnd = -dp(context, 3)
        })
        badge = countBadge

        val params = WindowManager.LayoutParams(
            size,
            size,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else
                WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = context.resources.displayMetrics.widthPixels - size - dp(context, 16)
            y = context.resources.displayMetrics.heightPixels / 2
        }
        root.setOnTouchListener(OverlayTouchListener(context, manager, params, size))
        try {
            manager.addView(root, params)
            bubble = root
        } catch (_: SecurityException) {
            badge = null
        } catch (_: WindowManager.BadTokenException) {
            badge = null
        }
    }

    fun hide() {
        val current = bubble ?: return
        try {
            windowManager?.removeView(current)
        } catch (_: IllegalArgumentException) {
            // Android already removed the view.
        }
        bubble = null
        badge = null
        windowManager = null
    }

    private fun countLabel(count: Int) = if (count > 99) "99+" else count.toString()

    private fun dp(context: Context, value: Int) =
        (value * context.resources.displayMetrics.density).toInt()

    private class OverlayTouchListener(
        context: Context,
        private val manager: WindowManager,
        private val params: WindowManager.LayoutParams,
        private val size: Int
    ) : View.OnTouchListener {
        private val app = context.applicationContext
        private val touchSlop = ViewConfiguration.get(context).scaledTouchSlop
        private var downX = 0f
        private var downY = 0f
        private var startX = 0
        private var startY = 0
        private var moved = false

        override fun onTouch(view: View, event: MotionEvent): Boolean {
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    downX = event.rawX
                    downY = event.rawY
                    startX = params.x
                    startY = params.y
                    moved = false
                    return true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = event.rawX - downX
                    val dy = event.rawY - downY
                    if (!moved && (kotlin.math.abs(dx) > touchSlop || kotlin.math.abs(dy) > touchSlop)) {
                        moved = true
                    }
                    if (moved) {
                        val metrics = app.resources.displayMetrics
                        params.x = (startX + dx.toInt()).coerceIn(0, metrics.widthPixels - size)
                        params.y = (startY + dy.toInt()).coerceIn(
                            OrderOverlayWindow.dp(app, 24),
                            metrics.heightPixels - size - OrderOverlayWindow.dp(app, 48)
                        )
                        try {
                            manager.updateViewLayout(view, params)
                        } catch (_: IllegalArgumentException) {
                            return false
                        }
                    }
                    return true
                }
                MotionEvent.ACTION_UP -> {
                    if (!moved) {
                        app.startActivity(
                            Intent(app, MainActivity::class.java).apply {
                                putExtra("open_active_orders", true)
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or
                                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                                    Intent.FLAG_ACTIVITY_SINGLE_TOP)
                            }
                        )
                    } else {
                        val screenWidth = app.resources.displayMetrics.widthPixels
                        val targetX = if (params.x + size / 2 < screenWidth / 2) {
                            OrderOverlayWindow.dp(app, 8)
                        } else {
                            screenWidth - size - OrderOverlayWindow.dp(app, 8)
                        }
                        ValueAnimator.ofInt(params.x, targetX).apply {
                            duration = 220
                            interpolator = DecelerateInterpolator()
                            addUpdateListener { animation ->
                                params.x = animation.animatedValue as Int
                                try {
                                    manager.updateViewLayout(view, params)
                                } catch (_: IllegalArgumentException) {
                                    cancel()
                                }
                            }
                            start()
                        }
                    }
                    return true
                }
                MotionEvent.ACTION_CANCEL -> return true
            }
            return false
        }
    }
}
