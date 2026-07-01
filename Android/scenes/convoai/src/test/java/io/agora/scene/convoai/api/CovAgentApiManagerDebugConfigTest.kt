package io.agora.scene.convoai.api

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test

class CovAgentApiManagerDebugConfigTest {

    @Test
    fun buildDebugStartRequestConfig_ignoresDebugConfigWhenDebugIsDisabled() {
        val config = buildDebugStartRequestConfig(
            isDebug = false,
            baseUrl = "https://example.com",
            namespace = "debug-namespace"
        )

        assertNull(config)
    }

    @Test
    fun buildDebugStartRequestConfig_returnsNullWhenDebugConfigIsEmpty() {
        val config = buildDebugStartRequestConfig(
            isDebug = true,
            baseUrl = " ",
            namespace = " "
        )

        assertNull(config)
    }

    @Test
    fun buildDebugStartRequestConfig_usesDebugConfigWhenDebugIsEnabled() {
        val config = buildDebugStartRequestConfig(
            isDebug = true,
            baseUrl = " https://example.com ",
            namespace = " debug-namespace "
        )

        val convoai = config?.get("convoai") as? Map<*, *>
        assertNotNull(convoai)
        assertEquals("https://example.com", convoai?.get("base_url"))
        assertEquals(
            mapOf("X-Service-Namespace" to "debug-namespace"),
            convoai?.get("headers")
        )
    }
}
