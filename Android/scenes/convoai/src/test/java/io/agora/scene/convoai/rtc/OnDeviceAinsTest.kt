package io.agora.scene.convoai.rtc

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class OnDeviceAinsTest {

    @Test
    fun resolve_isDisabledByDefault() {
        assertFalse(OnDeviceAins.resolve(isDebugMode = false, debugEnabled = false))
    }

    @Test
    fun resolve_isEnabledOnlyWhenDebugAndAinsAreEnabled() {
        assertTrue(OnDeviceAins.resolve(isDebugMode = true, debugEnabled = true))
        assertFalse(OnDeviceAins.resolve(isDebugMode = false, debugEnabled = true))
        assertFalse(OnDeviceAins.resolve(isDebugMode = true, debugEnabled = false))
    }

    @Test
    fun rtcParameter_serializesEnabledState() {
        assertEquals("{\"che.audio.sf.enabled\":false}", OnDeviceAins.rtcParameter(false))
        assertEquals("{\"che.audio.sf.enabled\":true}", OnDeviceAins.rtcParameter(true))
    }

    @Test
    fun parametersWithOverride_appliesDisabledAinsAfterRawEnableParameter() {
        val rawParameter = "{\"che.audio.sf.enabled\":true}"

        assertEquals(
            listOf(rawParameter, "{\"che.audio.sf.enabled\":false}"),
            OnDeviceAins.parametersWithOverride(rawParameter, enabled = false)
        )
    }

    @Test
    fun parametersWithOverride_appliesEnabledAinsAfterRawDisableParameter() {
        val rawParameter = "{\"che.audio.sf.enabled\":false}"

        assertEquals(
            listOf(rawParameter, "{\"che.audio.sf.enabled\":true}"),
            OnDeviceAins.parametersWithOverride(rawParameter, enabled = true)
        )
    }
}
