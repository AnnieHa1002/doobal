package com.annieha.doobal

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

// health 패키지가 Health Connect 권한 요청에 registerForActivityResult를 써서 FragmentActivity가 필요하다.
// 채널 doobal/activity: 걸음 센서(pedometer)용 ACTIVITY_RECOGNITION 런타임 권한을 확인(has)하고 묻는다(request)
// 채널 doobal/step_detector: 걸음 감지 센서(TYPE_STEP_DETECTOR)가 걸음마다 1을 보낸다 (16장 11/19).
// 걸음 카운터(pedometer step_count)는 걸음을 모아 늦게 보내서, 걷는 중 화면을 걸음마다 바로 움직이려고 같이 듣는다.
// pedometer도 같은 센서를 step_detection 채널로 열 수 있지만 앱은 그 채널(pedestrianStatusStream)을 듣지 않고,
// 듣더라도 SensorManager는 한 센서에 리스너 여럿을 따로 붙여서 서로 값을 빼앗지 않는다
class MainActivity : FlutterFragmentActivity() {
    // 묻는 중에 또 부르면 같은 답을 함께 돌려준다
    private val pending = mutableListOf<MethodChannel.Result>()
    private var detector: StepDetectorHandler? = null

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
        val handler = StepDetectorHandler(
            applicationContext.getSystemService(Context.SENSOR_SERVICE) as SensorManager
        )
        detector = handler
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, DETECTOR_CHANNEL)
            .setStreamHandler(handler)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        detector?.stop()
        detector = null
        super.cleanUpFlutterEngine(flutterEngine)
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
        private const val DETECTOR_CHANNEL = "doobal/step_detector"
        private const val REQUEST_ACTIVITY = 4107
    }
}

// 걸음 감지 센서를 듣는 동안만 켠다. 센서가 없으면 오류를 한 번 보내고 끝낸다 (앱은 카운터만 쓴다).
// 리스너는 기본으로 메인 스레드에서 불려서 그대로 sink에 보낸다
private class StepDetectorHandler(private val sensors: SensorManager) :
    EventChannel.StreamHandler, SensorEventListener {
    private var sink: EventChannel.EventSink? = null

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        stop()
        val sensor = sensors.getDefaultSensor(Sensor.TYPE_STEP_DETECTOR)
        if (sensor == null) {
            events.error("unavailable", "걸음 감지 센서가 없다", null)
            return
        }
        sink = events
        sensors.registerListener(this, sensor, SensorManager.SENSOR_DELAY_FASTEST)
    }

    override fun onCancel(arguments: Any?) = stop()

    fun stop() {
        if (sink == null) return
        sensors.unregisterListener(this)
        sink = null
    }

    // 감지 센서는 걸음 하나마다 값 1.0을 한 번 보낸다
    override fun onSensorChanged(event: SensorEvent) {
        sink?.success(1)
    }

    override fun onAccuracyChanged(sensor: Sensor, accuracy: Int) {}
}
