package com.casstime.ec.video;

import android.content.Intent;
import android.content.res.Configuration;
import android.graphics.Bitmap;
import android.graphics.PixelFormat;
import android.hardware.Camera;
import android.media.MediaMetadataRetriever;
import android.media.MediaRecorder;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Message;
import android.support.annotation.RequiresApi;
import android.support.v7.app.AppCompatActivity;
import android.util.Base64;
import android.util.Log;
import android.view.MotionEvent;
import android.view.SurfaceHolder;
import android.view.SurfaceView;
import android.view.View;
import android.widget.Button;
import android.widget.ImageButton;
import android.widget.TextView;
import android.widget.Toast;
import com.casstime.ec.R;

import java.io.*;
import java.util.Timer;
import java.util.TimerTask;
import java.util.UUID;

@RequiresApi(api = Build.VERSION_CODES.LOLLIPOP)
public class VideoRecordActivity extends AppCompatActivity implements View.OnClickListener, SurfaceHolder.Callback, MediaRecorder.OnErrorListener, MediaRecorder.OnInfoListener, View.OnTouchListener {

    private ImageButton backBtn;
    private ImageButton recordBtn;
    private TextView timeLabel;
    private SurfaceView surfaceview;
    private SurfaceHolder surfaceHolder;

    private Timer timer;// 计时器
    private MediaRecorder mediaRecorder;

    private Camera camera;
    private String TAG = "video";
    private boolean isRecording = false;
    private String videoFilePath;
    private int duration = 0;
    private Handler updateHandler;
    private View recordBar;
    private View actionBar;
    private Button sendBtn;
    private Button rerecordBtn;
    private ImageButton switchCameraBtn;
    private long startTimestamp;
    private CircleProgress circleProgress;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_video_record);

        recordBar = findViewById(R.id.video_record_bar);
        backBtn = (ImageButton) findViewById(R.id.video_record_back_btn);
        switchCameraBtn = (ImageButton) findViewById(R.id.video_record_switch_btn);
        backBtn.setOnClickListener(this);
        switchCameraBtn.setOnClickListener(this);


        circleProgress = (CircleProgress)findViewById(R.id.progress);
        circleProgress.setMaxProgress(10);
        actionBar = findViewById(R.id.video_record_action_bar);
        sendBtn = (Button) findViewById(R.id.video_send);
        rerecordBtn = (Button) findViewById(R.id.video_rerecord);
        sendBtn.setOnClickListener(this);
        rerecordBtn.setOnClickListener(this);

        recordBtn = (ImageButton) findViewById(R.id.video_record_btn);
        recordBtn.setOnClickListener(this);
