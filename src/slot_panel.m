// slot_panel.m - 51 根滑条的原生 UI
//
// 每根滑条一个 UISlider，tag = 表里的 index，值一变直接调 gcc_slot_set。
// 没有任何定时器、没有队列、没有 JS 中转 —— 安卓那边踩过的队列容量、
// 脚本长度上限、启动竞态在这一侧都不存在。

#import "slot_panel.h"
#import "effect_slots.h"

static UILabel *gccMakeLabel(NSString *text, UIFont *font, UIColor *color) {
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectZero];
    l.text = text;
    l.font = font;
    l.textColor = color;
    l.backgroundColor = [UIColor clearColor];
    return l;
}

@implementation GccSlotPanel {
    UIScrollView *_scroll;
    NSMutableArray<UISlider *> *_sliders;   // 下标 = slot index，跳过的位置放 NSNull
    NSMutableArray *_valueLabels;
    NSMutableArray<NSNumber *> *_indexList;
}

- (instancetype)initWithWidth:(CGFloat)width {
    self = [super initWithFrame:CGRectMake(0, 0, width, 260)];
    if (self) {
        self.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.35];
        [self buildRows];
    }
    return self;
}

- (void)buildRows {
    _sliders     = [NSMutableArray array];
    _valueLabels = [NSMutableArray array];
    _indexList   = [NSMutableArray array];

    _scroll = [[UIScrollView alloc] initWithFrame:self.bounds];
    _scroll.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _scroll.showsVerticalScrollIndicator = YES;
    [self addSubview:_scroll];

    UIFont *nameFont  = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
    UIFont *valueFont = [UIFont monospacedSystemFontOfSize:10 weight:UIFontWeightRegular];

    CGFloat w     = self.bounds.size.width;
    CGFloat rowH  = 26.0f;
    CGFloat nameW = 76.0f;
    CGFloat valW  = 44.0f;
    CGFloat y     = 2.0f;

    for (int i = 0; i < GCC_SLOT_COUNT; i++) {
        const GccSlot *s = &GCC_SLOTS[i];
        if (s->kind == GCC_KIND_NONE) continue;      // 第 0 行「无」不建控件

        NSString *name = s->label ? [NSString stringWithUTF8String:s->label] : @"?";
        if (name == nil) name = [NSString stringWithFormat:@"#%d", i];

        UILabel *nameLbl = gccMakeLabel(name, nameFont, [UIColor colorWithWhite:0.92 alpha:1.0]);
        nameLbl.frame = CGRectMake(6, y, nameW, rowH);
        nameLbl.adjustsFontSizeToFitWidth = YES;
        [_scroll addSubview:nameLbl];

        UISlider *sl = [[UISlider alloc] initWithFrame:CGRectMake(nameW + 6, y, w - nameW - valW - 20, rowH)];
        sl.minimumValue = 0.0f;
        sl.maximumValue = 1.0f;
        sl.tag = i;
        sl.value = [self neutralValueForKind:s->kind];
        // 形变类中性值是 0.5，用刻度条提示一下
        sl.minimumTrackTintColor = (s->kind == GCC_KIND_WARP) ? [UIColor colorWithRed:0.4 green:0.85 blue:0.6 alpha:1]
                                                             : [UIColor colorWithRed:0.4 green:0.6 blue:0.95 alpha:1];
        [sl addTarget:self action:@selector(onSliderChanged:)
     forControlEvents:UIControlEventValueChanged];
        [_scroll addSubview:sl];
        [_sliders addObject:sl];
        [_indexList addObject:@(i)];

        UILabel *valLbl = gccMakeLabel([NSString stringWithFormat:@"%.2f", sl.value],
                                       valueFont, [UIColor colorWithWhite:0.8 alpha:1.0]);
        valLbl.frame = CGRectMake(w - valW - 6, y, valW, rowH);
        valLbl.textAlignment = NSTextAlignmentRight;
        [_scroll addSubview:valLbl];
        [_valueLabels addObject:valLbl];

        y += rowH;
    }

    _scroll.contentSize = CGSizeMake(w, y + 4);
}

- (float)neutralValueForKind:(int)kind {
    return (kind == GCC_KIND_WARP) ? 0.5f : 0.0f;
}

- (void)onSliderChanged:(UISlider *)sl {
    int idx = (int)sl.tag;
    gcc_slot_set(idx, sl.value);
    for (NSUInteger k = 0; k < _indexList.count; k++) {
        if ([_indexList[k] intValue] == idx) {
            UILabel *vl = _valueLabels[k];
            vl.text = [NSString stringWithFormat:@"%.2f", sl.value];
            break;
        }
    }
}

- (void)pushAll {
    int bad = 0;
    for (NSUInteger k = 0; k < _sliders.count; k++) {
        UISlider *sl = _sliders[k];
        if (gcc_slot_set((int)sl.tag, sl.value) != 0) bad++;
    }
    NSLog(@"[panel] pushAll rows=%lu bad=%d", (unsigned long)_sliders.count, bad);
}

- (void)resetToNeutral {
    for (NSUInteger k = 0; k < _sliders.count; k++) {
        UISlider *sl   = _sliders[k];
        int idx        = [(_indexList[k]) intValue];
        const GccSlot *s = &GCC_SLOTS[idx];
        sl.value = [self neutralValueForKind:s->kind];
        UILabel *vl = _valueLabels[k];
        vl.text = [NSString stringWithFormat:@"%.2f", sl.value];
    }
    [self pushAll];
    NSLog(@"[panel] resetToNeutral done");
}

@end
