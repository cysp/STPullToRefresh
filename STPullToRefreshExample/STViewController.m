//  Copyright (c) 2013 Scott Talbot. All rights reserved.

#import "STViewController.h"
#import "STPullToRefreshHelper.h"


@interface STPullToRefreshExampleView : STPullToRefreshHelperView<STPullToRefreshHelperView>
@end
@implementation STPullToRefreshExampleView {
@private
    UIView *_innerView;
}
+ (CGFloat)naturalHeight {
    return 40;
}
- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        UIView * const innerView = _innerView = [[UIView alloc] initWithFrame:CGRectZero];
        innerView.backgroundColor = [[UIColor orangeColor] colorWithAlphaComponent:.2];
        [self addSubview:innerView];

        self.backgroundColor = [UIColor redColor];
    }
    return self;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    CGRect const bounds = self.bounds;
    UIView * const innerView = _innerView;
    innerView.frame = CGRectInset(bounds, 2, 2);
}
- (void)setState:(STPullToRefreshState)state animated:(BOOL)animated {
    [super setState:state animated:animated];
}
@end

@interface STViewController () <STPullToRefreshHelperDelegate>
@property (nonatomic,strong) UIScrollView *scrollView;
@property (nonatomic,strong,readonly) STPullToRefreshHelper *pulltorefreshHelper;
@end

@implementation STViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
        _pulltorefreshHelper = [[STPullToRefreshHelper alloc] initWithDirection:STPullToRefreshDirectionUp viewClass:nil delegate:self];

        self.navigationItem.rightBarButtonItem = self.editButtonItem;
    }
    return self;
}

- (void)loadView {
    self.view = [[UIView alloc] initWithFrame:(CGRect){ .size = { .width = 320, .height = 480 }}];
    UIView * const view = self.view;
    view.backgroundColor = [UIColor whiteColor];

    UIScrollView * const scrollView = _scrollView = [[UITableView alloc] initWithFrame:view.bounds style:UITableViewStylePlain];
    scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    [view addSubview:scrollView];

    scrollView.alwaysBounceVertical = YES;
    scrollView.contentSize = scrollView.bounds.size;
    scrollView.bounces = YES;
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    id<UILayoutSupport> const topLayoutGuide = [self respondsToSelector:@selector(topLayoutGuide)] ? self.topLayoutGuide : nil;
    UIEdgeInsets const contentInset = (UIEdgeInsets){
        .top = topLayoutGuide.length,
    };

    UIScrollView * const scrollView = self.scrollView;
    STPullToRefreshHelper * const pulltorefreshHelper = self.pulltorefreshHelper;

    scrollView.contentSize = scrollView.bounds.size;
    scrollView.contentInset = contentInset;
    scrollView.scrollIndicatorInsets = contentInset;

    pulltorefreshHelper.scrollView = scrollView;
}

#pragma mark - STPullToRefreshHelperDelegate

- (void)pullToRefreshHelperDidTriggerLoad:(STPullToRefreshHelper *)helper {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^(void){
        [helper didFinishLoading];
    });
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    NSLog(@"foo");
}

@end
