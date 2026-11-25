package org.videolan.vlc.gui.view

import android.content.Context
import android.util.AttributeSet
import android.view.View
import android.widget.FrameLayout

/**
 * Hosts the video view and rotates its content by 90° steps.
 *
 * Only [View] transforms are used here. [android.view.SurfaceView] ignores them (its surface is a
 * separate compositor layer that is only positioned and scaled), so the player has to attach a
 * [android.view.TextureView] to libVLC while the rotation is not 0.
 *
 * For 90°/270° the child is measured as if the window had the swapped aspect ratio, then rotated
 * around its center. libVLC therefore fits the video to the rotated shape instead of cropping it.
 */
class RotatableVideoLayout : FrameLayout {

    var videoRotation: Int = 0
        set(value) {
            val normalized = ((value % 360) + 360) % 360
            if (normalized == field) return
            field = normalized
            requestLayout()
            invalidate()
        }

    constructor(context: Context) : super(context)

    constructor(context: Context, attrs: AttributeSet?) : super(context, attrs)

    constructor(context: Context, attrs: AttributeSet?, defStyleAttr: Int) : super(context, attrs, defStyleAttr)

    private val isSwapped: Boolean
        get() = videoRotation % 180 != 0

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        if (!isSwapped) {
            super.onMeasure(widthMeasureSpec, heightMeasureSpec)
            return
        }
        val width = View.getDefaultSize(suggestedMinimumWidth, widthMeasureSpec)
        val height = View.getDefaultSize(suggestedMinimumHeight, heightMeasureSpec)
        val childWidthSpec = MeasureSpec.makeMeasureSpec(height, MeasureSpec.EXACTLY)
        val childHeightSpec = MeasureSpec.makeMeasureSpec(width, MeasureSpec.EXACTLY)
        for (i in 0 until childCount) {
            val child = getChildAt(i)
            if (child.visibility != View.GONE) child.measure(childWidthSpec, childHeightSpec)
        }
        setMeasuredDimension(width, height)
    }

    override fun onLayout(changed: Boolean, left: Int, top: Int, right: Int, bottom: Int) {
        val width = right - left
        val height = bottom - top
        for (i in 0 until childCount) {
            val child = getChildAt(i)
            if (child.visibility == View.GONE) continue
            val childWidth = child.measuredWidth
            val childHeight = child.measuredHeight
            val childLeft = (width - childWidth) / 2
            val childTop = (height - childHeight) / 2
            child.layout(childLeft, childTop, childLeft + childWidth, childTop + childHeight)
            child.pivotX = childWidth / 2f
            child.pivotY = childHeight / 2f
            child.rotation = videoRotation.toFloat()
        }
    }
}
