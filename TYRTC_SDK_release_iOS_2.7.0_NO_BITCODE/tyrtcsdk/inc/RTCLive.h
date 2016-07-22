//
//  RTCLive.h
//  RTCLive
//
//  Created by dongzhm on 16/3/17.
//  Copyright © 2016年 ding. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
//错误码
#define EC_START_IDX -1000
#define ECIDXMAKE(IDX)  (EC_START_IDX-IDX)
#define EC_OK                   0
#define EC_MALLOC_MEM_FAILED	ECIDXMAKE(1)
#define EC_PARAM_WRONG			ECIDXMAKE(2)
#define EC_LOST_KEY				ECIDXMAKE(3)
#define EC_CANTT_RESET_PARAM	ECIDXMAKE(4)
#define EC_MAKE_CALL_FAILED     ECIDXMAKE(5)
#define EC_HAVENT_CALL          ECIDXMAKE(6)
#define EC_ACTION_FAILED        ECIDXMAKE(7)
#define EC_SDK_INITED           ECIDXMAKE(8)
#define EC_SDK_INIT_UNCOMPLETED ECIDXMAKE(9)
#define EC_SIZE_TOO_LARGE       ECIDXMAKE(10)
#define EC_UNSUPPORTED_FUNC     ECIDXMAKE(11)

typedef enum
{
    CinLogLevelDebug = 0,
    CinLogLevelInfo,
    CinLogLevelWarning,
    CinLogLevelError
}CinLogLevel;


@protocol RTCLiveCallBackProtocol <NSObject>
/**
 *   登陆RTC云平台结果回调
 *
 *  @param code   获取结果
 *  @param error  错误原因
 */
-(void)onNavigationResp:(int)code error:(NSString*)error;
@end


#define RTCLivePlayerPlaybackDidFinishNotification @"PlaybackDidFinish" //当播放结束时,发送本通知
#define RTCLivePlayerPlaybackErrorNotification     @"PlaybackError"     //当播放器发生错误时,发送本通知 ￼


@interface RTCLive : NSObject
{
    int                     mObjId;
    id<RTCLiveCallBackProtocol> mDelegate;
}
@property(nonatomic,assign)int ObjId;
@property(nonatomic,assign)id<RTCLiveCallBackProtocol> Delegate;
+(NSString*)ECodeToStr:(int)code;

/**
 *  对象初始化
 *
 *  @return  生成的RTCLive对象
 */
-(id)init;

/**
 *  登录RTC云平台
 *  @param appId      平台申请的appid
 *  @param appKey     平台申请的appkey
 *  @param usrId      平台申请的usrid
 *  @param usrKey     平台申请的usrkey
 *
 *  @return EC_OK，登录结果由回调函数返回
 */
-(int)loginRtcCloud:(NSString*)appId appKey:(NSString*)appKey usrId:(NSString*)usrId usrKey:(NSString*)usrKey;

/**
 *  登录RTC云平台
 *  @param appId      平台申请的appid
 *  @param usrId      平台申请的usrid
 *  @param token      平台申请的token
 *
 *  @return EC_OK，登录结果由回调函数返回
 */
-(int)loginRtcCloud:(NSString*)appId usrId:(NSString*)usrId token:(NSString*)token;

/**
 *  播放直播：sdk构建播放界面和相关控制按钮以及交互响应
 *  @param mediaPath   媒体地址
 *  @return UIViewController，如果创建成功返回UIViewController，如果创建失败返回NULL
 */
+(id)playMedia:(NSString *)mediaPath;

/**
 *  播放直播：sdk只是构建播放的UIView，不含控制按钮和交互响应
 *  @param mediaPath   媒体地址
 *  @param bounds      播放的位置：坐标和宽高构成的CGRect
 *  返回 UIView，如果创建成功返回UIView，如果创建失败返回NULL
 */
-(id)playMedia:(NSString *)mediaPath bounds:(CGRect)bounds;

/**
 *  停止播放直播
 *  @return EC_OK或者错误码
 */
-(int)stopPlayMedia;