//        recordBtn.setOnTouchListener(this);

        timeLabel = (TextView) findViewById(R.id.time_label);
        surfaceview = (SurfaceView) findViewById(R.id.surface_view);
        surfaceview.setZOrderOnTop(false);
        surfaceHolder = surfaceview.getHolder();
        surfaceHolder.setFormat(PixelFormat.TRANSLUCENT);
        surfaceHolder.addCallback(this);
        surfaceHolder.setType(SurfaceHolder.SURFACE_TYPE_PUSH_BUFFERS);
        surfaceHolder.setKeepScreenOn(true);

        updateHandler = new VideoHandler();
    }

    private void generateFileInfo() {
        String nameSeed = UUID.randomUUID().toString();
        String dirPath = getExternalCacheDir() + File.separator + "video";
        String videoName = nameSeed +".mp4";
        videoFilePath = dirPath + File.separator + videoName;
        Log.d(TAG, "生成的视频文件路径为 -> " + videoFilePath);
        File dir = new File(dirPath);
        if (!dir.exists()) {
            dir.mkdirs();
        }
    }

    private void releaseMediaRecorder(){
        if (mediaRecorder != null) {
            mediaRecorder.reset();   // clear recorder configuration
            mediaRecorder.setOnErrorListener(null);
            mediaRecorder.release(); // release the recorder object
            mediaRecorder = null;
        }
    }

    private void releaseCamera(){
        if (camera != null){
            camera.lock();
            camera.setPreviewCallback(null);
            camera.stopPreview();
            camera.release();
            camera = null;
        }
    }

    public Camera getCameraInstance(){
        Camera c = null;
        try {
            c = Camera.open(Camera.CameraInfo.CAMERA_FACING_BACK); // attempt to get a Camera instance
        }
        catch (Exception e){
            // Camera is not available (in use or does not exist)
            e.printStackTrace();
        }
        return c; // returns null if camera is unavailable
    }

    @Override
    public void onClick(View v) {
        if (v == null) {
            return;
        }
        switch (v.getId()) {
            case R.id.video_record_back_btn:
                finish();
                break;
            case R.id.video_record_switch_btn:
                break;
            case R.id.video_record_btn:
                if (isRecording) {
                    long diffTimestamp = System.currentTimeMillis() - startTimestamp;
                    if (diffTimestamp < 1000) {
                        Toast.makeText(this, "录制时间过短", 600).show();
                    } else {
                        stopRecord();
                    }
                }else{
                    startTimestamp = System.currentTimeMillis();
                    startRecord();
                }
                break;
            case R.id.video_rerecord:
                circleProgress.setProgress(0);
                stopRecord();
                initCamera();
                break;
            case R.id.video_send:
                sendMessage();
                break;
            default:
                break;
        }
    }

    private void sendMessage() {
        Intent data = new Intent();

        MediaMetadataRetriever mmr=new MediaMetadataRetriever();
        mmr.setDataSource(videoFilePath);

        ByteArrayOutputStream baos = new ByteArrayOutputStream();

        Bitmap thumbBitmap = mmr.getFrameAtTime(0, MediaMetadataRetriever.OPTION_CLOSEST);
        thumbBitmap.compress(Bitmap.CompressFormat.JPEG, 20, baos);
        String thumbString = Base64.encodeToString(baos.toByteArray(), Base64.DEFAULT);

        File videoFile = new File(videoFilePath);
        int videoDuration = Integer.parseInt(mmr.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION));
