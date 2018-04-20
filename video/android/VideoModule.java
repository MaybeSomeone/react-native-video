package com.casstime.ec.video;

import android.app.Activity;
import android.content.Intent;
import android.util.Log;
import com.facebook.react.bridge.*;
import com.facebook.react.modules.core.DeviceEventManagerModule;

public class VideoModule extends ReactContextBaseJavaModule implements ActivityEventListener {
    public static final int VIDEO_RECORD_REQUEST = 467089;
    private String TAG = "video";

    public VideoModule(ReactApplicationContext reactContext) {
        super(reactContext);
        reactContext.addActivityEventListener(this);
    }

    @Override
    public String getName() {
        return "VideoModule";
    }

    @ReactMethod
    public void navigateVideoPlayScreen(String uri){
        try{
            Activity currentActivity = getCurrentActivity();
            if(null!=currentActivity){
                Intent intent = new Intent(currentActivity,VideoPlayActivity.class);
                intent.putExtra("uri", uri);
                currentActivity.startActivity(intent);
            }
        }catch(Exception e){
            throw new JSApplicationIllegalArgumentException(
                "不能打开Activity : "+e.getMessage());
        }
    }

    @ReactMethod
    public void navigateVideoRecordScreen(){
        try{
            Activity currentActivity = getCurrentActivity();
            if(null!=currentActivity){
                Intent intent = new Intent(currentActivity, VideoRecordActivity.class);
                currentActivity.startActivityForResult(intent, VIDEO_RECORD_REQUEST);
            }
        }catch(Exception e){
            throw new JSApplicationIllegalArgumentException(
                "不能打开Activity : "+e.getMessage());
        }
    }


    @Override
    public void onActivityResult(Activity activity, int requestCode, int resultCode, Intent data) {
        if (requestCode == VIDEO_RECORD_REQUEST && data != null) {
            WritableMap message = Arguments.createMap();
            message.putString("duration", data.getIntExtra("duration", 0) + "");
            message.putString("size", data.getLongExtra("size", 0L) + "");
            message.putString("uri", data.getStringExtra("uri"));
            message.putString("thumb", data.getStringExtra("thumb"));

            getReactApplicationContext()
                .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class)
                .emit("onVideoRecordFinish", message);
        }
    }

    @Override
    public void onNewIntent(Intent intent) {
        if (intent.getFlags() == VideoModule.VIDEO_RECORD_REQUEST) {
            Log.d(TAG, intent.getExtras().toString());
        }
    }
}
