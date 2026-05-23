package com.zyntro.app

import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)

    MethodChannel(
      flutterEngine.dartExecutor.binaryMessenger,
      APP_CHECK_DEBUG_CHANNEL,
    ).setMethodCallHandler { call, result ->
      when (call.method) {
        APP_CHECK_DEBUG_METHOD -> result.success(getAppCheckDebugSecret())
        else -> result.notImplemented()
      }
    }
  }

  private fun getAppCheckDebugSecret(): String? {
    val persistenceKey = getFirebasePersistenceKey() ?: return null
    val prefsName = APP_CHECK_DEBUG_PREFS_TEMPLATE.format(
      persistenceKey,
    )

    return applicationContext
      .getSharedPreferences(prefsName, Context.MODE_PRIVATE)
      .getString(APP_CHECK_DEBUG_SECRET_KEY, null)
  }

  private fun getFirebasePersistenceKey(): String? {
    return runCatching {
      val firebaseAppClass = Class.forName("com.google.firebase.FirebaseApp")
      val firebaseApp = firebaseAppClass.getMethod("getInstance").invoke(null)

      firebaseAppClass
        .getMethod("getPersistenceKey")
        .invoke(firebaseApp) as? String
    }.getOrNull()
  }

  private companion object {
    const val APP_CHECK_DEBUG_CHANNEL = "zyntro/debug"
    const val APP_CHECK_DEBUG_METHOD = "getAppCheckDebugSecret"
    const val APP_CHECK_DEBUG_PREFS_TEMPLATE =
      "com.google.firebase.appcheck.debug.store.%s"
    const val APP_CHECK_DEBUG_SECRET_KEY =
      "com.google.firebase.appcheck.debug.DEBUG_SECRET"
  }
}