//        if (videoDuration % 1000 > 0) videoDuration++;
        videoDuration = videoDuration / 1000;
        if (videoDuration > 10) {
            videoDuration = 10;
        }
        Log.d(TAG, "视频时长："+ videoDuration);

        data.setFlags(VideoModule.VIDEO_RECORD_REQUEST);
        data.putExtra("duration", videoDuration);
        data.putExtra("size", videoFile.length());
        data.putExtra("uri", "file://" + videoFilePath);
        data.putExtra("thumb", thumbString);
        mmr.release();
        setResult(VideoModule.VIDEO_RECORD_REQUEST, data);
        finish();
    }

    private void switchActionBar(){
        int nowState = actionBar.getVisibility();
        if (View.GONE == nowState) {
            actionBar.setVisibility(View.VISIBLE);
            recordBar.setVisibility(View.GONE);
        } else {
            actionBar.setVisibility(View.GONE);
            recordBar.setVisibility(View.VISIBLE);
        }
    }

    private void startRecord() {
        isRecording = true;
        duration = 0;
        generateFileInfo();
        initCamera();
        startRecordVideo();
        timeLabel.setVisibility(View.VISIBLE);
        timeLabel.setText("0秒");
        timer = new Timer();
        timer.schedule(new VideoTimerTask(), 1000, 1000);
        circleProgress.setProgress(0);
        recordBtn.setImageResource(R.drawable.ic_record_video_red);
//        Toast.makeText(this, "录制开始", 1500).show();
    }

    private void stopRecord(){
        isRecording = false;
        releaseCamera();
        releaseMediaRecorder();
        if (timer!=null){
            timer.cancel();
            timer = null;
        }
        switchActionBar();
        timeLabel.setText("轻触按钮开始录制");
        recordBtn.setImageResource(R.drawable.ic_record_video_white);
//            Toast.makeText(this, "录制完成", 1500).show();
    }

    @Override
    protected void onPause() {
        super.onPause();
        if (isRecording){
            stopRecord();
        }
    }

    public void startRecordVideo() {
        camera.unlock();
        mediaRecorder = new MediaRecorder();
        // Step 1: Unlock and set camera to MediaRecorder
        mediaRecorder.reset();
        mediaRecorder.setOnErrorListener(this);
        mediaRecorder.setOnInfoListener(this);
        mediaRecorder.setCamera(camera);
        // Step 2: Set sources
        mediaRecorder.setAudioSource(MediaRecorder.AudioSource.CAMCORDER);
        mediaRecorder.setVideoSource(MediaRecorder.VideoSource.CAMERA);
        // Step 3: Set a CamcorderProfile (requires API Level 8 or higher)
//            mediaRecorder.setProfile(CamcorderProfile.get(CamcorderProfile.QUALITY_HIGH));
        // Set output file format
        mediaRecorder.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4);
        mediaRecorder.setVideoEncoder(MediaRecorder.VideoEncoder.H264);
        mediaRecorder.setAudioEncoder(MediaRecorder.AudioEncoder.AAC);
        mediaRecorder.setVideoSize(640, 480);
        mediaRecorder.setVideoFrameRate(30);
        mediaRecorder.setVideoEncodingBitRate(3 * 1024 * 1024);
        mediaRecorder.setOrientationHint(90);
        mediaRecorder.setMaxDuration(10 * 1000);
        // Step 4: Set output file
        mediaRecorder.setOutputFile(videoFilePath);
        // Step 5: Set the preview output
        mediaRecorder.setPreviewDisplay(surfaceHolder.getSurface());
        try {
            // Step 6: Prepare configured MediaRecorder
            mediaRecorder.prepare();
            mediaRecorder.start();
        } catch (IllegalStateException e) {
            Log.w(TAG, "IllegalStateException preparing MediaRecorder: " + e.getMessage());
            releaseMediaRecorder();
        } catch (IOException e) {
            Log.w(TAG, "IOException preparing MediaRecorder: " + e.getMessage());
            releaseMediaRecorder();
        }
    }

    private void initCamera() {
        if (camera != null) {
            releaseCamera();
        }
        try {
            camera = getCameraInstance();
            Camera.Parameters params = camera.getParameters();
            //设置相机的很速屏幕
            if (this.getResources().getConfiguration().orientation != Configuration.ORIENTATION_LANDSCAPE) {
                params.set("orientation", "portrait");
                camera.setDisplayOrientation(90);
            } else {
                params.set("orientation", "landscape");
                camera.setDisplayOrientation(0);
            }
            //设置聚焦模式
            params.setFocusMode(Camera.Parameters.FOCUS_MODE_CONTINUOUS_VIDEO);
            //缩短Recording启动时间
            params.setRecordingHint(true);
            //是否支持影像稳定能力，支持则开启
            if (params.isVideoStabilizationSupported())
                params.setVideoStabilization(true);
            camera.setParameters(params);
            camera.setPreviewDisplay(surfaceHolder);
            camera.startPreview();
        } catch (IOException e) {
            e.printStackTrace();
        }
    }

    @Override
    public void surfaceCreated(SurfaceHolder holder) {
        surfaceHolder = holder;
        initCamera();
    }

    @Override
    public void surfaceChanged(SurfaceHolder holder, int format, int width, int height) {
        surfaceHolder = holder;
    }

    @Override
    public void surfaceDestroyed(SurfaceHolder holder) {
    }

    @Override
    public void onError(MediaRecorder mr, int what, int extra) {
    }

    @Override
    public void onInfo(MediaRecorder mr, int what, int extra) {
        if (MediaRecorder.MEDIA_RECORDER_INFO_MAX_DURATION_REACHED == what) {
            stopRecord();
        }
    }

    @Override
    public boolean onTouch(View v, MotionEvent event) {
        boolean isConsume = false;
        if (v != null && v.getId() == R.id.video_record_btn) {
            if (event.getAction() == MotionEvent.ACTION_DOWN) {
                isConsume = true;
                startRecord();
            }
            if (event.getAction() == MotionEvent.ACTION_UP) {
                isConsume = true;
                stopRecord();
            }
        }
        return isConsume;
    }

    private class VideoTimerTask extends TimerTask {
        @Override
        public void run() {
            updateHandler.sendEmptyMessage(1);
        }
    }

    private class VideoHandler extends Handler {
        @Override
        public void handleMessage(Message msg) {
            if (duration > 10) return;
            duration++;
            circleProgress.setProgress(duration);
            timeLabel.setText(duration + "秒");
        }
    }
}
