//
//  WebRTCHelper.m
//  WebRTC_new
//
//  Created by 胡志辉 on 2018/9/4.
//  Copyright © 2018年 Mr.hu. All rights reserved.
//

#import "WebRTCHelper.h"

#define kAPPID  @"1234567890abcdefg"
#define kDeviceUUID [[[UIDevice currentDevice] identifierForVendor] UUIDString]

//google提供的
static NSString *const RTCSTUNServerURL = @"stun:javacoder.tech:3478";
static NSString *const RTCSTUNServerURL2 = @"stun:javacoder.tech:3478";
//static NSString *const RTCSTUNServerURL = @"115.236.101.203:18080";
//static NSString *const RTCSTUNServerURL2 = @"115.236.101.203:18080";

@interface WebRTCHelper()<RTCPeerConnectionDelegate,RTCVideoCapturerDelegate,SRWebSocketDelegate>
{
    SRWebSocket *_socket;
    NSString *_server;
    NSString *_room;
    
    RTCPeerConnectionFactory *_factory;
    //RTCMediaStream *_localStream;
    
    
    NSString *_myId;
    NSMutableDictionary *_connectionDic;
    NSMutableArray *_connectionIdArray;
    
//    Role _role;
    NSString * _connectId;
    NSMutableArray *ICEServers;
    //判断是显示前摄像头还是显示后摄像头（yes为前摄像头。false为后摄像头）
    BOOL _usingFrontCamera;
    //是否显示我的视频流（默认为yes，显示；no为不显示）
    BOOL _usingCamera;
    
    
}
@property(nonatomic,strong)RTCPeerConnectionFactory * factory;
@property(nonatomic,strong)RTCPeerConnection *connection;
@property(nonatomic,strong)RTCMediaStream * localStream;

@end

@implementation WebRTCHelper

static WebRTCHelper * instance = nil;

+(instancetype)shareInstance{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[[self class] alloc] init];
        [instance initData];
    });
    return instance;
}

-(void)initData{
    _connectionDic = [NSMutableDictionary dictionary];
    _connectionIdArray = [NSMutableArray array];
    _usingFrontCamera = YES;
    _usingCamera = YES;
}


#pragma mark -提供给外部的方法

/**
 * 与服务器进行连接
 */
- (void)connectServer:(NSString *)server port:(NSString *)port room:(NSString *)room{
//    _server = server;
//    _room = room;
//    _socket = [[SRWebSocket alloc] initWithURLRequest:
//               [NSURLRequest requestWithURL:[NSURL URLWithString:server]]];
//    _socket.delegate = self;
//    [_socket open];
    [self initSocket:server];
    
}
-(void)initSocket:(NSString *)server
{
    [[SocketRocketUtility instance] SRWebSocketOpenWithURLString:server];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(SRWebSocketDidOpen) name:kWebSocketDidOpenNote object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(SRWebSocketDidReceiveMsg:) name:kWebSocketdidReceiveMessageNote object:nil];

}
/**
 *  加入房间
 *
 *  @param room 房间号
 */
- (void)joinRoom:(NSString *)room
{
    //如果socket是打开状态
//    if (_socket.readyState == SR_OPEN)
//    {
//        NSDictionary * dic = [[NSDictionary alloc] initWithObjectsAndKeys:@"Online",@"mAction",@"123",@"uid", nil];
//        NSString * jsonStr = [self convertToJsonData:dic];
//
//        //发送加入房间的数据
//        [_socket send:jsonStr];
//        NSMutableDictionary * dic = [[NSMutableDictionary alloc]init];
    
    NSDictionary * dic1 = [[NSDictionary alloc] initWithObjectsAndKeys:@"Online",@"mAction",@"123",@"uid", nil];
    NSString * jsonStr1 = [self convertToJsonData:dic1];
    [[SocketRocketUtility instance] sendData:jsonStr1];
    
        NSDictionary * dic = [[NSDictionary alloc] initWithObjectsAndKeys:@"messageTrans",@"mAction",EVENT_VIDEO_CALL_REQUEST,@"subAction",@"123",@"from",@"google-sdk_gphone_x86-RSR1.201013.001-T-Mobile",@"to", nil];
//        [dic setObject:@"messageTrans" forKey:@"mAction"];
//        [dic setObject:EVENT_VIDEO_CALL_REQUEST forKey:@"subAction"];
//        [dic setObject:@"123" forKey:@"form"];
//        [dic setObject:@google-sdk_gphone_x86-RSR1.201013.001-T-Mobile" forKey:@"to"];
        NSString * jsonStr = [self convertToJsonData:dic];
        //发送加入房间的数据
        [[SocketRocketUtility instance] sendData:jsonStr];

//    }
}
/**
 *  退出房间
 */
- (void)exitRoom
{
    _localStream = nil;
    [_connectionIdArray enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [self closePeerConnection:obj];
    }];
    [_socket close];
}

