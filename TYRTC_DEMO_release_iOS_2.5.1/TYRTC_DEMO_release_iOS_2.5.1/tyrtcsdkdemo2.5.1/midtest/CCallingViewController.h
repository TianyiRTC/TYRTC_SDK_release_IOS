#import <UIKit/UIKit.h>
#import "sdkkey.h"
typedef enum EVENTID
{
    MSG_NEED_VIDEO = 4000,
    MSG_SET_AUDIO_DEVICE = 4001,
    MSG_SET_VIDEO_DEVICE = 4002,
    MSG_HIDE_LOCAL_VIDEO = 4003,
    MSG_ROTATE_REMOTE_VIDEO = 4004,
    MSG_SNAP = 4005,
    MSG_MUTE = 4006,
    MSG_SENDDTMF = 4007,
    MSG_DOHOLD = 4008,
    MSG_UPDATE_CALLDURATION = 4009,
    MSG_HANGUP = 4010,
    MSG_ACCEPT = 4011,
    MSG_REJECT = 4012,
#if(SDK_HAS_GROUP>0)
    MSG_GROUP_CREATE = 4013,
    MSG_GROUP_ACCEPT = 4014,
    MSG_GROUP_LIST = 4015,
    MSG_GROUP_INVITE = 4016,
    MSG_GROUP_KICK = 4017,
    MSG_GROUP_CLOSE = 4018,
    MSG_GROUP_UNMUTE = 4019,
    MSG_GROUP_MUTE = 4020,
    MSG_GROUP_DISPLAY = 4021,
    MSG_GROUP_JOIN = 4022,
    MSG_GROUP_GRPLIST = 4023,
#endif
}eventid;

#define CALLINGVIEW_TAG 2000

@interface CCallingViewController : UIViewController
@property(nonatomic,assign)BOOL isCallOut;
@property(nonatomic,assign)BOOL isVideo;
@property(nonatomic,assign)BOOL isAutoRotate;
#if(SDK_HAS_GROUP>0)
@property (nonatomic, retain) IBOutlet UITextField*           mUser3;
#endif

-(void)onCallOk:(BOOL)callOK;
-(void)setCallStatus:(NSString*)log;
@end
