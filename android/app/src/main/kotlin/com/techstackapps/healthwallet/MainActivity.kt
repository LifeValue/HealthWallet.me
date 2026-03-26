package com.techstackapps.healthwallet

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import com.techstackapps.healthwallet.no_screenshot.ScreenSecurityHandler
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private var bluetoothReceiver: BroadcastReceiver? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        ScreenSecurityHandler(window).register(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.techstackapps.healthwallet/bluetooth")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isBluetoothEnabled" -> {
                        val bluetoothManager = getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
                        val adapter = bluetoothManager?.adapter
                        result.success(adapter?.isEnabled == true)
                    }
                    "requestEnable" -> {
                        val intent = Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE)
                        startActivity(intent)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "com.techstackapps.healthwallet/bluetooth_state")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    bluetoothReceiver = object : BroadcastReceiver() {
                        override fun onReceive(context: Context?, intent: Intent?) {
                            if (intent?.action == BluetoothAdapter.ACTION_STATE_CHANGED) {
                                val state = intent.getIntExtra(BluetoothAdapter.EXTRA_STATE, BluetoothAdapter.ERROR)
                                events?.success(state == BluetoothAdapter.STATE_ON)
                            }
                        }
                    }
                    registerReceiver(bluetoothReceiver, IntentFilter(BluetoothAdapter.ACTION_STATE_CHANGED))
                }

                override fun onCancel(arguments: Any?) {
                    if (bluetoothReceiver != null) {
                        unregisterReceiver(bluetoothReceiver)
                        bluetoothReceiver = null
                    }
                }
            })
    }
}
