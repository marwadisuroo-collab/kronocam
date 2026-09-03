package com.kronocam.app;

import android.content.pm.ApplicationInfo;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
	private static final String CHANNEL = "com.kronocam.app/share_apk";

	@Override
	public void configureFlutterEngine(FlutterEngine flutterEngine) {
		super.configureFlutterEngine(flutterEngine);
		new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
				.setMethodCallHandler((call, result) -> {
					if (call.method.equals("getApkPath")) {
						ApplicationInfo applicationInfo = getApplicationInfo();
						result.success(applicationInfo.sourceDir);
					} else {
						result.notImplemented();
					}
				});
	}
}
