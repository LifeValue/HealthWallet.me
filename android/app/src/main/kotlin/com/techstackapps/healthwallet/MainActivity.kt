package com.techstackapps.healthwallet

import com.techstackapps.healthwallet.no_screenshot.ScreenSecurityHandler
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        ScreenSecurityHandler(window).register(flutterEngine)
    }
}
