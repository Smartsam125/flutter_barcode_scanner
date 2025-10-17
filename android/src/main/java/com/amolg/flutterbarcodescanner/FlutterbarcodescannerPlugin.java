package com.amolg.flutterbarcodescanner;

import android.app.Activity;
import android.app.Application;
import android.content.Intent;
import android.os.Bundle;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.lifecycle.DefaultLifecycleObserver;
import androidx.lifecycle.Lifecycle;
import androidx.lifecycle.LifecycleOwner;

import com.google.android.gms.common.api.CommonStatusCodes;
import com.google.android.gms.vision.barcode.Barcode;

import java.util.Map;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.EventChannel.StreamHandler;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry.ActivityResultListener;

/**
 * FlutterbarcodescannerPlugin
 */
public class FlutterbarcodescannerPlugin implements FlutterPlugin, MethodCallHandler, ActivityAware, ActivityResultListener, StreamHandler {
  private static final String CHANNEL = "flutter_barcode_scanner";
  private static final String EVENT_CHANNEL = "flutter_barcode_scanner_receiver";
  private static final String TAG = FlutterbarcodescannerPlugin.class.getSimpleName();
  private static final int RC_BARCODE_CAPTURE = 9001;

  // Static fields for barcode configuration
  public static String lineColor = "";
  public static boolean isShowFlashIcon = false;
  public static boolean isContinuousScan = false;
  static EventChannel.EventSink barcodeStream;