/**
 * 切换摄像头
 */
- (void)swichCamera{
    _usingFrontCamera = !_usingFrontCamera;
    [self createLocalStream];
}
/**
 * 是否显示本地摄像头
 */
- (void)showLocaolCamera{
    _usingCamera = !_usingCamera;
    //如果为空，则创建点对点工厂
    if (!self.factory)
    {
        //设置SSL传输
        [RTCPeerConnectionFactory initialize];
        self.factory = [[RTCPeerConnectionFactory alloc] init];
    }
    //如果本地视频流为空
    if (!self.localStream)
    {
        //创建本地流
        [self createLocalStream];
    }
    //创建连接
    [self createPeerConnections];
    
    //添加
    [self addStreams];
    [self createOffers];
}

#pragma mark -内部方法
/**
 *  关闭peerConnection
 *
 *  @param connectionId <#connectionId description#>
 */
- (void)closePeerConnection:(NSString *)connectionId
{
    RTCPeerConnection *peerConnection = [_connectionDic objectForKey:connectionId];
    if (peerConnection)
    {
        [peerConnection close];
    }
//    [_connectionIdArray removeObject:connectionId];
//    [_connectionDic removeObjectForKey:connectionId];
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self->_delegate respondsToSelector:@selector(webRTCHelper:closeWithUserId:)])
        {
            [self->_delegate webRTCHelper:self closeWithUserId:connectionId];
        }
    });
}


/**
 *  创建点对点连接
 *
 *  @param connectionId connectionId description
 *
 *  @return <#return value description#>
 */
- (RTCPeerConnection *)createPeerConnection:(NSString *)connectionId
{
    //如果点对点工厂为空
    if (!self.factory)
    {
        //先初始化工厂
        self.factory = [[RTCPeerConnectionFactory alloc] init];
    }
    
    //得到ICEServer
    if (!ICEServers) {
        ICEServers = [NSMutableArray array];
        [ICEServers addObject:[self defaultSTUNServer]];
    }
    
    //用工厂来创建连接
    RTCConfiguration *configuration = [[RTCConfiguration alloc] init];
    configuration.iceServers = ICEServers;
    RTCPeerConnection *connection = [self.factory peerConnectionWithConfiguration:configuration constraints:[self creatPeerConnectionConstraint] delegate:self];
    
    return connection;
}

- (RTCMediaConstraints *)creatPeerConnectionConstraint
{
    RTCMediaConstraints *constraints = [[RTCMediaConstraints alloc] initWithMandatoryConstraints:@{kRTCMediaConstraintsOfferToReceiveAudio:kRTCMediaConstraintsValueTrue,kRTCMediaConstraintsOfferToReceiveVideo:kRTCMediaConstraintsValueTrue} optionalConstraints:nil];
    return constraints;
}

//初始化STUN Server （ICE Server）
- (RTCIceServer *)defaultSTUNServer{
    return [[RTCIceServer alloc] initWithURLStrings:@[RTCSTUNServerURL,RTCSTUNServerURL2]];
}



/**
 *  为所有连接添加流
 */
- (void)addStreams
{
    //给每一个点对点连接，都加上本地流
    [_connectionDic enumerateKeysAndObjectsUsingBlock:^(NSString *key, RTCPeerConnection *obj, BOOL * _Nonnull stop) {
        if (!self->_localStream)
        {
            [self createLocalStream];
        }
        [obj addStream:self->_localStream];
    }];
}
/**
 *  创建所有连接
 */
- (void)createPeerConnections
{
    //从我们的连接数组里快速遍历
    [_connectionIdArray enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        
        //根据连接ID去初始化 RTCPeerConnection 连接对象
        RTCPeerConnection *connection = [self createPeerConnection:obj];
        
        //设置这个ID对应的 RTCPeerConnection对象
        [self->_connectionDic setObject:connection forKey:obj];
    }];
}


/**
 * 创建本地视频流
 */
