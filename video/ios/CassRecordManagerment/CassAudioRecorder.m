//
//  CassAudioRecorder.m
//  recordDemo
//
//  Created by 谢志敏 on 2018/2/7.
//  Copyright © 2018年 谢志敏. All rights reserved.
//

#import "CassAudioRecorder.h"

static CassAudioRecorder  *single = nil;

@interface CassAudioRecorder()<AVAudioRecorderDelegate, AVAudioPlayerDelegate> {
    StopAudioRecorder _stopAudioRecorder;
    
    AudioPlayerIsFinishOrStop _audioPlayerIsFinishOrStop;
    
    NSTimer *_maxTimer;
    
    AVAudioSession *_session;
}

@end

@implementation CassAudioRecorder

// 单例模式创建
+ (instancetype)shareCassAudioRecorder {
    @synchronized(self) {
        if (single == nil) {
            single = [[self alloc] init];
        }
    }
    return  single;
}

- (instancetype)init {
    if (self = [super init]) {
        [self audio];
    }
    return self;
}

// 录音设置
- (void)audio {
    //录音设置
    NSMutableDictionary *recordSetting = [[NSMutableDictionary alloc]init];
    
    //设置录音格式  AVFormatIDKey==kAudioFormatLinearPCM
    [recordSetting setValue:[NSNumber numberWithInt:kAudioFormatLinearPCM] forKey:AVFormatIDKey];
    //设置录音采样率(Hz) 如：AVSampleRateKey==8000/44100/96000（影响音频的质量）
    [recordSetting setValue:[NSNumber numberWithFloat:8000] forKey:AVSampleRateKey];
    //录音通道数  1 或 2
    [recordSetting setValue:[NSNumber numberWithInt:1] forKey:AVNumberOfChannelsKey];
    //线性采样位数  8、16、24、32
    [recordSetting setValue:[NSNumber numberWithInt:16] forKey:AVLinearPCMBitDepthKey];
    //录音的质量
    [recordSetting setValue:[NSNumber numberWithInt:AVAudioQualityMedium] forKey:AVEncoderAudioQualityKey];
    
    // 我们这边录制的音频格式为WAV格式，因此先保存至WAV文件路径下
    NSURL *wavUrl = [NSURL fileURLWithPath:WAV_PATH];
    
    NSError *error;
    
    // 初始化recorder
    recorder = [[AVAudioRecorder alloc] initWithURL:wavUrl settings:recordSetting error:&error];
    
    // 开启音量检测
    [recorder setDelegate:self];
    [recorder setMeteringEnabled:YES];
    
    // 判断版本是否大于 7.0 大于则需要询问
    if ([[[UIDevice currentDevice] systemVersion] compare:@"7.0"]!=NSOrderedAscending) {
        // iOS 7.0第一次运行会询问是否允许使用麦克风， 我们生成音频会话者
        _session = [AVAudioSession sharedInstance];
        
        
        NSError *sessionError;
        //AVAudioSessionCategoryPlayAndRecord用于录音和播放
        [_session setCategory:AVAudioSessionCategoryPlayAndRecord error:&sessionError];
        
        if(_session == nil) {
                // 生成绘画失败的情况则是不允许访问麦克风时产生的情况
        } else
            
        [_session setActive:YES error:nil];
    }
}

/**
 *  开始录音
 *
 *  @param volumeChangedBlock 当前话筒音量监听
 */
- (void)startAudioRecorderWithMaxDuration:(double)duration VolumeChangeBlock:(VolumeChangedBlock)volumeChangedBlock :(StopAudioRecorder)stopAudioRecorder {

    _session = [AVAudioSession sharedInstance];
    [_session setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
    [_session setActive:YES error:nil];
    // 如果再录制过程中再次调用录制，则直接返回
    if ([recorder isRecording]) {
        return;
    }
    
    // 点击录制但是仍然在播放
    if ([_avPlayer isPlaying]) {
        [self stopPlay];
    }
    
    // 返回录音内容需要在录音之前进行
    _stopAudioRecorder = stopAudioRecorder;
    
    if ([recorder prepareToRecord]) {
        // 开始
        _maxTimer = [NSTimer scheduledTimerWithTimeInterval:duration/1000 + 2 target:self selector:@selector(toMaxDurationStopRecord) userInfo:nil repeats:NO];
        [recorder record];
    }
    
    // 这里返回平均时间内的音频大小
    if (volumeChangedBlock != nil) {
        _volumeChangedBlock = [volumeChangedBlock copy];
    } else  {
        _volumeChangedBlock = nil;
    }
    
    // 设置定时器
    _timer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(detectionVoice) userInfo:nil repeats:YES];
}

- (void)toMaxDurationStopRecord {
    [self stopAudioRecorderWithStopAudioRecorder];
}


/**
*  停止录音的方法
*
*  @return 如果返回nil说明录制时间小于1秒，否则放回_amr文件路径
*/

/**
 *  停止录音的方法
 *
 */
- (void)stopAudioRecorderWithStopAudioRecorder {
    if (_maxTimer) {
        _maxTimer = nil;
    }
    
    if (!_stopAudioRecorder) {
        return;
    }
    
    double cTime = recorder.currentTime;
    if (cTime > MIN_TIME) {//如果录制时间<2 不发送
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            // 音频转码
            // wav 格式音频转为 amr 格式音频
            [VoiceConvert ConvertWavToAmr:WAV_PATH amrSavePath:AMR_PATH];
            NSData *data = [NSData dataWithContentsOfFile:AMR_PATH];
            NSString *base64 = [CassAudioRecorder getBase64StringWithData:data];
            dispatch_async(dispatch_get_main_queue(), ^{
                [recorder stop];
                [_timer invalidate];
                _stopAudioRecorder(YES, base64, cTime*1000 );
                _stopAudioRecorder = nil;
            });
        });
    } else {
        //删除记录的文件
        [self deleteRecording];
        _stopAudioRecorder(NO, @"", 0);
        _stopAudioRecorder = nil;
    }
}

