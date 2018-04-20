//
//  CassRecordManager.m
//  CassRecordManager
//
//  Created by 谢志敏 on 2018/2/7.
//  Copyright © 2018年 谢志敏. All rights reserved.
//

#import "CassRecordManager.h"

static CassRecordManager  *single = nil;

@implementation CassRecordManager {
    NSFileManager *_fileManager;
    
    NSString *_savePath;
    
    AVAudioRecorder *_recorder;
    
    AVAudioPlayer *_avPlayer;
    
    StopAudioRecorder _stopAudioRecorder;
    
    PlayAudioRecordFinished _playAudioRecordFinished;
}

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
        _fileManager = [NSFileManager defaultManager];
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
    _recorder = [[AVAudioRecorder alloc] initWithURL:wavUrl settings:recordSetting error:&error];
    
    // 开启音量检测
    [_recorder setDelegate:self];
    [_recorder setMeteringEnabled:YES];
    
    // 判断版本是否大于 7.0 大于则需要询问
    if ([[[UIDevice currentDevice] systemVersion] compare:@"7.0"]!=NSOrderedAscending) {
        // iOS 7.0第一次运行会询问是否允许使用麦克风， 我们生成音频会话者
        AVAudioSession *session = [AVAudioSession sharedInstance];
        
        
        NSError *sessionError;
        //AVAudioSessionCategoryPlayAndRecord用于录音和播放
        [session setCategory:AVAudioSessionCategoryPlayAndRecord error:&sessionError];
        
        if(session == nil) {
            // 生成会话失败情况的原因，这里会请求用户同意访问麦克风
            NSLog(@"Error creating session %@", [sessionError description]);
        } else {
            [session setActive:YES error:nil];
        }
    }
}

/**
 *  开始录音
 *
 *  @param volumeChangedBlock 当前话筒音量监听
 */
- (void)startAudioRecorderVolumeChangeBlock:(VolumeChangedBlock)volumeChangedBlock StopAudioRecorder:(StopAudioRecorder)stopAudioRecorder MaxDuration:(int)maxDuration {
    // 录音前需要停止播放
    [self stopPlayerAudioRecorder];
    
    // 如果点击录音时还在录制中，则强制结束这一次录制并返回结果，进入下一次录制
    if ([_recorder isRecording]) {
        [self stopRecord];
    }
    
    if ([_recorder prepareToRecord]) {
        // 开始
        [_recorder record];
    }
    
    // 这里返回平均时间内的音频大小
    if (volumeChangedBlock != nil) {
        _volumeChangedBlock = [volumeChangedBlock copy];
    } else  {
        _volumeChangedBlock = nil;
    }
    
    _stopAudioRecorder = stopAudioRecorder;
    
    [NSTimer scheduledTimerWithTimeInterval:maxDuration/1000 repeats:NO block:^(NSTimer * _Nonnull timer) {
        if ([_recorder currentTime] >=  maxDuration/1000) {
            [self stopRecord];
        }
    }];
    
    // 设置定时器
    _timer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(detectionVoice) userInfo:nil repeats:YES];
}

// 实时返回音量大小
- (void)detectionVoice {
    [_recorder updateMeters];
    // 获取音量平均值
    // 音量的最大值
    int volume = ([_recorder peakPowerForChannel:0] + 50);
    int db = 0;
    volume = MIN(40, volume);
    volume = MAX(0, volume);
    if (volume <= 5) {
        db = 1;
    } else if (volume <= 10) {
        db = 2;
    } else if (volume <= 15) {
        db = 3;
    } else if (volume <= 20) {
        db = 4;
    } else if (volume <= 35) {
        db = 5;
    } else if (volume <= 45){
        db = 6;
    } else {
        db = 7;
    }
    
    _volumeChangedBlock(db);
}


/**
 *  停止录音的方法
 *
 */