-(void)createLocalStream{
    
    self.localStream = [self.factory mediaStreamWithStreamId:@"ARDAMS"];
    //音频
    RTCAudioTrack * audioTrack = [self.factory audioTrackWithTrackId:@"ARDAMSa0"];
    [self.localStream addAudioTrack:audioTrack];
    NSArray<AVCaptureDevice *> *captureDevices = [RTCCameraVideoCapturer captureDevices];
    AVCaptureDevicePosition position = _usingFrontCamera ? AVCaptureDevicePositionFront : AVCaptureDevicePositionBack;
    AVCaptureDevice * device = captureDevices[0];
    for (AVCaptureDevice *obj in captureDevices) {
        if (obj.position == position) {
            device = obj;
            break;
        }
    }
//    [self.localStream addVideoTrack:videoTrack];
//    [self.connection addStream:self.localStream];

    //检测摄像头权限
    AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    if(authStatus == AVAuthorizationStatusRestricted || authStatus == AVAuthorizationStatusDenied)
    {
        NSLog(@"相机访问受限");
        if ([_delegate respondsToSelector:@selector(webRTCHelper:setLocalStream:userId:)])
        {
            
            [_delegate webRTCHelper:self setLocalStream:nil userId:_myId];
        }
    }
    else
    {
        if (device)
        {
            RTCVideoSource *videoSource = [self.factory videoSource];//[self.factory videoSource];
            RTCCameraVideoCapturer * capture = [[RTCCameraVideoCapturer alloc] initWithDelegate:videoSource];
            AVCaptureDeviceFormat * format = [[RTCCameraVideoCapturer supportedFormatsForDevice:device] lastObject];
            CGFloat fps = [[format videoSupportedFrameRateRanges] firstObject].maxFrameRate;
            RTCVideoTrack *videoTrack = [self.factory videoTrackWithSource:videoSource trackId:@"ARDAMSv0"];
            videoTrack.isEnabled = YES;
            NSLog(@"%d",videoTrack.readyState);
            __weak RTCCameraVideoCapturer *weakCapture = capture;
            __weak RTCMediaStream * weakStream = _localStream;
            __weak NSString * weakMyId = _myId;
            

            [capture startCaptureWithDevice:device format:format fps:fps completionHandler:^(NSError * error) {
                
                [self.localStream addVideoTrack:videoTrack];
                [self.connection addStream:self.localStream];

//                [self.localStream addVideoTrack:videoTrack];
//                [self.connection addStream:self.localStream];

//                [self->_localStream addVideoTrack:videoTrack];
//                [self.connection addStream:self->_localStream];

                if ([self->_delegate respondsToSelector:@selector(webRTCHelper:capturerSession:)])
                {
                    [self->_delegate webRTCHelper:self capturerSession:weakCapture.captureSession];
                }
            }];
//            [videoSource adaptOutputFormatToWidth:640 height:480 fps:30];
            
        }
        else
        {
            NSLog(@"该设备不能打开摄像头");
            if ([_delegate respondsToSelector:@selector(webRTCHelper:setLocalStream:userId:)])
            {
                [_delegate webRTCHelper:self setLocalStream:nil userId:_myId];
            }
        }
    }
}

/**
 *  视频的相关约束
 */
//- (RTCMediaConstraints *)localVideoConstraints
//{
//    NSDictionary *mandatory = @{kRTCMediaConstraintsMaxWidth:@640,kRTCMediaConstraintsMinWidth:@640,kRTCMediaConstraintsMaxHeight:@480,kRTCMediaConstraintsMinHeight:@480,kRTCMediaConstraintsMinFrameRate:@15};
//    RTCMediaConstraints *constraints = [[RTCMediaConstraints alloc] initWithMandatoryConstraints:mandatory optionalConstraints:nil];
//    return constraints;
//}

/**
 * 创建offer
 */
-(void)createOffer:(RTCPeerConnection *)peerConnection{
    if (peerConnection == nil) {
        peerConnection = [self createPeerConnection:nil];
    }
    [peerConnection offerForConstraints:[self offerOranswerConstraint] completionHandler:^(RTCSessionDescription * _Nullable sdp, NSError * _Nullable error) {
        if (error == nil) {
             __weak RTCPeerConnection * weakPeerConnction = peerConnection;
            [peerConnection setLocalDescription:sdp completionHandler:^(NSError * _Nullable error) {
                
                if (error == nil) {
                    [self setSessionDescriptionWithPeerConnection:weakPeerConnction];
                }
                else
                {
                    
                }
            }];
        }
    }];

}
/**
 *  为所有连接创建offer
 */
- (void)createOffers
{
    //给每一个点对点连接，都去创建offer
    [_connectionDic enumerateKeysAndObjectsUsingBlock:^(NSString *key, RTCPeerConnection *obj, BOOL * _Nonnull stop) {
        [self createOffer:obj];
    }];
}

/**
 *  设置offer/answer的约束
 */
- (RTCMediaConstraints *)offerOranswerConstraint
{
    NSMutableDictionary * dic = [@{kRTCMediaConstraintsOfferToReceiveAudio:kRTCMediaConstraintsValueTrue,kRTCMediaConstraintsOfferToReceiveVideo:kRTCMediaConstraintsValueTrue} mutableCopy];
    [dic setObject:(_usingCamera ? kRTCMediaConstraintsValueTrue : kRTCMediaConstraintsValueFalse) forKey:kRTCMediaConstraintsOfferToReceiveVideo];
    RTCMediaConstraints *constraints = [[RTCMediaConstraints alloc] initWithMandatoryConstraints:dic optionalConstraints:nil];
    return constraints;
}

