//  Copyright (c) 2013 Scott Talbot. All rights reserved.

#import "STPullToRefreshHelper.h"
#import <QuartzCore/QuartzCore.h>


static const CGFloat STPullToRefreshHelperViewHeight = 40;

typedef enum STPullToRefreshState {
    STPullToRefreshStateIdle = 0,
    STPullToRefreshStateWaitingForRelease,
    STPullToRefreshStateLoading,
    STPullToRefreshStateLoaded,
} STPullToRefreshState;


@interface STPullToRefreshHelperView : UIView
@property (nonatomic,assign,readonly) STPullToRefreshState state;
- (void)setState:(STPullToRefreshState)state animated:(BOOL)animated;
@end


@interface STPullToRefreshHelper ()
- (id)initWithDirection:(STPullToRefreshDirection)direction delegate:(id<STPullToRefreshHelperDelegate>)delegate;
@property (nonatomic,weak,readonly) id<STPullToRefreshHelperDelegate> delegate;
@property (nonatomic,strong) STPullToRefreshHelperView *view;
@end


@implementation STPullToRefreshHelper {
@private
    STPullToRefreshDirection _direction;
    STPullToRefreshState _state;
}

- (id)initWithDirection:(STPullToRefreshDirection)direction delegate:(id<STPullToRefreshHelperDelegate>)delegate {
    if ((self = [super init])) {
        _direction = direction;
        _delegate = delegate;

        _view = [[STPullToRefreshHelperView alloc] initWithFrame:(CGRect){ .size = { 320, STPullToRefreshHelperViewHeight } }];
        _view.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleBottomMargin;
    }
    return self;
}

- (void)setScrollView:(UIScrollView *)scrollView {
    [_scrollView removeObserver:self forKeyPath:@"contentSize"];
    [_scrollView removeObserver:self forKeyPath:@"contentOffset"];

    [_view removeFromSuperview];

    _scrollView = scrollView;
    UIView * const view = self.view;

    switch (_direction) {
        case STPullToRefreshDirectionUp: {
            CGRect const frame = (CGRect){ .origin = { .y = -STPullToRefreshHelperViewHeight }, .size = { .width = scrollView.bounds.size.width, .height = STPullToRefreshHelperViewHeight } };
            view.frame = frame;
            view.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleBottomMargin;
            [scrollView addSubview:view];
        } break;
        case STPullToRefreshDirectionDown: {
            CGRect const frame = (CGRect){ .origin = { .y = scrollView.contentSize.height }, .size = { .width = scrollView.bounds.size.width, .height = STPullToRefreshHelperViewHeight } };
            view.frame = frame;
            view.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleTopMargin;
            [scrollView addSubview:view];
        } break;
    }

    [scrollView addObserver:self forKeyPath:@"contentSize" options:NSKeyValueObservingOptionNew context:NULL];
    [scrollView addObserver:self forKeyPath:@"contentOffset" options:NSKeyValueObservingOptionNew context:NULL];
}


- (void)setState:(STPullToRefreshState)state animated:(BOOL)animated {
    if (_state != state) {
        UIScrollView * const scrollView = self.scrollView;
        STPullToRefreshState const oldState = _state;

        _state = state;
        [_view setState:state animated:animated];

        [self modifyScrollView:scrollView forState:state oldState:oldState];
    }
}


- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    UIScrollView * const scrollView = self.scrollView;
    STPullToRefreshHelperView * const view = _view;
    STPullToRefreshDirection const direction = _direction;
    STPullToRefreshState const state = _state;

    if (object == scrollView) {
        if ([keyPath isEqualToString:@"contentSize"]) {
            if (direction == STPullToRefreshDirectionDown) {
                CGRect f = view.frame;
                f.origin.y = scrollView.contentSize.height;
                view.frame = f;
            }
        } else if ([keyPath isEqualToString:@"contentOffset"]) {
            if (state != STPullToRefreshStateLoading) {
                CGPoint const contentOffset = scrollView.contentOffset;
                CGFloat const pullDistance = STPullToRefreshHelperViewHeight;

                if (scrollView.isDragging) {
                    switch (direction) {
                        case STPullToRefreshDirectionUp: {
                            STPullToRefreshState newState;
                            if (contentOffset.y < -pullDistance) {
                                newState = STPullToRefreshStateWaitingForRelease;
                            } else {
                                newState = STPullToRefreshStateIdle;
                            }
                            [self setState:newState animated:YES];
                        } break;
                        case STPullToRefreshDirectionDown: {
                            CGSize contentSize = scrollView.contentSize;
                            CGSize frameSize = scrollView.frame.size;

                            STPullToRefreshState newState;
                            if (contentOffset.y > (contentSize.height - frameSize.height + pullDistance)) {
                                newState = STPullToRefreshStateWaitingForRelease;
                            } else {
                                newState = STPullToRefreshStateIdle;
                            }
                            [self setState:newState animated:YES];
                        } break;
                    }
                } else if (state == STPullToRefreshStateWaitingForRelease) {
                    [self setState:STPullToRefreshStateLoading animated:YES];
                    [self notifyDidTriggerLoad];
                }
            }
        }
    }
}

- (void)notifyDidTriggerLoad {
    id<STPullToRefreshHelperDelegate> const delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(pullToRefreshHelperDidTriggerLoad:)]) {
        [delegate pullToRefreshHelperDidTriggerLoad:self];
    }
}

- (void)didFinishLoading {
    STPullToRefreshState const state = _state;
    if (state == STPullToRefreshStateLoading) {
        [self setState:STPullToRefreshStateLoaded animated:YES];
        [self.scrollView flashScrollIndicators];
    }
}