/**
 *  开始直播预览
 *  必须先调用此接口开始直播预览，在预览窗口可以切换摄像头
 *  @param width              视频宽度
 *  @param height             视频高度
 *  @param videoFramerate     视频帧率
 *  @param cameraId           摄像头选择：0 后置摄像头，1 前置摄像头
 *  @param videoCodec         编码器选择：0 硬件编码，1 软件编码
 *  @param onlyAudio          仅音频直播
 *  @param localVideoWindow   视频预览窗口
 *  @return EC_OK或者错误码
 */
-(int)startPreview:(int)width height:(int)height videoFramerate:(int)videoFramerate cameraId:(int)cameraId videoCodec:(int)videoCodec onlyAudio:(int)onlyAudio localVideoWindow:(void*)localVideoWindow;

/**
 *  开始直播
 *  必须先调用startPreview之后再调用此接口开始直播
 *  @param channelID          直播频道
 *  @param pushURL            直播推流地址
 *  @return EC_OK或者错误码
 */
-(int)startCast:(int)channelID pushURL:(const char*)pushURL;

/**
 *  停止直播
 *  @return EC_OK或者错误码
 */
-(int)stop;

/**
 *  切换摄像头
 *  @return EC_OK或者错误码
 */
-(int)SwitchCamera;

/**
 *  旋转摄像头
 *  @return EC_OK或者错误码
 *  @param angle: 0, 90, 180, 270
 *  @return EC_OK或者错误码
 */
-(int)RotateCamera:(int)angle;

/**
 *  关闭麦克/开启麦克
 *  @param bMute: 1 关闭麦克 ，0 开启麦克
 *  @return EC_OK或者错误码
 */
-(int)MuteMic:(int)bMute;

/**
 *  暂停直播额
 *  @param bPause: 1 暂停直播 ，0 继续直播
 *  @return EC_OK或者错误码
 */
-(int)Pause:(int)bPause;

/**
 *  @return 得到直播已发送字节，单位KB
 */
-(long)GetKBSend;

/**
 *  @return 得到直播缓存中字节，单位KB
 */
-(long)GetKBQueue;

/**
 *  @return 得到直播上传速率，单位KB/S
 */
-(long)GetKBitrate;

/**
 *  @return 得到直播时间，单位S
 */
-(long)GetTimeSend;

/**
 *  @return 直播状态
 */
-(long)IsConnected;

/**
 *  对象释放
 */
-(void)dealloc;

#define SCREEN_WIDTH       [[UIScreen mainScreen] bounds].size.width
#define SCREEN_HEIGHT      [[UIScreen mainScreen] bounds].size.height
#define SCREEN_SCALE        [UIScreen mainScreen].scale
//系统是否为ios5以上
#define ISIOS5 !([[[UIDevice currentDevice] systemVersion] floatValue] <=4.9f)
//系统是否为ios6以上
#define ISIOS6 !([[[UIDevice currentDevice] systemVersion] floatValue] <=5.9f)
//系统是否为ios7以上
#define ISIOS7 !([[[UIDevice currentDevice] systemVersion] floatValue] <=6.9f)
//状态栏高度
#define  CW_STATUSBAR_HEIGHT  20.0f
#define  IOS7_STATUSBAR_DELTA   (ISIOS7?(CW_STATUSBAR_HEIGHT):0)

@end


//#define iPhone5 ([UIScreen instancesRespondToSelector:@selector(currentMode)] ? CGSizeEqualToSize(CGSizeMake(640, 1136), [[UIScreen mainScreen] currentMode].size) : NO)
#define SCREEN_WIDTH       [[UIScreen mainScreen] bounds].size.width
#define SCREEN_HEIGHT      [[UIScreen mainScreen] bounds].size.height
#define SCREEN_SCALE        [UIScreen mainScreen].scale
//系统是否为ios5以上
#define ISIOS5 !([[[UIDevice currentDevice] systemVersion] floatValue] <=4.9f)
//系统是否为ios6以上
#define ISIOS6 !([[[UIDevice currentDevice] systemVersion] floatValue] <=5.9f)
//系统是否为ios7以上
#define ISIOS7 !([[[UIDevice currentDevice] systemVersion] floatValue] <=6.9f)
//状态栏高度
#define  CW_STATUSBAR_HEIGHT  20.0f
#define  IOS7_STATUSBAR_DELTA   (ISIOS7?(CW_STATUSBAR_HEIGHT):0)