// Called when setting a local or remote description.
//当一个远程或者本地的SDP被设置就会调用
- (void)setSessionDescriptionWithPeerConnection:(RTCPeerConnection *)peerConnection
{
    NSLog(@"%s",__func__);
    NSString *currentId = [self getKeyFromConnectionDic:peerConnection];
    
    //判断，当前连接状态为，收到了远程点发来的offer，这个是进入房间的时候，尚且没人，来人就调到这里
    if (peerConnection.signalingState == RTCSignalingStateHaveRemoteOffer)
    {
        //创建一个answer,会把自己的SDP信息返回出去
        [peerConnection answerForConstraints:[self offerOranswerConstraint] completionHandler:^(RTCSessionDescription * _Nullable sdp, NSError * _Nullable error) {
            __weak RTCPeerConnection *obj = peerConnection;
            [peerConnection setLocalDescription:sdp completionHandler:^(NSError * _Nullable error) {
                [self setSessionDescriptionWithPeerConnection:obj];
            }];
        }];
    }
    //判断连接状态为本地发送offer
    else if (peerConnection.signalingState == RTCSignalingStateHaveLocalOffer)
    {
        if (peerConnection.localDescription.type == RTCSdpTypeAnswer)
        {
            NSDictionary *dic = @{@"eventName": @"__answer", @"data": @{@"sdp": @{@"type": @"answer", @"sdp": peerConnection.localDescription.sdp}, @"socketId": currentId}};
            NSData *data = [NSJSONSerialization dataWithJSONObject:dic options:NSJSONWritingPrettyPrinted error:nil];
            [_socket send:data];
        }
        //发送者,发送自己的offer
        else if(peerConnection.localDescription.type == RTCSdpTypeOffer)
        {
            /*
             requestBody.put("description", localDescription.description);
             requestBody.put("type", localDescription.type);
             request.put("mAction", "messageTrans");
             request.put("subAction", subAction);
             request.put("from", myId);
             request.put("to", target);
             **/
            NSMutableDictionary * dic = [[NSMutableDictionary alloc] init];
            RTCSessionDescription * description = peerConnection.localDescription;
            [dic setObject:description.sdp forKey:@"description"];
            [dic setObject:[NSString stringWithFormat:@"%@",@"Offer"] forKey:@"type"];
            [dic setObject:EVENT_RTC_OFFER forKey:@"subAction"];
            [dic setObject:@"123" forKey:@"from"];
            [dic setObject:@"google-sdk_gphone_x86-RSR1.201013.001-T-Mobile" forKey:@"to"];
            [dic setObject:@"messageTrans" forKey:@"mAction"];
            
            NSString * jsonStr = [self convertToJsonData:dic];
            [[SocketRocketUtility instance] sendData:jsonStr];
        }
    }
    else if (peerConnection.signalingState == RTCSignalingStateStable)
    {
        if (peerConnection.localDescription.type == RTCSdpTypeAnswer)
        {
            NSDictionary *dic = @{@"eventName": @"__answer", @"data": @{@"sdp": @{@"type": @"answer", @"sdp": peerConnection.localDescription.sdp}, @"socketId": currentId}};
            NSData *data = [NSJSONSerialization dataWithJSONObject:dic options:NSJSONWritingPrettyPrinted error:nil];
            [_socket send:data];
        }
    }
    
}


#pragma mark RTCPeerConnectionDelegate
/**获取远程视频流*/
- (void)peerConnection:(nonnull RTCPeerConnection *)peerConnection didAddStream:(nonnull RTCMediaStream *)stream {
    NSString * userId = [self getKeyFromConnectionDic:peerConnection];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self->_delegate respondsToSelector:@selector(webRTCHelper:addRemoteStream:userId:)]) {
            [self->_delegate webRTCHelper:self addRemoteStream:stream userId:userId];
        }
    });
}
/**RTCIceConnectionState 状态变化*/
- (void)peerConnection:(nonnull RTCPeerConnection *)peerConnection didChangeIceConnectionState:(RTCIceConnectionState)newState {
    NSLog(@"%s",__func__);
    NSString * connectId = [self getKeyFromConnectionDic:peerConnection];
    if (newState == RTCIceConnectionStateDisconnected) {
        //断开connection的连接
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([self->_delegate respondsToSelector:@selector(webRTCHelper:closeWithUserId:)]) {
                [self->_delegate webRTCHelper:self closeWithUserId:connectId];
            }
            [self closePeerConnection:connectId];
        });
    }
}
/**获取到新的candidate 获取导更新的ice信息传递给服务器端*/
- (void)peerConnection:(RTCPeerConnection *)peerConnection didGenerateIceCandidate:(RTCIceCandidate *)candidate{
    NSLog(@"%s",__func__);
    //@google-sdk_gphone_x86-RSR1.201013.001-T-Mobile"
    
    NSMutableDictionary * dic = [[NSMutableDictionary alloc] init];
    [dic setObject:@"123" forKey:@"from"];
    [dic setObject:@"google-sdk_gphone_x86-RSR1.201013.001-T-Mobile" forKey:@"to"];
    [dic setObject:@"messageTrans" forKey:@"mAction"];
    [dic setObject:EVENT_RTC_ICE forKey:@"subAction"];
    [dic setObject:[NSString stringWithFormat:@"%d",candidate.sdpMLineIndex] forKey:@"label"];
    [dic setObject:candidate.sdpMid forKey:@"id"];
    [dic setObject:candidate.sdp forKey:@"candidate"];
    NSString * jsonStr = [self convertToJsonData:dic];
    [[SocketRocketUtility instance] sendData:jsonStr];
}

