package com.annieha.doobal

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// health 패키지가 Health Connect 권한 요청에 registerForActivityResult를 써서 FragmentActivity가 필요하다.
// 채널 doobal/activity: 걸음 센서(pedometer)용 ACTIVITY_RECOGNITION 런타임 권한을 확인(has)하고 묻는다(request)
class MainActivity : FlutterFragmentActivity() {
    // 묻는 중에 또 부르면 같은 답을 함께 돌려준다
    private val pending = mutableListOf<MethodChannel.Result>()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "has" -> result.success(hasActivityRecognition())
                    "request" -> requestActivityRecognition(result)
                    else -> result.notImplemented()
                }
            }
    }

    // 안드로이드 10(API 29) 미만은 런타임 권한이 아니라 늘 허용
    private fun hasActivityRecognition(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.Q ||
            checkSelfPermission(Manifest.permission.ACTIVITY_RECOGNITION) ==
            PackageManager.PERMISSION_GRANTED

    private fun requestActivityRecognition(result: MethodChannel.Result) {
        if (hasActivityRecognition()) {
            result.success(true)
            return
        }
        pending.add(result)
        if (pending.size == 1) {
            requestPermissions(arrayOf(Manifest.permission.ACTIVITY_RECOGNITION), REQUEST_ACTIVITY)
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != REQUEST_ACTIVITY) return
        val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
        val waiting = pending.toList()
        pending.clear()
        waiting.forEach { it.success(granted) }
    }

    companion object {
        private const val CHANNEL = "doobal/activity"
        private const val REQUEST_ACTIVITY = 4107
    }
}
