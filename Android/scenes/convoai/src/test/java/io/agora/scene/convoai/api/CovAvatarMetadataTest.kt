package io.agora.scene.convoai.api

import io.agora.scene.common.util.GsonTools
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class CovAvatarMetadataTest {
    @Test
    fun sceneBackgroundIsDecodedSeparatelyFromPosterAndThumbnail() {
        val avatar = decode(
            """{"thumb_img_url":"thumb.png","bg_img_url":"poster.png","scene_bg_img_url":"scene.png"}"""
        )
        assertEquals("thumb.png", avatar.thumb_img_url)
        assertEquals("poster.png", avatar.bg_img_url)
        assertEquals("scene.png", avatar.scene_bg_img_url)
    }

    @Test
    fun legacyAndEmptySceneBackgroundsDoNotReuseThePoster() {
        for (json in listOf("{}", """{"scene_bg_img_url":null}""")) {
            assertNull(decode(json).scene_bg_img_url)
        }
        assertEquals("", decode("""{"bg_img_url":"poster.png","scene_bg_img_url":""}""").scene_bg_img_url)
    }

    private fun decode(json: String) = requireNotNull(GsonTools.toBean(json, CovAvatar::class.java))
}
