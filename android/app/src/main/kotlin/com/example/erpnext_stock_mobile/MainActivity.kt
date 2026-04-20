package com.example.erpnext_stock_mobile

import android.content.Context
import android.content.res.ColorStateList
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.ColorFilter
import android.graphics.Paint
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.Drawable
import android.os.Bundle
import android.util.TypedValue
import android.view.ContextThemeWrapper
import android.view.Gravity
import android.view.Menu
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import com.google.android.material.bottomnavigation.BottomNavigationView
import com.google.android.material.button.MaterialButton
import com.google.android.material.navigation.NavigationBarView
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private var nativeDockHost: NativeDockHostView? = null
    private var nativeDockBridge: NativeDockChannelBridge? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        ensureNativeDockHost()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        ensureNativeDockHost()
        nativeDockBridge = NativeDockChannelBridge(
            messenger = flutterEngine.dartExecutor.binaryMessenger,
            onStateChanged = { state ->
                nativeDockHost?.render(
                    state = state,
                    onTap = { id -> nativeDockBridge?.sendTap(id) },
                    onLongPress = { id -> nativeDockBridge?.sendLongPress(id) },
                )
            },
        )
    }

    private fun ensureNativeDockHost() {
        if (nativeDockHost != null) return
        val content = findViewById<ViewGroup>(android.R.id.content) ?: return
        nativeDockHost = NativeDockHostView(this)
        content.addView(nativeDockHost)
    }
}

private class NativeDockChannelBridge(
    messenger: BinaryMessenger,
    private val onStateChanged: (NativeDockState) -> Unit,
) {
    private val channel = MethodChannel(messenger, "accord/native_dock")

    init {
        channel.setMethodCallHandler(::handleMethodCall)
        channel.invokeMethod("nativeDockReady", true)
    }

    fun sendTap(id: String) {
        channel.invokeMethod("nativeDockTap", id)
    }

    fun sendLongPress(id: String) {
        channel.invokeMethod("nativeDockLongPress", id)
    }

    private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "setDockState" -> {
                val arguments = call.arguments as? Map<*, *> ?: emptyMap<String, Any?>()
                onStateChanged(NativeDockState(arguments))
                result.success(null)
            }

            "isSystemDockSupported" -> result.success(true)
            else -> result.notImplemented()
        }
    }
}

private data class NativeDockState(
    val visible: Boolean,
    val compact: Boolean,
    val tightToEdges: Boolean,
    val items: List<NativeDockItem>,
) {
    constructor(arguments: Map<*, *>) : this(
        visible = arguments["visible"] as? Boolean ?: false,
        compact = arguments["compact"] as? Boolean ?: true,
        tightToEdges = arguments["tightToEdges"] as? Boolean ?: true,
        items = (arguments["items"] as? List<*>)?.mapNotNull {
            (it as? Map<*, *>)?.let(::NativeDockItem)
        } ?: emptyList(),
    )
}

private data class NativeDockItem(
    val id: String,
    val label: String,
    val iconCodePoint: Int,
    val selectedIconCodePoint: Int?,
    val active: Boolean,
    val primary: Boolean,
    val showBadge: Boolean,
    val supportsLongPress: Boolean,
) {
    constructor(arguments: Map<*, *>) : this(
        id = arguments["id"] as? String ?: "",
        label = arguments["label"] as? String ?: "",
        iconCodePoint = (arguments["iconCodePoint"] as? Number)?.toInt() ?: 0,
        selectedIconCodePoint = (arguments["selectedIconCodePoint"] as? Number)?.toInt(),
        active = arguments["active"] as? Boolean ?: false,
        primary = arguments["primary"] as? Boolean ?: false,
        showBadge = arguments["showBadge"] as? Boolean ?: false,
        supportsLongPress = arguments["supportsLongPress"] as? Boolean ?: false,
    )
}

