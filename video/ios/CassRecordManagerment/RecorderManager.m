//
//  RecorderManager.m
//  recordDemo
//
//  Created by 谢志敏 on 2018/2/7.
//  Copyright © 2018年 谢志敏. All rights reserved.
//

#import "RecorderManager.h"
#import <React/RCTUtils.h>
#import <React/RCTBridge.h>
#import <React/RCTEventDispatcher.h>
#import "CassAudioRecorder.h"

@interface RecorderManager() {
    CassAudioRecorder *cassAudioRecorder;
}

@end

@implementation RecorderManager

RCT_EXPORT_MODULE(VoiceClient)

@synthesize bridge = _bridge;

- (dispatch_queue_t)methodQueue {
    return dispatch_get_main_queue();
}

//初始化的懒加载方法 初始化录音以及播放模块初始化完成
- (instancetype)init {
    if (self = [super init]) {
        //设置消息监听代理
        cassAudioRecorder = [CassAudioRecorder shareCassAudioRecorder];
    }
    return self;
}

// [self sendEventWithName:@"recording" body:[notifiction userInfo]];

#pragma mark - React-Native 调起录音模块
/*
 * 开始录音，并且实时返回音量大小
 */
RCT_EXPORT_METHOD(record:(int)maxDuration
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject) {
    [cassAudioRecorder startAudioRecorderWithMaxDuration:maxDuration VolumeChangeBlock:^(int volume, NSTimeInterval currentTime) {
        [self sendEventWithName:@"recording" body:[NSNumber numberWithInt:volume]];
    } :^(BOOL complete, NSString *base64, double duration) {
        resolve(@{@"encode_data" : base64, @"duration":[NSNumber numberWithDouble:duration]});
    }];
}

#pragma mark - React-Native 录音模块停止
/*
 * 停止录音,返回录音结果base64位结果
 */
RCT_EXPORT_METHOD(stopRecord
                  :(RCTPromiseResolveBlock)resolve
                  :(RCTPromiseRejectBlock)reject) {
    [cassAudioRecorder stopAudioRecorderWithStopAudioRecorder];
}

#pragma mark - React-Native 播放录音
/*
 * 播放录音
 */
RCT_EXPORT_METHOD(play:(NSString *)base64 :(NSString *)type
                  :(RCTPromiseResolveBlock)resolve
                  :(RCTPromiseRejectBlock)reject) {
    [cassAudioRecorder playAudioRecordWithBase64:base64 isComplete:^(BOOL isFinishOrStop) {
        resolve(@"isFinish");
    }];
}

#pragma mark - React-Native 停止播放录音
/*
 * 停止播放录音,返回录音结果base64位结果
 */
RCT_EXPORT_METHOD(stopPlay
                  :(RCTPromiseResolveBlock)resolve
                  :(RCTPromiseRejectBlock)reject) {
    [cassAudioRecorder stopPlay];
}

#pragma mark - OC回调Javascri
- (NSArray<NSString *> *)supportedEvents {
    return @[@"recording"];
}

@end
