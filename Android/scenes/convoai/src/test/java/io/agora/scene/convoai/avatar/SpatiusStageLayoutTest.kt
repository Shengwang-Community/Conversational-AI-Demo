package io.agora.scene.convoai.avatar

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class SpatiusStageLayoutTest {
    @Test fun tallPhoneHasNoUncoveredStripAtTopOrBottom() {
        val stage = SpatiusStageLayout.size(1280, 2772)
        assertEquals(2772, stage.height)
        assertEquals(4928, stage.width)
    }

    @Test fun unfoldingRevealsMoreSceneWithoutZoomingAtTheSameHeight() {
        val compact = SpatiusStageLayout.size(450, 800)
        val expanded = SpatiusStageLayout.size(900, 800)
        assertEquals(compact, expanded)
    }

    @Test fun ultrawideWindowFillsItsWidthAndCropsVerticalOverflow() {
        val stage = SpatiusStageLayout.size(1200, 400)
        assertEquals(675, stage.height)
        assertEquals(1200, stage.width)
    }

    @Test fun narrowSplitWindowKeepsFullHeightAndCropsHorizontalOverflow() {
        val stage = SpatiusStageLayout.size(180, 900)
        assertEquals(900, stage.height)
        assertEquals(1600, stage.width)
    }

    @Test fun phoneTabletFoldableAndSmallWindowAreCoveredWithoutStretching() {
        for ((width, height) in listOf(1280 to 2772, 2208 to 1840, 768 to 1024,
            1024 to 768, 320 to 1024, 90 to 130, 130 to 90, 1 to 1)) {
            val stage = SpatiusStageLayout.size(width, height)
            assertTrue(stage.height >= height)
            assertTrue(stage.width >= width)
            assertTrue(stage.height == height || stage.width == width)
            assertEquals(stage.height * 16.0 / 9.0, stage.width.toDouble(), 1.5)
        }
    }

    @Test fun resizeSequenceHasNoDependenceOnPreviousWindow() {
        val initial = SpatiusStageLayout.size(360, 800)
        SpatiusStageLayout.size(900, 800)
        SpatiusStageLayout.size(180, 900)
        SpatiusStageLayout.size(90, 130)
        assertEquals(initial, SpatiusStageLayout.size(360, 800))
    }

    @Test fun unmeasuredOrInvalidWindowHasNoRenderArea() {
        for ((width, height) in listOf(0 to 800, 360 to 0, -1 to 100)) {
            assertEquals(SpatiusStageLayout.Size(0, 0), SpatiusStageLayout.size(width, height))
        }
    }
}
