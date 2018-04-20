//
//  CassRecordManager.h
//  CassRecordManager
//
//  Created by 谢志敏 on 2018/2/7.
//  Copyright © 2018年 谢志敏. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreAudio/CoreAudioTypes.h>
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>
#import "VoiceConvert.h"

/* *录制音频的wav路径，和自动转码amr的路径，以及获取到语音文件保存的路径
 *
 * 存储位置放置在了缓存目录下，当缓存不够用时，系统会自动删除部分内存，解决内存中录音数据可能会越来越多的问题
 **/
#define AMR_PATH [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/vido1.amr"]
#define WAV_PATH [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/vido2.wav"]
#define PLAY_PATH [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/play.amr"]

// 音频最短录制时间
#define MIN_TIME 1.0

/**
 *  录音时，监听话筒音量的block
 *
 *  @param volume        返回当前检测话筒声音的音量
 */
typedef void(^VolumeChangedBlock)(int volume);

/**
 *  完成停止录音后回调的block
 *
 *  @param complete    录音是否成功，失败条件为录音时间小于 MIN_TIME
 *  @param base64String 成功后返回录音文件
 *  @param cTime 成功后返回录音文件时长
 *  @param filePath 成功后返回录音文件amr文件路径
 */
typedef void(^StopAudioRecorder)(BOOL complete,
                                 NSString *base64String,
                                 float cTime,
                                 NSString *filePath);

/**
 *  播放音频是否成功
 *
 *  @param finished       播放当前音频是否播放完成
 */
typedef void(^PlayAudioRecordFinished)(BOOL finished);


@interface CassRecordManager: NSObject<AVAudioRecorderDelegate, AVAudioPlayerDelegate> {
    
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
- (void)startAudioRecorderVolumeChangeBlock:(VolumeChangedBlock)volumeChangedBlock StopAudioRecorder:(StopAudioRecorder)stopAudioRecorder MaxDuration: (int)maxDuration;

/**
 *  停止录音
 *
 */
- (void)stopRecord;

/**
 *  开始播放融云穿过来的音频
 *
 *  @param base64String 融云端的base64位字符串
 */
- (void)playerAudioRecorderWithPlayerUrl:(NSString *)base64String isFinished:(PlayAudioRecordFinished)playAudioFinished;

/**
 *  停止播放音频
 *
 */
- (void)stopPlayerAudioRecorder;
@end
