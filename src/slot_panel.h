// slot_panel.h - 51 根滑条的原生 UI（iOS 侧）
//
// 表本身来自 effect_slots.h（与安卓 CameraActivity.<clinit> 逐条对齐）。
// 这个面板只做一件事：把每根滑条的变化直接喂给 gcc_slot_set(index, v)，
// 不经过任何 JS / 事件 / Lua 中转。

#import <UIKit/UIKit.h>

@interface GccSlotPanel : UIView

// width: 面板宽度（一般传 self.view.bounds.size.width）
- (instancetype)initWithWidth:(CGFloat)width;

// 把每根滑条重置成中性值（形变 0.5，其它 0.0）并同步写引擎
- (void)resetToNeutral;

// 把当前所有滑条值一次性灌进引擎（切换美颜开关后调，避免清空）
- (void)pushAll;

@end
