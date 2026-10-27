package io.agora.scene.convoai.ui.living

import io.agora.scene.convoai.ui.living.LivingWindowLayout.Bounds
import io.agora.scene.convoai.ui.living.LivingWindowLayout.Divider
import org.junit.Assert.assertEquals
import org.junit.Test

class LivingWindowLayoutTest {
    @Test fun flatWindowUsesAllAvailableSpace() {
        assertEquals(Bounds(0, 0, 900, 800), LivingWindowLayout.pane(900, 800, emptyList()))
    }

    @Test fun verticalHingeKeepsTheWholeCallOnOneSide() {
        val hinge = Divider(Bounds(440, 0, 460, 800), vertical = true)
        assertEquals(Bounds(0, 0, 440, 800), LivingWindowLayout.pane(900, 800, listOf(hinge)))
    }

    @Test fun zeroWidthSeparatingFoldStillSplitsTheWindow() {
        val fold = Divider(Bounds(450, 0, 450, 800), vertical = true)
        assertEquals(Bounds(0, 0, 450, 800), LivingWindowLayout.pane(900, 800, listOf(fold)))
    }

    @Test fun tabletopUsesTheTopPaneWhenBothPanesAreEqual() {
        val fold = Divider(Bounds(0, 390, 900, 410), vertical = false)
        assertEquals(Bounds(0, 0, 900, 390), LivingWindowLayout.pane(900, 800, listOf(fold)))
    }

    @Test fun asymmetricFoldUsesTheLargerPane() {
        val fold = Divider(Bounds(300, -20, 320, 820), vertical = true)
        assertEquals(Bounds(320, 0, 900, 800), LivingWindowLayout.pane(900, 800, listOf(fold)))
    }

    @Test fun multipleHingesChooseACompletePaneRegardlessOfFeatureOrder() {
        val folds = listOf(Divider(Bounds(300, 0, 320, 800), true),
            Divider(Bounds(800, 0, 820, 800), true))
        val expected = Bounds(320, 0, 800, 800)
        assertEquals(expected, LivingWindowLayout.pane(1100, 800, folds))
        assertEquals(expected, LivingWindowLayout.pane(1100, 800, folds.reversed()))
    }

    @Test fun FeaturesOutsideOrNotSpanningTheCurrentWindowDoNotReduceIt() {
        val folds = listOf(Divider(Bounds(950, 0, 960, 800), true),
            Divider(Bounds(400, 200, 410, 600), true))
        assertEquals(Bounds(0, 0, 900, 800), LivingWindowLayout.pane(900, 800, folds))
    }

    @Test fun unfoldingRestoresTheFullWindow() {
        val fold = Divider(Bounds(450, 0, 450, 800), true)
        LivingWindowLayout.pane(900, 800, listOf(fold))
        assertEquals(Bounds(0, 0, 900, 800), LivingWindowLayout.pane(900, 800, emptyList()))
    }
}