- (void)modifyScrollView:(UIScrollView *)scrollView forState:(STPullToRefreshState)state oldState:(STPullToRefreshState)oldState {
    int verticalInsetModifier = 0;
    if (state == STPullToRefreshStateLoading && oldState != STPullToRefreshStateLoading) {
        verticalInsetModifier = 1;
    } else if (state != STPullToRefreshStateLoading && oldState == STPullToRefreshStateLoading) {
        verticalInsetModifier = -1;
    }

    CGFloat const verticalInset = STPullToRefreshHelperViewHeight;
    UIEdgeInsets edgeInsets = scrollView.contentInset;
    switch (_direction) {
        case STPullToRefreshDirectionUp:
            edgeInsets.top += verticalInset * verticalInsetModifier;
            break;
        case STPullToRefreshDirectionDown:
            edgeInsets.bottom += verticalInset * verticalInsetModifier;
            break;
    }

    [UIView animateWithDuration:1./3. delay:0 options:UIViewAnimationOptionBeginFromCurrentState|UIViewAnimationOptionAllowUserInteraction animations:^{
        [scrollView setContentInset:edgeInsets];
    } completion:nil];
}

@end


@interface STPullToRefreshHelperView () {
@private
    UIActivityIndicatorView *_activityIndicatorView;
    UILabel *_pullInstructionsLabel;
    UILabel *_releaseInstructionsLabel;
}
@end


@implementation STPullToRefreshHelperView
@synthesize state = _state;
- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:CGRectMake(0, 0, 320, 40)])) {
        CGRect const bounds = self.bounds;
        self.backgroundColor = [UIColor clearColor];
        self.opaque = NO;

        UIActivityIndicatorView * const activityIndicatorView = _activityIndicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        activityIndicatorView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleRightMargin|UIViewAutoresizingFlexibleTopMargin|UIViewAutoresizingFlexibleBottomMargin;
        CGRect activityIndicatorViewFrame = activityIndicatorView.frame;
        activityIndicatorViewFrame.origin.x = (bounds.size.width - activityIndicatorViewFrame.size.width) / 2;
        activityIndicatorViewFrame.origin.y = (bounds.size.height - activityIndicatorViewFrame.size.height) / 2;
        activityIndicatorView.frame = activityIndicatorViewFrame;
        {
            UIView * const activityIndicatorViewBackground = [[UIView alloc] initWithFrame:CGRectInset(_activityIndicatorView.bounds, -4, -4)];
            activityIndicatorViewBackground.backgroundColor = [UIColor colorWithWhite:1 alpha:.7];
            activityIndicatorViewBackground.layer.masksToBounds = YES;
            activityIndicatorViewBackground.layer.cornerRadius = 6;
            [activityIndicatorView insertSubview:activityIndicatorViewBackground atIndex:0];
        }
        [self addSubview:activityIndicatorView];

        UILabel * const pullInstructionsLabel = _pullInstructionsLabel = [[UILabel alloc] initWithFrame:bounds];
        pullInstructionsLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
        pullInstructionsLabel.font = [UIFont boldSystemFontOfSize:14];
        pullInstructionsLabel.textColor = [UIColor lightGrayColor];
        pullInstructionsLabel.textAlignment = NSTextAlignmentCenter;
        pullInstructionsLabel.text = @"Pull To Refresh";
        [pullInstructionsLabel sizeToFit];
        pullInstructionsLabel.frame = bounds;
        pullInstructionsLabel.backgroundColor = [UIColor colorWithWhite:1 alpha:.7];
        pullInstructionsLabel.layer.masksToBounds = YES;
        pullInstructionsLabel.layer.cornerRadius = 6;
        [self addSubview:pullInstructionsLabel];

        UILabel * const releaseInstructionsLabel = _releaseInstructionsLabel = [[UILabel alloc] initWithFrame:bounds];
        releaseInstructionsLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
        releaseInstructionsLabel.font = [UIFont boldSystemFontOfSize:14];
        releaseInstructionsLabel.textColor = [UIColor lightGrayColor];
        releaseInstructionsLabel.textAlignment = NSTextAlignmentCenter;
        releaseInstructionsLabel.text = @"Release To Refresh";
        [releaseInstructionsLabel sizeToFit];
        releaseInstructionsLabel.frame = bounds;
        releaseInstructionsLabel.backgroundColor = [UIColor colorWithWhite:1 alpha:.7];
        releaseInstructionsLabel.layer.masksToBounds = YES;
        releaseInstructionsLabel.layer.cornerRadius = 6;
        [self addSubview:releaseInstructionsLabel];

        activityIndicatorView.alpha = 0;
        pullInstructionsLabel.alpha = 1;
        releaseInstructionsLabel.alpha = 0;
    }
    return self;
}

- (void)setState:(STPullToRefreshState)state {
    return [self setState:state animated:NO];
}
- (void)setState:(STPullToRefreshState)state animated:(BOOL)animated {
    if (_state != state) {
        _state = state;

        if (_state == STPullToRefreshStateLoading) {
            [_activityIndicatorView startAnimating];
        }

        [UIView animateWithDuration:.2 delay:0 options:UIViewAnimationOptionAllowUserInteraction animations:^{
            _activityIndicatorView.alpha = (state == STPullToRefreshStateLoading) ? 1 : 0;
            _pullInstructionsLabel.alpha = (state == STPullToRefreshStateIdle) ? 1 : 0;
            _releaseInstructionsLabel.alpha = (state == STPullToRefreshStateWaitingForRelease) ? 1 : 0;
        } completion:^(BOOL finished) {
            if (_state != STPullToRefreshStateLoading) {
                [_activityIndicatorView stopAnimating];
            }
        }];
    }
}

@end
