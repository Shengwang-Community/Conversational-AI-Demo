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

    @Test
    fun loadAudioSettings_reappliesCurrentAinsOverrideLast() {
        val parameters = mutableListOf<String>()
        val controller = OnDeviceAinsController(parameters::add)

        controller.loadAudioSettings(enabled = false) {
            parameters += "{\"che.audio.sf.enabled\":true}"
            parameters += "{\"che.audio.sf.stftType\":6}"
        }

        assertEquals("{\"che.audio.sf.enabled\":false}", parameters.last())
    }

    @Test
    fun routeChange_reappliesCurrentAinsOverrideLast() {
        val parameters = mutableListOf<String>()
        val controller = OnDeviceAinsController(parameters::add)
        controller.setEnabled(true)
        parameters.clear()

        parameters += "{\"che.audio.sf.enabled\":false}"
        controller.reapply()

        assertEquals("{\"che.audio.sf.enabled\":true}", parameters.last())
    }
}
