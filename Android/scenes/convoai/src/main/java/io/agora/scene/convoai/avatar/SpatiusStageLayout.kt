package io.agora.scene.convoai.avatar

import kotlin.math.max
import kotlin.math.roundToInt

/** Cover the viewport with the SDK's 16:9 stage, cropping overflow without stretching. */
internal object SpatiusStageLayout {
    data class Size(val width: Int, val height: Int)

    fun size(viewportWidth: Int, viewportHeight: Int): Size {
        if (viewportWidth <= 0 || viewportHeight <= 0) return Size(0, 0)
        // Never cap the height by a portrait ratio: tall phones would leave a strip uncovered.
        val height = max(viewportHeight.toDouble(), viewportWidth * 9.0 / 16.0)
        return Size((height * 16.0 / 9.0).roundToInt(), height.roundToInt())
    }
}
