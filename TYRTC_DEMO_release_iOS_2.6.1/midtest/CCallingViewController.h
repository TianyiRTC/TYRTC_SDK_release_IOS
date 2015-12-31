#import <UIKit/UIKit.h>
#import "sdkkey.h"

typedef enum EVENTID//监听事件由应用自定义
{
    MSG_NEED_VIDEO = 4000,//创建视频
    MSG_SET_AUDIO_DEVICE = 4001,//设置扬声器
    MSG_SET_VIDEO_DEVICE = 4002,//切换摄像头
    MSG_HIDE_LOCAL_VIDEO = 4003,//隐藏本地窗口
    MSG_ROTATE_REMOTE_VIDEO = 4004,//旋转摄像头
    MSG_SNAP = 4005,//截图
    MSG_MUTE = 4006,//静音
    MSG_SENDDTMF = 4007,//发送DTMF
    MSG_DOHOLD = 4008,
    MSG_UPDATE_CALLDURATION = 4009,//刷新通话状态
    MSG_HANGUP = 4010,//挂断
    MSG_ACCEPT = 4011,//接听
    MSG_REJECT = 4012,//拒接
#if(SDK_HAS_GROUP>0)
    MSG_GROUP_CREATE = 4013,//创建多人
    MSG_GROUP_ACCEPT = 4014,//接听多人
    MSG_GROUP_LIST = 4015,//获取成员列表
    MSG_GROUP_INVITE = 4016,//邀请成员
    MSG_GROUP_KICK = 4017,//踢出成员
    MSG_GROUP_CLOSE = 4018,//结束多人
    MSG_GROUP_UNMUTE = 4019,//两方下给麦，对讲下抢麦
    MSG_GROUP_MUTE = 4020,//两方下收麦，对讲下释麦
    MSG_GROUP_DISPLAY = 4021,//视频分屏
    MSG_GROUP_JOIN = 4022,//加入多人
#endif
    MSG_START_RECORDING = 4023,//开始录制
    MSG_STOP_RECORDING = 4024,//停止录制
}eventid;

#define CALLINGVIEW_TAG 2000

@interface CCallingViewController : UIViewController
@property(nonatomic,assign)BOOL isCallOut;//1为呼出，0为被叫，包括多人及点对点
@property(nonatomic,assign)BOOL isVideo;//1为视频，0为音频
@property(nonatomic,assign)BOOL isAutoRotate;//是否允许对方画面自动旋转为竖直方向
#if(SDK_HAS_GROUP>0)
@property (nonatomic, retain) IBOutlet UITextField*           mUser3;
#endif

-(void)onCallOk:(BOOL)callOK;
-(void)setCallStatus:(NSString*)log;
@end
