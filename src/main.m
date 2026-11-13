// main.m — iOS 端入口。
//
// ★ 本轮修正（2026-10-24）
// 旧版有两个致命问题：
//   1. UIApplicationMain(argc, argv, nil, nil) —— 不传 delegate，也没有
//      UIWindow / rootViewController，App 启动后是一片空白。
//      现在改用 AppDelegate 建 window 并挂 CameraViewController。
//   2. 在 main() 里调 bef_init，而 CameraViewController 里也会调一次 ——
//      二次 init 在安卓侧已实证会损坏 EffectManager 内部状态
//      （SIGSEGV fault addr 0x0）。现在 init 只由 CameraViewController 负责。

#import <UIKit/UIKit.h>
#import "CameraViewController.h"

@interface GCCAppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation GCCAppDelegate

- (BOOL)application:(UIApplication *)application
didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.backgroundColor = [UIColor blackColor];

    CameraViewController *vc = [[CameraViewController alloc] init];
    self.window.rootViewController = vc;
    [self.window makeKeyAndVisible];
    return YES;
}

@end

int main(int argc, char *argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil,
                                 NSStringFromClass([GCCAppDelegate class]));
    }
}