  // Instance fields
  private MethodChannel channel;
  private EventChannel eventChannel;
  private FlutterPluginBinding pluginBinding;
  private ActivityPluginBinding activityBinding;
  private Activity activity;
  private Lifecycle lifecycle;
  private LifeCycleObserver observer;
  private Result pendingResult;
  private Map<String, Object> arguments;

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
    pluginBinding = flutterPluginBinding;
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    pluginBinding = null;
  }

  @Override
  public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
    activityBinding = binding;
    setupPlugin(binding);
  }

  @Override
  public void onDetachedFromActivityForConfigChanges() {
    onDetachedFromActivity();
  }

  @Override
  public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {
    onAttachedToActivity(binding);
  }

  @Override
  public void onDetachedFromActivity() {
    teardownPlugin();
  }

  /**
   * Setup the plugin with all necessary components
   */
  private void setupPlugin(ActivityPluginBinding activityBinding) {
    this.activity = activityBinding.getActivity();

    // Setup method channel
    channel = new MethodChannel(pluginBinding.getBinaryMessenger(), CHANNEL);
    channel.setMethodCallHandler(this);

    // Setup event channel for continuous scanning
    eventChannel = new EventChannel(pluginBinding.getBinaryMessenger(), EVENT_CHANNEL);
    eventChannel.setStreamHandler(this);

    // Setup activity result listener
    activityBinding.addActivityResultListener(this);

    // Setup lifecycle observer - get lifecycle directly from binding
    lifecycle = (Lifecycle) activityBinding.getLifecycle();
    observer = new LifeCycleObserver(activity);
    lifecycle.addObserver(observer);
  }

  /**
   * Teardown the plugin and clean up resources
   */
  private void teardownPlugin() {
    if (activityBinding != null) {
      activityBinding.removeActivityResultListener(this);
      activityBinding = null;
    }

    if (lifecycle != null && observer != null) {
      lifecycle.removeObserver(observer);
      lifecycle = null;
      observer = null;
    }

    if (channel != null) {
      channel.setMethodCallHandler(null);
      channel = null;
    }

    if (eventChannel != null) {
      eventChannel.setStreamHandler(null);
      eventChannel = null;
    }

    activity = null;
  }

  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
    try {
      if (call.method.equals("scanBarcode")) {
        handleScanBarcode(call, result);
      } else if (call.method.equals("getPlatformVersion")) {
        result.success("Android " + android.os.Build.VERSION.RELEASE);
      } else {
        result.notImplemented();
      }
    } catch (Exception e) {
      Log.e(TAG, "onMethodCall error: " + e.getLocalizedMessage());
      result.error("ERROR", e.getLocalizedMessage(), null);
    }
  }

  /**
   * Handle the scanBarcode method call
   */
  private void handleScanBarcode(@NonNull MethodCall call, @NonNull Result result) {
    pendingResult = result;

    if (!(call.arguments instanceof Map)) {
      throw new IllegalArgumentException("Plugin not passing a map as parameter: " + call.arguments);
    }

    arguments = (Map<String, Object>) call.arguments;

    // Parse arguments
    lineColor = (String) arguments.get("lineColor");
    if (lineColor == null || lineColor.isEmpty()) {
      lineColor = "#DC143C";
    }

    isShowFlashIcon = arguments.get("isShowFlashIcon") != null
            && (boolean) arguments.get("isShowFlashIcon");

    // Set scan mode
    if (arguments.get("scanMode") != null) {
      int scanMode = (int) arguments.get("scanMode");
      if (scanMode == BarcodeCaptureActivity.SCAN_MODE_ENUM.DEFAULT.ordinal()) {
        BarcodeCaptureActivity.SCAN_MODE = BarcodeCaptureActivity.SCAN_MODE_ENUM.QR.ordinal();
      } else {
        BarcodeCaptureActivity.SCAN_MODE = scanMode;
      }
    } else {
      BarcodeCaptureActivity.SCAN_MODE = BarcodeCaptureActivity.SCAN_MODE_ENUM.QR.ordinal();
    }

    isContinuousScan = arguments.get("isContinuousScan") != null
            && (boolean) arguments.get("isContinuousScan");

    String cancelButtonText = (String) arguments.get("cancelButtonText");
    startBarcodeScannerActivity(cancelButtonText, isContinuousScan);
  }

  /**
   * Start the barcode scanner activity
   */
  private void startBarcodeScannerActivity(String cancelButtonText, boolean isContinuousScan) {
    try {
      Intent intent = new Intent(activity, BarcodeCaptureActivity.class)
              .putExtra("cancelButtonText", cancelButtonText);

      if (isContinuousScan) {
        activity.startActivity(intent);
      } else {
        activity.startActivityForResult(intent, RC_BARCODE_CAPTURE);
      }
    } catch (Exception e) {
      Log.e(TAG, "startBarcodeScannerActivity error: " + e.getLocalizedMessage());
      if (pendingResult != null) {
        pendingResult.error("ERROR", e.getLocalizedMessage(), null);
        pendingResult = null;
      }
    }
  }

  /**
   * Handle activity result from barcode scanner
   */
  @Override
  public boolean onActivityResult(int requestCode, int resultCode, Intent data) {
    if (requestCode == RC_BARCODE_CAPTURE) {
      if (resultCode == CommonStatusCodes.SUCCESS) {
        if (data != null) {
          try {
            Barcode barcode = data.getParcelableExtra(BarcodeCaptureActivity.BarcodeObject);
            if (barcode != null && pendingResult != null) {
              pendingResult.success(barcode.rawValue);
            } else {
              if (pendingResult != null) {
                pendingResult.success("-1");
              }
            }
          } catch (Exception e) {
            Log.e(TAG, "onActivityResult error: " + e.getLocalizedMessage());
            if (pendingResult != null) {
              pendingResult.success("-1");
            }
          }
        } else {
          if (pendingResult != null) {
            pendingResult.success("-1");
          }
        }
      } else {
        if (pendingResult != null) {
          pendingResult.success("-1");
        }
      }

      pendingResult = null;
      arguments = null;
      return true;
    }
    return false;
  }

  /**
   * EventChannel StreamHandler methods for continuous scanning
   */
  @Override
  public void onListen(Object arguments, EventChannel.EventSink events) {
    barcodeStream = events;
  }

  @Override
  public void onCancel(Object arguments) {
    barcodeStream = null;
  }

  /**
   * Receive continuous barcode scans
   */
  public static void onBarcodeScanReceiver(final Barcode barcode) {
    try {
      if (barcode != null && barcode.displayValue != null && !barcode.displayValue.isEmpty()) {
        if (barcodeStream != null) {
          barcodeStream.success(barcode.rawValue);
        }
      }
    } catch (Exception e) {
      Log.e(TAG, "onBarcodeScanReceiver error: " + e.getLocalizedMessage());
    }
  }

  /**
   * Lifecycle observer for activity lifecycle callbacks
   */
  private class LifeCycleObserver implements DefaultLifecycleObserver {
    private final Activity thisActivity;

    LifeCycleObserver(Activity activity) {
      this.thisActivity = activity;
    }

    @Override
    public void onCreate(@NonNull LifecycleOwner owner) {
    }

    @Override
    public void onStart(@NonNull LifecycleOwner owner) {
    }

    @Override
    public void onResume(@NonNull LifecycleOwner owner) {
    }

    @Override
    public void onPause(@NonNull LifecycleOwner owner) {
    }

    @Override
    public void onStop(@NonNull LifecycleOwner owner) {
    }

    @Override
    public void onDestroy(@NonNull LifecycleOwner owner) {
    }
  }
}