/**删除某个视频流*/
- (void)peerConnection:(nonnull RTCPeerConnection *)peerConnection didRemoveStream:(nonnull RTCMediaStream *)stream {
    NSLog(@"%s",__func__);
}

- (void)peerConnectionShouldNegotiate:(RTCPeerConnection *)peerConnection{
    NSLog(@"%s,line = %d object = %@",__FUNCTION__,__LINE__,peerConnection);
}

- (void)peerConnection:(nonnull RTCPeerConnection *)peerConnection didRemoveIceCandidates:(nonnull NSArray<RTCIceCandidate *> *)candidates {
    NSLog(@"%s,line = %d object = %@",__FUNCTION__,__LINE__,candidates);
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection didChangeSignalingState:(RTCSignalingState)stateChanged{
    NSLog(@"stateChanged = %ld",(long)stateChanged);
    
    
}
- (void)peerConnection:(RTCPeerConnection *)peerConnection didChangeIceGatheringState:(RTCIceGatheringState)newState{
    NSLog(@"newState = %ld",newState);
}


#pragma mark -消息相关
-(void)peerConnection:(RTCPeerConnection *)peerConnection didOpenDataChannel:(RTCDataChannel *)dataChannel{
    
}

#pragma mark -视频分辨率代理
- (void)capturer:(nonnull RTCVideoCapturer *)capturer didCaptureVideoFrame:(nonnull RTCVideoFrame *)frame {
    
}

- (void)SRWebSocketDidOpen {
    NSLog(@"开启成功");
    [self joinRoom:_room];

    
}
-(void)SRWebSocketDidReceiveMsg:(NSNotification *)note
{
    //收到服务端发送过来的消息
    NSString * message = note.object;
    
    NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:[message dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingMutableContainers error:nil];
    NSString *eventName = dic[@"subAction"];
    
    if([EVENT_RTC_READY isEqualToString:eventName])
    {
        //拿到给自己分配的ID
        _myId = @"123";//dataDic[@"you"];
   
        //如果为空，则创建点对点工厂
        if (!self.factory)
        {
            //设置SSL传输
            [RTCPeerConnectionFactory initialize];
            self.factory =  [[RTCPeerConnectionFactory alloc] init];

            
//            RTCVideoCodecInfo *codecInfo = [[RTCVideoCodecInfo alloc]initWithName:@"VP8"];
//            RTCDefaultVideoEncoderFactory *encodeFac = [[RTCDefaultVideoEncoderFactory alloc]init];
//            RTCDefaultVideoDecoderFactory *decodeFac = [[RTCDefaultVideoDecoderFactory  alloc]init];
//            NSArray *arrCodecs  = [encodeFac supportedCodecs];
//            RTCVideoCodecInfo *info = arrCodecs[2];
//            [encodeFac setPreferredCodec:info];
//            NSLog(@"factory---:%@",arrCodecs);
//            self.factory = [[RTCPeerConnectionFactory alloc]initWithEncoderFactory:encodeFac decoderFactory:decodeFac];
        }
        //创建连接
        self.connection =  [self createPeerConnection:@""];//对方ID

        //如果本地视频流为空
        if (!_localStream)
        {
            //创建本地流
            [self createLocalStream];
        }
        //添加
        //[self addStreams];
        //添加offer
        [self createOffer:self.connection];
        
    }
    else if ([EVENT_RTC_ANSWER isEqualToString:eventName])
    {
        __weak typeof(self)wself = self;
        NSString * description = [dic objectForKey:@"description"];
        RTCSessionDescription *remoteSdp = [[RTCSessionDescription alloc] initWithType:RTCSdpTypeAnswer sdp:description];
        __weak RTCPeerConnection * weakPeerConnection = self.connection;
        [self.connection setRemoteDescription:remoteSdp completionHandler:^(NSError * _Nullable error) {
            [wself setSessionDescriptionWithPeerConnection:weakPeerConnection];
        }];

    }
    else if ([@"" isEqualToString:eventName])
    {
        //拿到给自己分配的ID
        _myId = @"123";//dataDic[@"you"];
   
        //如果为空，则创建点对点工厂
        if (!_factory)
        {
            //设置SSL传输
            [RTCPeerConnectionFactory initialize];
            _factory = [[RTCPeerConnectionFactory alloc] init];
        }
        //如果本地视频流为空
        if (!_localStream)
        {
            //创建本地流
            [self createLocalStream];
        }
        //创建连接
        RTCPeerConnection *connection =  [self createPeerConnection:@""];//对方ID
        //添加
        [self addStreams];
        //添加offer
        [self createOffer:connection];
        
        
    }
    //1.发送加入房间后的反馈
    else if ([eventName isEqualToString:@"_peers"])
    {
        //得到data
        NSDictionary *dataDic = dic[@"data"];
        //得到所有的连接
        NSArray *connections = dataDic[@"connections"];
        //加到连接数组中去
        [_connectionIdArray addObjectsFromArray:connections];
        
        //拿到给自己分配的ID
        _myId = @"123";//dataDic[@"you"];
   
        //如果为空，则创建点对点工厂
        if (!_factory)
        {
            //设置SSL传输
            [RTCPeerConnectionFactory initialize];
            _factory = [[RTCPeerConnectionFactory alloc] init];
        }
        //如果本地视频流为空
        if (!_localStream)
        {
            //创建本地流
            [self createLocalStream];
        }
        //创建连接
        [self createPeerConnections];
        
        //添加
        [self addStreams];
        [self createOffers];
        
         
        //获取房间内所有用户的代理回调
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([self->_friendDelegate respondsToSelector:@selector(webRTCHelper:gotFriendList:)]) {
                [self->_friendDelegate webRTCHelper:self gotFriendList:connections];
            }
        });
        
    }
    //4.接收到新加入的人发了ICE候选，（即经过ICEServer而获取到的地址）
    else if ([eventName isEqualToString:@"_ice_candidate"])
    {
        NSDictionary *dataDic = dic[@"data"];
        NSString *socketId = dataDic[@"socketId"];
        NSString *sdpMid = dataDic[@"id"];
        int sdpMLineIndex = [dataDic[@"label"] intValue];
        NSString *sdp = dataDic[@"candidate"];
        //生成远端网络地址对象
        RTCIceCandidate *candidate = [[RTCIceCandidate alloc] initWithSdp:sdp sdpMLineIndex:sdpMLineIndex sdpMid:sdpMid];;
        //拿到当前对应的点对点连接
        RTCPeerConnection *peerConnection = [_connectionDic objectForKey:socketId];
        //添加到点对点连接中
        [peerConnection addIceCandidate:candidate];
    }
    //2.其他新人加入房间的信息
    else if ([eventName isEqualToString:@"_new_peer"])
    {
        NSDictionary *dataDic = dic[@"data"];
        //拿到新人的ID
        NSString *socketId = dataDic[@"socketId"];
        
        //再去创建一个连接
        RTCPeerConnection *peerConnection = [self createPeerConnection:socketId];
        if (!_localStream)
        {
            [self createLocalStream];
        }
        //把本地流加到连接中去
        [peerConnection addStream:_localStream];
        //连接ID新加一个
        [_connectionIdArray addObject:socketId];
        //并且设置到Dic中去
        [_connectionDic setObject:peerConnection forKey:socketId];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            //设置新加入用户代理
            if ([_friendDelegate respondsToSelector:@selector(webRTCHelper:gotNewFriend:)]) {
                [_friendDelegate webRTCHelper:self gotNewFriend:socketId];
            }
        });
    }
    //有人离开房间的事件
    else if ([eventName isEqualToString:@"_remove_peer"])
    {
        //得到socketId，关闭这个peerConnection
        NSDictionary *dataDic = dic[@"data"];
        NSString *socketId = dataDic[@"socketId"];
        [self closePeerConnection:socketId];
        
        //设置关闭某个用户聊天代理回调
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([self->_delegate respondsToSelector:@selector(webRTCHelper:closeWithUserId:)])
            {
                [self->_delegate webRTCHelper:self closeWithUserId:socketId];
            }
            //设置退出房间用户代理回调
            if ([self->_friendDelegate respondsToSelector:@selector(webRTCHelper:removeFriend:)]) {
                [self->_friendDelegate webRTCHelper:self removeFriend:socketId];
            }
        });
        
    }
    //这个新加入的人发了个offer
    else if ([eventName isEqualToString:@"_offer"])
    {
        NSDictionary *dataDic = dic[@"data"];
        NSDictionary *sdpDic = dataDic[@"sdp"];
        //拿到SDP
        NSString *sdp = sdpDic[@"sdp"];
        NSString *socketId = dataDic[@"socketId"];
        
        //拿到这个点对点的连接
        RTCPeerConnection *peerConnection = [_connectionDic objectForKey:socketId];
        //根据类型和SDP 生成SDP描述对象
        RTCSessionDescription *remoteSdp = [[RTCSessionDescription alloc] initWithType:RTCSdpTypeOffer sdp:sdp];
        //设置给这个点对点连接
        __weak RTCPeerConnection *weakPeerConnection = peerConnection;
        [weakPeerConnection setRemoteDescription:remoteSdp completionHandler:^(NSError * _Nullable error) {
            [self setSessionDescriptionWithPeerConnection:weakPeerConnection];
        }];
        
        //设置当前角色状态为被呼叫，（被发offer）
        //        _role = RoleCallee;
    }
    //回应offer
    else if ([eventName isEqualToString:@"_answer"])
    {
        NSDictionary *dataDic = dic[@"data"];
        NSDictionary *sdpDic = dataDic[@"sdp"];
        NSString *sdp = sdpDic[@"sdp"];
        //        NSString *type = sdpDic[@"type"];
        NSString *socketId = dataDic[@"socketId"];
        RTCPeerConnection *peerConnection = [_connectionDic objectForKey:socketId];
        RTCSessionDescription *remoteSdp = [[RTCSessionDescription alloc] initWithType:RTCSdpTypeAnswer sdp:sdp];
        __weak RTCPeerConnection * weakPeerConnection = peerConnection;
        [weakPeerConnection setRemoteDescription:remoteSdp completionHandler:^(NSError * _Nullable error) {
            [self setSessionDescriptionWithPeerConnection:weakPeerConnection];
        }];
    }

}