- (void)stopRecord {

    double cTime = _recorder.currentTime;
    if (cTime > 1.0) {//如果录制时间<1 不发送
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            // 音频转码
            // wav 格式音频转为 amr 格式音频
            [VoiceConvert ConvertWavToAmr:WAV_PATH amrSavePath:AMR_PATH];
            NSString *base64String = [self getBase64StringWithFilePath:AMR_PATH];
            NSString *filePath = [self saveRecordFileWithBase64String:base64String];
            dispatch_async(dispatch_get_main_queue(), ^{
                // 停止录音
                [_recorder stop];
                // 定时器关闭
                [_timer invalidate];
                // 停止录音需要返回录音的base64 也需要返回录音时长
                _stopAudioRecorder(YES, base64String, cTime*1000, filePath);
                _stopAudioRecorder = nil;
            });
        });
    } else {
        //删除记录的文件
        if (!_stopAudioRecorder) {
            _stopAudioRecorder(YES,@"",0, @"");
            _stopAudioRecorder = nil;
        }
    }
}

/**
 *  删除录制文件
 */
- (void)deleteRecording {
    // 删除录制文件
    [_recorder stop];
    [_timer invalidate];
    [_recorder deleteRecording];
    
    // 删除转码的文件
    [_fileManager removeItemAtPath:AMR_PATH error:nil];
}

/**
 *  保存录制文件
 */
- (NSString *)saveRecordFileWithBase64String:(NSString *)base64String {
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateFormat = @"yyyyMMddHHmmss";
    NSString *timeStr = [dateFormatter stringFromDate:[NSDate date]];
    
    //doc目录
    NSString *doc = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, NO) lastObject];
    
    NSData *dataFromBase64 = [base64String dataUsingEncoding:NSUTF8StringEncoding];
    //拼接音频URL
    NSString *filePath = [doc stringByAppendingPathComponent:timeStr];
    [dataFromBase64 writeToFile:filePath atomically:YES];
    return filePath;
}


/**
 *  播放音频文件
 *
 *  @param urlString 音频文件的地址
 */
- (void)playerAudioRecorderWithPlayerUrl:(NSString *)urlString isFinished:(PlayAudioRecordFinished)playAudioFinished{
    // 播放之前先将上一次播放关闭，并将上一次的回调置空
    if ([_avPlayer isPlaying]) {
        [_avPlayer stop];
        _playAudioRecordFinished(NO);
        _playAudioRecordFinished = nil;
    }
    _playAudioRecordFinished = playAudioFinished;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // 这里是base64的字符串需要处理成NSData
        NSData *amrData = [[NSData alloc] initWithBase64EncodedString:urlString options:NSDataBase64DecodingIgnoreUnknownCharacters];
        [amrData writeToFile:PLAY_PATH atomically:YES];
        // 音频转码
        [VoiceConvert ConvertAmrToWav:PLAY_PATH wavSavePath:WAV_PATH];
        [_fileManager removeItemAtPath:PLAY_PATH error:nil];
        dispatch_async(dispatch_get_main_queue(), ^{
            _avPlayer = [[AVAudioPlayer alloc]initWithContentsOfURL:[NSURL fileURLWithPath:WAV_PATH] error:nil];
            [_avPlayer setDelegate:self];
            _avPlayer.volume=1.0;
            [_avPlayer play];
        });
    });
}

/**
 *  停止播放音频文件
 *
 */
- (void)stopPlayerAudioRecorder {
    [_avPlayer stop];
    if (_playAudioRecordFinished != nil) {
        _playAudioRecordFinished(NO);
        _playAudioRecordFinished = nil;
    }
    
    [_fileManager removeItemAtPath:WAV_PATH error:nil];
}


/**
 *  将AMR文件格式转换成base64格式文件
 *
 * @params filePath 文件保存路径
 */
- (NSString *)getBase64StringWithFilePath:(NSString *)filePath {
    NSData *uploadData = [NSData dataWithContentsOfFile:filePath];
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

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
    _playAudioRecordFinished(flag);
    _playAudioRecordFinished = nil;
}


@end
