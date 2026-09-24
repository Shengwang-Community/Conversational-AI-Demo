package io.agora.scene.convoai.avatar

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class SpatiusSDKConfigurationTest {
    private val initial = SpatiusConfig("app-a", "avatar-a", "auto")

    @Test
    fun reconnectAndAvatarChangeReuseInitialization() {
        val state = SpatiusSDKConfiguration()
        var calls = 0
        state.initialize(initial) { calls++ }
        state.initialize(initial) { calls++ }
        state.initialize(initial.copy(avatarId = "avatar-b")) { calls++ }
        assertEquals(1, calls)
    }

    @Test
    fun changedAppIdCannotInitializeOrReachModelLoading() {
        assertChangeRejected(initial.copy(appId = "app-b"))
    }

    @Test
    fun changedRegionCannotInitializeOrReachModelLoading() {
        assertChangeRejected(initial.copy(region = "cn-beijing"))
    }

    private fun assertChangeRejected(changed: SpatiusConfig) {
        val state = SpatiusSDKConfiguration()
        var initializations = 0
        var loads = 0
        fun prepare(config: SpatiusConfig) {
            state.initialize(config) { initializations++ }
            loads++
        }
        prepare(initial)
        repeat(2) {
            assertThrows(SpatiusSDKConfiguration.ConfigurationChanged::class.java) { prepare(changed) }
        }
        assertEquals(1, initializations)
        assertEquals(1, loads)
        prepare(initial) // Returning to the original preset still works.
        assertEquals(1, initializations)
        assertEquals(2, loads)
    }

    @Test
    fun initializationFailureDoesNotPinConfiguration() {
        val state = SpatiusSDKConfiguration()
        assertThrows(IllegalStateException::class.java) {
            state.initialize(initial) { error("initialization failed") }
        }
        var calls = 0
        state.initialize(initial.copy(appId = "app-b")) { calls++ }
        assertEquals(1, calls)
    }

    @Test
    fun freshProcessAcceptsChangedConfiguration() {
        SpatiusSDKConfiguration().initialize(initial) {}
        var calls = 0
        SpatiusSDKConfiguration().initialize(initial.copy(appId = "app-b", region = "us-west")) { calls++ }
        assertEquals(1, calls)
    }
}
