package io.agora.scene.convoai.ui.living

/** Window-local geometry, independent of display size and device model. */
internal object LivingWindowLayout {
    data class Bounds(val left: Int, val top: Int, val right: Int, val bottom: Int) {
        val width get() = (right - left).coerceAtLeast(0)
        val height get() = (bottom - top).coerceAtLeast(0)
        val area get() = width.toLong() * height
    }

    data class Divider(val bounds: Bounds, val vertical: Boolean)

    /** Keep the complete call UI on the largest pane; ties prefer the top/left pane. */
    fun pane(width: Int, height: Int, dividers: List<Divider>): Bounds {
        val window = Bounds(0, 0, width.coerceAtLeast(0), height.coerceAtLeast(0))
        var panes = listOf(window)
        for ((fold, vertical) in dividers) {
            panes = panes.flatMap { pane ->
                when {
                    vertical && fold.top <= pane.top && fold.bottom >= pane.bottom &&
                        fold.left > pane.left && fold.right < pane.right -> listOf(
                        Bounds(pane.left, pane.top, fold.left, pane.bottom),
                        Bounds(fold.right, pane.top, pane.right, pane.bottom)
                    )
                    !vertical && fold.left <= pane.left && fold.right >= pane.right &&
                        fold.top > pane.top && fold.bottom < pane.bottom -> listOf(
                        Bounds(pane.left, pane.top, pane.right, fold.top),
                        Bounds(pane.left, fold.bottom, pane.right, pane.bottom)
                    )
                    else -> listOf(pane)
                }
            }
        }
        return panes.sortedWith(compareByDescending<Bounds> { it.area }.thenBy { it.top }.thenBy { it.left }).first()
    }
}