#pragma mark WebSocketDelegate
- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message{
    
    NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:[message dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingMutableContainers error:nil];
    NSString *eventName = dic[@"mAction"];
    
    if([@"Online" isEqualToString:eventName])
    {
        
    }
    else if ([@"" isEqualToString:eventName])
    {
        //拿到给自己分配的ID
        _myId = @"123";//dataDic[@"you"];
   
        //如果为空，则创建点对点工厂
        if (!_factory)
        {
            //设置SSL传输
            [RTCPeerConnectionFactory initialize];
            _factory = [[RTCPeerConnectionFactory alloc] init];
        }
        //如果本地视频流为空
        if (!_localStream)
        {
            //创建本地流
            [self createLocalStream];
        }
        //创建连接
        RTCPeerConnection *connection =  [self createPeerConnection:@""];//对方ID
        //添加
        [self addStreams];
        //添加offer
        [self createOffer:connection];
        
        
    }
    //1.发送加入房间后的反馈
    else if ([eventName isEqualToString:@"_peers"])
    {
        //得到data
        NSDictionary *dataDic = dic[@"data"];
        //得到所有的连接
        NSArray *connections = dataDic[@"connections"];
        //加到连接数组中去
        [_connectionIdArray addObjectsFromArray:connections];
        
        //拿到给自己分配的ID
        _myId = @"123";//dataDic[@"you"];
   
        //如果为空，则创建点对点工厂
        if (!_factory)
        {
            //设置SSL传输
            [RTCPeerConnectionFactory initialize];
            _factory = [[RTCPeerConnectionFactory alloc] init];
        }
        //如果本地视频流为空
        if (!_localStream)
        {
            //创建本地流
            [self createLocalStream];
        }
        //创建连接
        [self createPeerConnections];
        
        //添加
        [self addStreams];
      //  [self.connection addStream:_localStream];
        [self createOffers];
        
         
        //获取房间内所有用户的代理回调
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([self->_friendDelegate respondsToSelector:@selector(webRTCHelper:gotFriendList:)]) {
                [self->_friendDelegate webRTCHelper:self gotFriendList:connections];
            }
        });
        
    }
    //4.接收到新加入的人发了ICE候选，（即经过ICEServer而获取到的地址）
    else if ([eventName isEqualToString:@"_ice_candidate"])
    {
        NSDictionary *dataDic = dic[@"data"];
        NSString *socketId = dataDic[@"socketId"];
        NSString *sdpMid = dataDic[@"id"];
        int sdpMLineIndex = [dataDic[@"label"] intValue];
        NSString *sdp = dataDic[@"candidate"];
        //生成远端网络地址对象
        RTCIceCandidate *candidate = [[RTCIceCandidate alloc] initWithSdp:sdp sdpMLineIndex:sdpMLineIndex sdpMid:sdpMid];;
        //拿到当前对应的点对点连接
        RTCPeerConnection *peerConnection = [_connectionDic objectForKey:socketId];
        //添加到点对点连接中
        [peerConnection addIceCandidate:candidate];
    }
    //2.其他新人加入房间的信息
    else if ([eventName isEqualToString:@"_new_peer"])
    {
        NSDictionary *dataDic = dic[@"data"];
        //拿到新人的ID
        NSString *socketId = dataDic[@"socketId"];
        
        //再去创建一个连接
        RTCPeerConnection *peerConnection = [self createPeerConnection:socketId];
        if (!_localStream)
        {
            [self createLocalStream];
        }
        //把本地流加到连接中去
        [peerConnection addStream:_localStream];
        //连接ID新加一个
        [_connectionIdArray addObject:socketId];
        //并且设置到Dic中去
        [_connectionDic setObject:peerConnection forKey:socketId];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            //设置新加入用户代理
            if ([_friendDelegate respondsToSelector:@selector(webRTCHelper:gotNewFriend:)]) {
                [_friendDelegate webRTCHelper:self gotNewFriend:socketId];
            }
        });
    }
    //有人离开房间的事件
    else if ([eventName isEqualToString:@"_remove_peer"])
    {
        //得到socketId，关闭这个peerConnection
        NSDictionary *dataDic = dic[@"data"];
        NSString *socketId = dataDic[@"socketId"];
        [self closePeerConnection:socketId];
        
        //设置关闭某个用户聊天代理回调
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([self->_delegate respondsToSelector:@selector(webRTCHelper:closeWithUserId:)])
            {
                [self->_delegate webRTCHelper:self closeWithUserId:socketId];
            }
            //设置退出房间用户代理回调
            if ([self->_friendDelegate respondsToSelector:@selector(webRTCHelper:removeFriend:)]) {
                [self->_friendDelegate webRTCHelper:self removeFriend:socketId];
            }
        });
        
    }
    //这个新加入的人发了个offer
    else if ([eventName isEqualToString:@"_offer"])
    {
        NSDictionary *dataDic = dic[@"data"];
        NSDictionary *sdpDic = dataDic[@"sdp"];
        //拿到SDP
        NSString *sdp = sdpDic[@"sdp"];
        NSString *socketId = dataDic[@"socketId"];
        
        //拿到这个点对点的连接
        RTCPeerConnection *peerConnection = [_connectionDic objectForKey:socketId];
        //根据类型和SDP 生成SDP描述对象
        RTCSessionDescription *remoteSdp = [[RTCSessionDescription alloc] initWithType:RTCSdpTypeOffer sdp:sdp];
        //设置给这个点对点连接
        __weak RTCPeerConnection *weakPeerConnection = peerConnection;
        [weakPeerConnection setRemoteDescription:remoteSdp completionHandler:^(NSError * _Nullable error) {
            [self setSessionDescriptionWithPeerConnection:weakPeerConnection];
        }];
        
        //设置当前角色状态为被呼叫，（被发offer）
        //        _role = RoleCallee;
    }
    //回应offer
    else if ([eventName isEqualToString:@"_answer"])
    {
        NSDictionary *dataDic = dic[@"data"];
        NSDictionary *sdpDic = dataDic[@"sdp"];
        NSString *sdp = sdpDic[@"sdp"];
        //        NSString *type = sdpDic[@"type"];
        NSString *socketId = dataDic[@"socketId"];
        RTCPeerConnection *peerConnection = [_connectionDic objectForKey:socketId];
        RTCSessionDescription *remoteSdp = [[RTCSessionDescription alloc] initWithType:RTCSdpTypeAnswer sdp:sdp];
        __weak RTCPeerConnection * weakPeerConnection = peerConnection;
        [weakPeerConnection setRemoteDescription:remoteSdp completionHandler:^(NSError * _Nullable error) {
            [self setSessionDescriptionWithPeerConnection:weakPeerConnection];
        }];
    }
}

