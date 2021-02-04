//
//  VideoViewController.m
//  WebRTCDemo
//
//  Created by tang bo on 2021/1/13.
//

#import "VideoViewController.h"
#import <WebRTC/WebRTC.h>
#import "WebRTCHelper.h"
#import "SocketRocketUtility.h"

@interface VideoViewController ()<WebRTCHelperDelegate>
//{
//    RTCPeerConnectionFactory *_factory;
//    RTCMediaStream *_localStream;
//
//    //判断是显示前摄像头还是显示后摄像头（yes为前摄像头。false为后摄像头）
//    BOOL _usingFrontCamera;
//    //是否显示我的视频流（默认为yes，显示；no为不显示）
//    BOOL _usingCamera;
//
//    NSString *_myId;
//
//}
@property(nonatomic,strong)RTCCameraPreviewView *localVideoView;

/*注释*/
@property (nonatomic,strong)RTCEAGLVideoView *videoView;
@property (nonatomic, strong)   RTCVideoTrack  *remoteVideoTrack;


@end

@implementation VideoViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor whiteColor];
    
    [[WebRTCHelper shareInstance] connectServer:@"http://47.242.132.74:8080/ws" port:@"3000" room:@"100"];
    [WebRTCHelper shareInstance].delegate = self;
//    _usingFrontCamera = YES;
    self.localVideoView = [[RTCCameraPreviewView alloc] initWithFrame:CGRectMake(0, 0, 100, 200)];
    [self.view addSubview:self.localVideoView];
    
    self.videoView = [[RTCEAGLVideoView alloc] initWithFrame:CGRectMake(0, 300, 100, 200)];
    [self.view addSubview:self.videoView];

//    [self showLocaolCamera];
    
    //[self initSocket];
}

- (void)webRTCHelper:(WebRTCHelper *)webRTCHelper capturerSession:(AVCaptureSession *)captureSession{
    
    self.localVideoView.captureSession = captureSession;
}

-(void)webRTCHelper:(WebRTCHelper *)webRTCHelper addRemoteStream:(RTCMediaStream *)stream userId:(NSString *)userId
{
    self.remoteVideoTrack = stream.videoTracks[0];//[stream.videoTracks lastObject];
    [self.remoteVideoTrack addRenderer:self.videoView];

}


-(void)initSocket
{
    [[SocketRocketUtility instance] SRWebSocketOpenWithURLString:@"http://47.242.132.74:8080/ws"];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(SRWebSocketDidOpen) name:kWebSocketDidOpenNote object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(SRWebSocketDidReceiveMsg:) name:kWebSocketdidReceiveMessageNote object:nil];

}
- (void)SRWebSocketDidOpen {
    NSLog(@"开启成功");
    //在成功后需要做的操作。。。
    
    NSDictionary * dic = [[NSDictionary alloc] initWithObjectsAndKeys:@"Online",@"mAction",@"123",@"uid", nil];
    NSString * jsonStr = [self convertToJsonData:dic];
    //发送加入房间的数据
    [[SocketRocketUtility instance] sendData:jsonStr];

}
-(void)SRWebSocketDidReceiveMsg:(NSNotification *)note
{
    //收到服务端发送过来的消息
    NSString * message = note.object;
    NSLog(@"%@",message);
    NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:[message dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingMutableContainers error:nil];
    

}
-(NSString *)convertToJsonData:(NSDictionary *)dict
{
    NSError *error;
    
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:&error];
    
    NSString *jsonString;
    
    if (!jsonData) {
        
        NSLog(@"%@",error);
        
    }else{
        jsonString = [[NSString alloc]initWithData:jsonData encoding:NSUTF8StringEncoding];
    }
    
    NSMutableString *mutStr = [NSMutableString stringWithString:jsonString];
    
    NSRange range = {0,jsonString.length};
    
    //去掉字符串中的空格
    
    [mutStr replaceOccurrencesOfString:@" " withString:@"" options:NSLiteralSearch range:range];
    
    NSRange range2 = {0,mutStr.length};
    
    //去掉字符串中的换行符
    
    [mutStr replaceOccurrencesOfString:@"\n" withString:@"" options:NSLiteralSearch range:range2];
    
    return mutStr;
    
}