/**
 *  删除录制文件
 */
- (void)deleteRecording {
    // 删除录制文件
    [recorder stop];
    [_timer invalidate];
    [recorder deleteRecording];
    
    // 删除转码的文件
    NSFileManager *fileManager = [NSFileManager defaultManager];
    [fileManager removeItemAtPath:AMR_PATH error:nil];
}


- (void)detectionVoice {
    [recorder updateMeters];
    // 获取音量平均值
    // 音量的最大值
    
    double lowPassResults = pow(10, (0.05 * [recorder peakPowerForChannel:0]));
    float result  = 10 * (float)lowPassResults;
    //    NSLog(@"%f", result);
    int no = 0;
    if (result > 0 && result <= 0.8) {
        no = 1;
    } else if (result > 0.8 && result <= 1.6) {
        no = 2;
    } else if (result > 1.6 && result <= 2.4) {
        no = 3;
    } else if (result > 2.4 && result <= 3.2) {
        no = 4;
    } else if (result > 4.0 && result <= 4.8) {
        no = 5;
    } else if (result > 4.8 && result <= 5.6) {
        no = 6;
    } else if (result > 5.6) {
        no = 7;
    }
    
    _volumeChangedBlock(no, recorder.currentTime);
}

/**
 *  播放音频文件
 *
 *  @param urlString 音频文件的地址
 *  @param isAmr     当前音频文件是否是amr格式的，如果是自动转码成wav
 */
- (void)playerAudioRecorderWithPlayerUrl:(NSString *)urlString amrToWav:(BOOL)isAmr {
    if (isAmr == YES) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            // 音频转码
            [VoiceConvert ConvertAmrToWav:urlString wavSavePath:WAV_PATH];
            dispatch_async(dispatch_get_main_queue(), ^{
                _avPlayer = [[AVAudioPlayer alloc]initWithContentsOfURL:[NSURL fileURLWithPath:WAV_PATH] error:nil];
                _avPlayer.volume=1.0;
                [_avPlayer play];
            });
        });
    } else {
        _avPlayer = [[AVAudioPlayer alloc]initWithContentsOfURL:[NSURL fileURLWithPath:urlString] error:nil];
        _avPlayer.volume=1.0;
        [_avPlayer play];
    }
}

- (void)playAudioRecordWithBase64:(NSString *)base64 isComplete:(AudioPlayerIsFinishOrStop)audioPlayerIsFinishOrStop {

    BOOL isPlay = [_avPlayer isPlaying];
    if (isPlay) {
        audioPlayerIsFinishOrStop(true);
        [_avPlayer stop];
    }
    
    _session = [AVAudioSession sharedInstance];
    [_session overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:nil];
    [_session setActive:YES error:nil];
    
    // 切换播放模式，使播放声音变大
    _audioPlayerIsFinishOrStop = audioPlayerIsFinishOrStop;
    NSData *base64Data = [[NSData alloc]initWithBase64EncodedString:base64 options:NSDataBase64DecodingIgnoreUnknownCharacters];
    [base64Data writeToFile:BASE64_PATH atomically:YES];
    [VoiceConvert ConvertAmrToWav:BASE64_PATH wavSavePath:WAV_PATH];
    dispatch_async(dispatch_get_main_queue(), ^{
        _avPlayer = [[AVAudioPlayer alloc]initWithContentsOfURL:[NSURL fileURLWithPath:WAV_PATH] error:nil];
        [_avPlayer setDelegate:self];
        [_avPlayer setVolume:1.0];
        [_avPlayer setNumberOfLoops:0];
        [_avPlayer prepareToPlay];
        [_avPlayer play];
    });
}

- (void)stopPlay {
    if ([_avPlayer isPlaying]) {
        _audioPlayerIsFinishOrStop(true);
        [_avPlayer stop];
        _audioPlayerIsFinishOrStop = nil;
    }
}

// 转换成base64字符串形式方法
#pragma mark - 根据NSData对象获取对应的Base64String
+ (NSString *)getBase64StringWithData:(NSData *)uploadData {
    
    NSStringEncoding enc = CFStringConvertEncodingToNSStringEncoding(NSUTF16BigEndianStringEncoding);
    
    NSString *str_iso_8859_1 = [[NSString alloc] initWithData:uploadData encoding:enc];
    
    NSData *data_iso_8859_1 = [str_iso_8859_1 dataUsingEncoding:enc];
    
    //    Byte *byte = (Byte *)[data_iso_8859_1 bytes];
    
    //    for (int i=0 ; i<[data_iso_8859_1 length]; i++) {
    //        NSLog(@"byte = %d",byte[i]);
    //    }
    
    NSString *str_base64 = [data_iso_8859_1 base64EncodedStringWithOptions:0];
    
    return str_base64;
}

#pragma mark - AVAudioPlayerDelegate(内部处理方法)
- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
    if (flag) {
        _audioPlayerIsFinishOrStop(true);
        _audioPlayerIsFinishOrStop = nil;
    }
}

#pragma mark - AVAudioRecorderDelegate
- (void)audioRecorderDidFinishRecording:(AVAudioRecorder *)recorder successfully:(BOOL)flag {
    if (flag) {
        
    }
}

@end
