//
//  WebRTCManger.h
//  WebRTCDemo
//
//  Created by tang bo on 2021/1/14.
//

#import <Foundation/Foundation.h>
#import <WebRTC/WebRTC.h>
#import "SocketRocketUtility.h"

#define EVENT_VIDEO_CALL_REQUEST  @"1"
#define EVENT_VIDEO_CALL_AGREE = @"2"
#define EVENT_VIDEO_CALL_DENIED = @"3"
#define EVENT_RTC_OFFER = @"4"
#define EVENT_RTC_ANSWER = @"5"
#define EVENT_RTC_ICE = @"6"
#define EVENT_RTC_AONLINE = @"7"
#define EVENT_RTC_READY = @"8"
#define EVENT_RTC_END = @"9"

NS_ASSUME_NONNULL_BEGIN

@interface WebRTCManger : NSObject

@end

NS_ASSUME_NONNULL_END