//- (void)showLocaolCamera{
//    _usingCamera = !_usingCamera;
//    //如果为空，则创建点对点工厂
//    if (!_factory)
//    {
//        //设置SSL传输
//        [RTCPeerConnectionFactory initialize];
//        _factory = [[RTCPeerConnectionFactory alloc] init];
//    }
//    //如果本地视频流为空
//    if (!_localStream)
//    {
//        //创建本地流
//        [self createLocalStream];
//    }
//    //创建连接
////    [self createPeerConnections];
////
////    //添加
////    [self addStreams];
////    [self createOffers];
//}
///**
// * 创建本地视频流
// */
//-(void)createLocalStream{
//
//    _localStream = [_factory mediaStreamWithStreamId:@"ARDAMS"];
//    //音频
//    RTCAudioTrack * audioTrack = [_factory audioTrackWithTrackId:@"ARDAMSa0"];
//    [_localStream addAudioTrack:audioTrack];
//    NSArray<AVCaptureDevice *> *captureDevices = [RTCCameraVideoCapturer captureDevices];
//    AVCaptureDevicePosition position = _usingFrontCamera ? AVCaptureDevicePositionFront : AVCaptureDevicePositionBack;
//    AVCaptureDevice * device = captureDevices[0];
//    for (AVCaptureDevice *obj in captureDevices) {
//        if (obj.position == position) {
//            device = obj;
//            break;
//        }
//    }
//
//    //检测摄像头权限
//    AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
//    if(authStatus == AVAuthorizationStatusRestricted || authStatus == AVAuthorizationStatusDenied)
//    {
//        NSLog(@"相机访问受限");
////        if ([_delegate respondsToSelector:@selector(webRTCHelper:setLocalStream:userId:)])
////        {
////
////            [_delegate webRTCHelper:self setLocalStream:nil userId:_myId];
////        }
//    }
//    else
//    {
//        if (device)
//        {
//            RTCVideoSource *videoSource = [_factory videoSource];
//            RTCCameraVideoCapturer * capture = [[RTCCameraVideoCapturer alloc] initWithDelegate:videoSource];
//            AVCaptureDeviceFormat * format = [[RTCCameraVideoCapturer supportedFormatsForDevice:device] lastObject];
//            CGFloat fps = [[format videoSupportedFrameRateRanges] firstObject].maxFrameRate;
//            RTCVideoTrack *videoTrack = [_factory videoTrackWithSource:videoSource trackId:@"ARDAMSv0"];
//            __weak RTCCameraVideoCapturer *weakCapture = capture;
//            __weak RTCMediaStream * weakStream = _localStream;
//            __weak NSString * weakMyId = _myId;
//            [weakCapture startCaptureWithDevice:device format:format fps:fps completionHandler:^(NSError * error) {
//                NSLog(@"11111111");
//                [weakStream addVideoTrack:videoTrack];
//
//                self.localVideoView.captureSession = weakCapture.captureSession;
//
////                if ([self->_delegate respondsToSelector:@selector(webRTCHelper:setLocalStream:userId:)])
////                {
////                    [self->_delegate webRTCHelper:self setLocalStream:weakStream userId:weakMyId];
////                    [self->_delegate webRTCHelper:self capturerSession:weakCapture.captureSession];
////                }
//            }];
////            [videoSource adaptOutputFormatToWidth:640 height:480 fps:30];
//
//        }
//        else
//        {
//            NSLog(@"该设备不能打开摄像头");
////            if ([_delegate respondsToSelector:@selector(webRTCHelper:setLocalStream:userId:)])
////            {
////                [_delegate webRTCHelper:self setLocalStream:nil userId:_myId];
////            }
//        }
//    }
//}

@end
