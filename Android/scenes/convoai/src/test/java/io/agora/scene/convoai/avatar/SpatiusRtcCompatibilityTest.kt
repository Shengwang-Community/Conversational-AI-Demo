package io.agora.scene.convoai.avatar

import ai.spatius.avatarkit.rtc.providers.AgoraProvider
import io.agora.rtc2.video.IVideoEncodedFrameObserver
import java.lang.reflect.Modifier
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class SpatiusRtcCompatibilityTest {
    @Test fun spatiusImplementsTheRuntimeRtcEncodedFrameCallback() {
        // AvatarKitRTC declares Agora as compileOnly. Gradle can otherwise resolve an older
        // RTC whose callback has a different signature, silently breaking mouth animation.
        val contract = IVideoEncodedFrameObserver::class.java
        val observer = AgoraProvider::class.java.declaredFields
            .map { it.type }
            .single { contract.isAssignableFrom(it) }
        val callbacks = contract.methods.filter { Modifier.isAbstract(it.modifiers) }
        assertTrue("RTC must expose its encoded-frame callback", callbacks.isNotEmpty())
        for (callback in callbacks) {
            val implementation = observer.getMethod(callback.name, *callback.parameterTypes)
            assertFalse(
                "Spatius does not implement the resolved RTC callback: $callback",
                Modifier.isAbstract(implementation.modifiers),
            )
        }
    }
}