private class NativeDockHostView(
    context: Context,
) : FrameLayout(context) {
    private val menuGroupId = 100
    private var state: NativeDockState = NativeDockState(
        visible = false,
        compact = true,
        tightToEdges = true,
        items = emptyList(),
    )
    private var tapHandler: ((String) -> Unit)? = null
    private var longPressHandler: ((String) -> Unit)? = null
    private var bottomInsetPx: Int = 0
    private val themedContext = ContextThemeWrapper(
        context,
        com.google.android.material.R.style.Theme_Material3_DayNight_NoActionBar,
    )
    private val iconTypeface: Typeface? by lazy {
        runCatching {
            Typeface.createFromAsset(
                context.assets,
                "flutter_assets/fonts/MaterialIcons-Regular.otf",
            )
        }.getOrNull()
    }
    private val dockView = BottomNavigationView(themedContext).apply {
        layoutParams = LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT,
            Gravity.BOTTOM,
        )
        labelVisibilityMode = NavigationBarView.LABEL_VISIBILITY_LABELED
        isItemHorizontalTranslationEnabled = false
        isItemActiveIndicatorEnabled = true
        itemActiveIndicatorColor = ColorStateList.valueOf(COLOR_SELECTED_INDICATOR)
        itemTextColor = buildItemTextColors()
        itemIconTintList = null
        setBackgroundColor(COLOR_DOCK_BACKGROUND)
        elevation = 0f
        isClickable = true
        isFocusable = false
        clipToPadding = false
        setOnItemSelectedListener { item ->
            val targetId = itemIdMap[item.itemId] ?: return@setOnItemSelectedListener false
            tapHandler?.invoke(targetId)
            true
        }
        setOnItemReselectedListener { item ->
            val targetId = itemIdMap[item.itemId] ?: return@setOnItemReselectedListener
            tapHandler?.invoke(targetId)
        }
    }
    private val primaryButton = MaterialButton(
        themedContext,
        null,
        com.google.android.material.R.attr.materialButtonStyle,
    ).apply {
        layoutParams = LayoutParams(
            dp(84f),
            dp(84f),
            Gravity.END or Gravity.BOTTOM,
        ).apply {
            marginEnd = dp(16f)
        }
        insetTop = 0
        insetBottom = 0
        minHeight = 0
        minWidth = 0
        minimumHeight = 0
        minimumWidth = 0
        cornerRadius = dp(22f)
        backgroundTintList = ColorStateList.valueOf(COLOR_PRIMARY_BUTTON)
        setTextColor(COLOR_PRIMARY_CONTENT)
        typeface = iconTypeface
        text = "+"
        setTextSize(TypedValue.COMPLEX_UNIT_SP, 30f)
        gravity = Gravity.CENTER
        elevation = dp(8f).toFloat()
        isCheckable = false
        isClickable = true
        isFocusable = false
        visibility = View.GONE
    }
    private val itemIdMap = LinkedHashMap<Int, String>()

    init {
        layoutParams = LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT,
        )
        clipChildren = false
        clipToPadding = false
        isClickable = false
        isFocusable = false
        visibility = View.GONE
        addView(dockView)
        addView(primaryButton)
        ViewCompat.setOnApplyWindowInsetsListener(this) { _, insets ->
            bottomInsetPx = insets.getInsets(WindowInsetsCompat.Type.systemBars()).bottom
            applyInsets()
            insets
        }
        post { ViewCompat.requestApplyInsets(this) }
    }

    fun render(
        state: NativeDockState,
        onTap: ((String) -> Unit)?,
        onLongPress: ((String) -> Unit)?,
    ) {
        this.state = state
        tapHandler = onTap
        longPressHandler = onLongPress

        if (!state.visible || state.items.isEmpty()) {
            visibility = View.GONE
            dockView.visibility = View.GONE
            primaryButton.visibility = View.GONE
            dockView.menu.clear()
            return
        }

        visibility = View.VISIBLE
        val nonPrimaryItems = state.items.filterNot { it.primary }
        val primaryItem = state.items.firstOrNull { it.primary }

        updateDock(nonPrimaryItems)
        updatePrimaryButton(primaryItem)
        applyInsets()
    }

    private fun updateDock(items: List<NativeDockItem>) {
        dockView.menu.clear()
        itemIdMap.clear()

        if (items.isEmpty()) {
            dockView.visibility = View.GONE
            return
        }

        dockView.visibility = View.VISIBLE
        var selectedMenuId: Int? = null
        items.forEachIndexed { index, item ->
            val menuId = 10_000 + index
            itemIdMap[menuId] = item.id
            val menuItem = dockView.menu.add(menuGroupId, menuId, Menu.NONE, item.label)
            menuItem.isCheckable = true
            menuItem.icon = buildIconDrawable(item)
            menuItem.isChecked = false
            if (item.showBadge) {
                dockView.getOrCreateBadge(menuId).apply {
                    isVisible = true
                    backgroundColor = COLOR_BADGE
                }
            } else {
                dockView.removeBadge(menuId)
            }
            if (item.active) {
                selectedMenuId = menuId
            }
        }
        dockView.menu.setGroupCheckable(menuGroupId, true, true)
        selectedMenuId?.let { dockView.selectedItemId = it }

        dockView.post {
            attachLongPressListeners(items)
        }
    }

    private fun updatePrimaryButton(primaryItem: NativeDockItem?) {
        if (primaryItem == null) {
            primaryButton.visibility = View.GONE
            primaryButton.setOnClickListener(null)
            primaryButton.setOnLongClickListener(null)
            return
        }

        primaryButton.visibility = View.VISIBLE
        primaryButton.text = codePointString(primaryItem.selectedIconCodePoint ?: primaryItem.iconCodePoint)
        primaryButton.setOnClickListener {
            tapHandler?.invoke(primaryItem.id)
        }
        if (primaryItem.supportsLongPress) {
            primaryButton.setOnLongClickListener {
                longPressHandler?.invoke(primaryItem.id)
                true
            }
        } else {
            primaryButton.setOnLongClickListener(null)
        }
    }

    private fun attachLongPressListeners(items: List<NativeDockItem>) {
        val menuView = dockView.getChildAt(0) as? ViewGroup ?: return
        items.forEachIndexed { index, item ->
            val child = menuView.getChildAt(index) ?: return@forEachIndexed
            if (item.supportsLongPress) {
                child.setOnLongClickListener {
                    longPressHandler?.invoke(item.id)
                    true
                }
            } else {
                child.setOnLongClickListener(null)
            }
        }
    }

    private fun applyInsets() {
        val baseHeight = dp(if (state.compact) 60f else 64f)
        dockView.setPadding(
            dockView.paddingLeft,
            dockView.paddingTop,
            dockView.paddingRight,
            bottomInsetPx,
        )
        dockView.minimumHeight = baseHeight + bottomInsetPx
        (primaryButton.layoutParams as? LayoutParams)?.let { params ->
            params.bottomMargin = baseHeight + bottomInsetPx + dp(12f)
            primaryButton.layoutParams = params
        }
    }

    private fun buildItemTextColors(): ColorStateList {
        return ColorStateList(
            arrayOf(
                intArrayOf(android.R.attr.state_checked),
                intArrayOf(),
            ),
            intArrayOf(
                COLOR_SELECTED_CONTENT,
                COLOR_UNSELECTED_CONTENT,
            ),
        )
    }

    private fun buildIconDrawable(item: NativeDockItem): Drawable {
        val selected = MaterialIconDrawable(
            typeface = iconTypeface,
            codePoint = item.selectedIconCodePoint ?: item.iconCodePoint,
            color = COLOR_SELECTED_CONTENT,
            sizePx = dp(24f),
        )
        val unselected = MaterialIconDrawable(
            typeface = iconTypeface,
            codePoint = item.iconCodePoint,
            color = COLOR_UNSELECTED_CONTENT,
            sizePx = dp(24f),
        )
        return android.graphics.drawable.StateListDrawable().apply {
            addState(intArrayOf(android.R.attr.state_checked), selected)
            addState(intArrayOf(), unselected)
        }
    }

    private fun codePointString(codePoint: Int): String {
        if (codePoint == 0) return ""
        return String(Character.toChars(codePoint))
    }

    private fun dp(value: Float): Int {
        return TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            value,
            resources.displayMetrics,
        ).toInt()
    }

    companion object {
        private val COLOR_DOCK_BACKGROUND = Color.parseColor("#241F18")
        private val COLOR_SELECTED_INDICATOR = Color.parseColor("#6F6951")
        private val COLOR_SELECTED_CONTENT = Color.parseColor("#F7EFD5")
        private val COLOR_UNSELECTED_CONTENT = Color.parseColor("#E6DCC9")
        private val COLOR_PRIMARY_BUTTON = Color.parseColor("#A08C59")
        private val COLOR_PRIMARY_CONTENT = Color.parseColor("#FFF8E7")
        private val COLOR_BADGE = Color.parseColor("#D95C5C")
    }
}

private class MaterialIconDrawable(
    typeface: Typeface?,
    codePoint: Int,
    color: Int,
    private val sizePx: Int,
) : Drawable() {
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        this.typeface = typeface
        this.color = color
        textAlign = Paint.Align.CENTER
        textSize = sizePx.toFloat()
    }
    private val text = if (codePoint == 0) "" else String(Character.toChars(codePoint))

    override fun draw(canvas: Canvas) {
        if (text.isEmpty()) return
        val bounds = bounds
        val centerX = bounds.exactCenterX()
        val centerY = bounds.exactCenterY() - ((paint.descent() + paint.ascent()) / 2f)
        canvas.drawText(text, centerX, centerY, paint)
    }

    override fun setAlpha(alpha: Int) {
        paint.alpha = alpha
        invalidateSelf()
    }

    override fun setColorFilter(colorFilter: ColorFilter?) {
        paint.colorFilter = colorFilter
        invalidateSelf()
    }

    @Deprecated("Deprecated in Java")
    override fun getOpacity(): Int = PixelFormat.TRANSLUCENT

    override fun getIntrinsicWidth(): Int = sizePx

    override fun getIntrinsicHeight(): Int = sizePx
}
