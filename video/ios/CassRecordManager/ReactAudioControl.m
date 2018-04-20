//
//  ReactAudioControl.m
//  CassRecordManager
//
//  Created by 谢志敏 on 2018/2/7.
//  Copyright © 2018年 谢志敏. All rights reserved.
//

#import "ReactAudioControl.h"
#import <React/RCTBridge.h>
#import <React/RCTEventDispatcher.h>
#import "CassRecordManager.h"

@implementation ReactAudioControl {
    CassRecordManager *_cassRecordManager;
}

@synthesize bridge = _bridge;

RCT_EXPORT_MODULE(VoiceClient)

- (dispatch_queue_t)methodQueue {
    return dispatch_get_main_queue();
}

// 初始化方法 将变量初始化
- (instancetype)init {
    if (self = [super init]) {
        _cassRecordManager = [CassRecordManager shareCassAudioRecorder];
    }
    return self;
}

// 发起录音
RCT_EXPORT_METHOD(record:(int)MAX_DURATION
                  :(RCTPromiseResolveBlock)resolve
                  :(RCTPromiseRejectBlock)reject) {
    [_cassRecordManager startAudioRecorderVolumeChangeBlock:^(int volume) {
        // 实时发送音量大小
        [self sendEventWithName:@"recording" body:@{@"recording":[NSNumber numberWithInt:volume]}];
    } StopAudioRecorder:^(BOOL complete, NSString *base64String, float cTime, NSString *filePath) {
        if (complete) {
            resolve(@{@"encode_data" : base64String, @"duration" : [NSNumber numberWithFloat:cTime], @"file_path" : filePath});
        } else {
            reject(@"录音错误", nil, nil);
        }
    } MaxDuration:(int)MAX_DURATION];
}

// 停止录音
RCT_EXPORT_METHOD(stopRecord
                  :(RCTPromiseResolveBlock)resolve
                  :(RCTPromiseRejectBlock)reject) {
    [_cassRecordManager stopRecord];
}

// 开始播放
RCT_EXPORT_METHOD(play:(NSString *)base64String
                      :(NSString *)type
                      :(RCTPromiseResolveBlock)resolve
                      :(RCTPromiseRejectBlock)reject) {
    [_cassRecordManager playerAudioRecorderWithPlayerUrl:base64String isFinished:^(BOOL finished) {
        resolve([NSNumber numberWithBool:finished]);
    }];
}

// 停止播放
RCT_EXPORT_METHOD(stopPlay) {
    [_cassRecordManager stopPlayerAudioRecorder];
}

#pragma mark - 注册发射的方法
- (NSArray<NSString *> *)supportedEvents {
    return @[@"recording", @"RECORD_STOP"];
}

@end