- (void)webSocketDidOpen:(SRWebSocket *)webSocket{
    NSLog(@"socket连接成功");
    [self joinRoom:_room];
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self->_delegate respondsToSelector:@selector(webRTCHelper:socketConnectState:)]) {
            [self->_delegate webRTCHelper:self socketConnectState:WebSocketConnectSuccess];
        }
    });
}

- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error{
    NSLog(@"socket连接失败");
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self->_delegate respondsToSelector:@selector(webRTCHelper:socketConnectState:)]) {
            [self->_delegate webRTCHelper:self socketConnectState:WebSocketConnectSuccess];
        }
    });
}

- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean{
    NSLog(@"socket关闭。code = %ld,reason = %@",code,reason);
}

- (NSString *)getKeyFromConnectionDic:(RTCPeerConnection *)peerConnection
{
    //find socketid by pc
    static NSString *socketId;
    [_connectionDic enumerateKeysAndObjectsUsingBlock:^(NSString *key, RTCPeerConnection *obj, BOOL * _Nonnull stop) {
        if ([obj isEqual:peerConnection])
        {
            NSLog(@"%@",key);
            socketId = key;
        }
    }];
    return socketId;
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
    
//    [mutStr replaceOccurrencesOfString:@" " withString:@"" options:NSLiteralSearch range:range];
    
    NSRange range2 = {0,mutStr.length};
    
    //去掉字符串中的换行符
    
    [mutStr replaceOccurrencesOfString:@"\n" withString:@"" options:NSLiteralSearch range:range2];
    
    return mutStr;
    
}

@end
