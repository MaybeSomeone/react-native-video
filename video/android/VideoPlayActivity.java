package com.casstime.ec.video;

import android.media.MediaPlayer;
import android.net.Uri;
import android.os.Bundle;
import android.support.v7.app.AppCompatActivity;
import android.view.View;
import android.widget.ImageButton;
import android.widget.MediaController;
import android.widget.Toast;
import android.widget.VideoView;
import com.casstime.ec.R;

public class VideoPlayActivity extends AppCompatActivity implements View.OnClickListener, MediaPlayer.OnErrorListener {

    private VideoView videoView;
    private Uri videoUri;
    private ImageButton backBtn;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_video_play);

        backBtn = (ImageButton) findViewById(R.id.video_play_back_btn);
        backBtn.setOnClickListener(this);

        videoView = (VideoView) findViewById(R.id.videoView);

        String uri = getIntent().getStringExtra("uri");
        videoUri = Uri.parse(uri);
        videoView.setVideoURI(videoUri);
        videoView.setMediaController(new MediaController(this));
        videoView.setOnPreparedListener(new MediaPlayer.OnPreparedListener() {
            @Override
            public void onPrepared(MediaPlayer mp) {
//                         mp.setLooping(true);
                mp.start();// 播放
//                Toast.makeText(VideoPlayActivity.this, "开始播放！", Toast.LENGTH_LONG).show();
            }
        });

        videoView.setOnCompletionListener(new MediaPlayer.OnCompletionListener() {
            @Override
            public void onCompletion(MediaPlayer mp) {
//                Toast.makeText(VideoPlayActivity.this, "播放完毕", Toast.LENGTH_SHORT).show();
            }
        });
        videoView.setOnErrorListener(this);
    }

    @Override
    public void onClick(View v) {
        this.finish();
    }

    @Override
    public void onBackPressed() {
        this.finish();
    }

    @Override
    public boolean onError(MediaPlayer mp, int what, int extra) {
        if (MediaPlayer.MEDIA_ERROR_IO == what) {
            Toast.makeText(this, "请重新播放视频", 1500).show();
            return true;
        }
        return false;
    }
}
