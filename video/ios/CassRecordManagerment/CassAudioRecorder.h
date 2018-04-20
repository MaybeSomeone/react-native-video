//
//  CassAudioRecorder.h
//  recordDemo
//
//  Created by 谢志敏 on 2018/2/7.
//  Copyright © 2018年 谢志敏. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreAudio/CoreAudioTypes.h>
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>
#import "VoiceConvert.h"

// 录制音频的wav路径，和自动转码amr的路径
#define AMR_PATH [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/vido1.amr"]
#define WAV_PATH [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/vido2.wav"]
#define BASE64_PATH [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/vido3.wav"]

// 音频最短录制时间
#define MIN_TIME 1.0

/**
 *  录音时，监听话筒音量的block
 *
 *  @param volume        返回当前检测话筒声音的音量
 *  @param currentTime   录制时间（秒）
 */
typedef void(^VolumeChangedBlock)(int volume, NSTimeInterval currentTime);

/**
 *  完成停止录音后回调的block
 *
 *  @param complete    录音是否成功，失败条件为录音时间小于 MIN_TIME
 *  @param base64      录音文件的base64格式
 *  @param duration    录音的时长
 */
typedef void(^StopAudioRecorder)(BOOL complete, NSString *base64, double duration);

/**
 *  播放录音完成或者被强制停止
 *  @param isFinishOrStop 录音播放或者强制停止
 */
typedef void(^AudioPlayerIsFinishOrStop)(BOOL isFinishOrStop);

@interface CassAudioRecorder : NSObject<AVAudioRecorderDelegate, AVAudioPlayerDelegate> {
    AVAudioRecorder *recorder;
    
    AVAudioPlayer *_avPlayer;
    
    VolumeChangedBlock _volumeChangedBlock;
    
    NSTimer *_timer;
}

/**
 *  单例设计模式（创建和使用对象都用此方法）
 *
 *  @return 返回当前音频录制对象
 */
+ (instancetype)shareCassAudioRecorder;

/**
 *  开始录音
 *
 *  @param volumeChangedBlock 当前话筒音量监听
 */
- (void)startAudioRecorderWithMaxDuration:(double)duration VolumeChangeBlock:(VolumeChangedBlock)volumeChangedBlock :(StopAudioRecorder)stopAudioRecorder;

- (void)stopAudioRecorderWithStopAudioRecorder;

- (void)playAudioRecordWithBase64:(NSString *)base64 isComplete:(AudioPlayerIsFinishOrStop)audioPlayerIsFinishOrStop;

- (void)stopPlay;

@end
