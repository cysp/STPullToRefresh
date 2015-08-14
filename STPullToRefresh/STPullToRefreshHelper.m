//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2013 Scott Talbot. All rights reserved.

#import "STPullToRefreshHelper.h"
#import <QuartzCore/QuartzCore.h>


@interface STPullToRefreshHelper ()
- (id)initWithDirection:(STPullToRefreshDirection)direction delegate:(id<STPullToRefreshHelperDelegate>)delegate;
@property (nonatomic,weak,readonly) id<STPullToRefreshHelperDelegate> delegate;
@property (nonatomic,strong) UIView<STPullToRefreshHelperView> *view;
@end


@implementation STPullToRefreshHelper {
@private
    STPullToRefreshDirection _direction;
    STPullToRefreshState _state;
    CGFloat _topContentInsetScrollAdjustment;
    NSDate *_loadingStartDate;
}

- (id)initWithDirection:(STPullToRefreshDirection)direction delegate:(id<STPullToRefreshHelperDelegate>)delegate {
    return [self initWithDirection:direction viewClass:nil delegate:delegate];
}
- (id)initWithDirection:(STPullToRefreshDirection)direction viewClass:(Class)viewClass delegate:(id<STPullToRefreshHelperDelegate>)delegate {
    if ((self = [super init])) {
        _direction = direction;
        _delegate = delegate;

        viewClass = viewClass ?: [STPullToRefreshHelperView class];
        CGFloat const viewHeight = [viewClass naturalHeight];
        _view = [[viewClass alloc] initWithFrame:(CGRect){ .size = { 320, viewHeight } }];
        _view.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleBottomMargin;
        _triggerDistance = viewHeight;
    }
    return self;
}

- (void)dealloc {
    [_scrollView removeObserver:self forKeyPath:@"contentSize"];
    [_scrollView removeObserver:self forKeyPath:@"contentOffset"];
    [_scrollView removeObserver:self forKeyPath:@"contentInset"];
}

- (void)setScrollView:(UIScrollView *)scrollView {
    if (scrollView != _scrollView) {
        [_scrollView removeObserver:self forKeyPath:@"contentSize"];
        [_scrollView removeObserver:self forKeyPath:@"contentOffset"];
        [_scrollView removeObserver:self forKeyPath:@"contentInset"];

        [_view removeFromSuperview];

        _scrollView = scrollView;
        UIView * const view = self.view;
        CGFloat const viewHeight = [view.class naturalHeight];

        switch (_direction) {
            case STPullToRefreshDirectionUp: {
                CGRect const frame = (CGRect){ .origin = { .y = -viewHeight }, .size = { .width = scrollView.bounds.size.width, .height = viewHeight } };
                view.frame = frame;
                view.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleBottomMargin;
                [scrollView insertSubview:view atIndex:0];
            } break;
        }

        [scrollView addObserver:self forKeyPath:@"contentSize" options:NSKeyValueObservingOptionNew context:NULL];
        [scrollView addObserver:self forKeyPath:@"contentOffset" options:NSKeyValueObservingOptionNew context:NULL];
        [scrollView addObserver:self forKeyPath:@"contentInset" options:NSKeyValueObservingOptionNew context:NULL];
    }
}


- (void)setState:(STPullToRefreshState)state animated:(BOOL)animated {
    if (_state != state) {
        UIScrollView * const scrollView = self.scrollView;
        STPullToRefreshState const oldState = _state;

        if (state == STPullToRefreshStateLoading) {
            _loadingStartDate = [NSDate date];
        }
        
        _state = state;
        [_view setState:state animated:animated];

        [self modifyScrollView:scrollView forState:state oldState:oldState animated:animated];
    }
}

- (void)setStateLoadingAnimated:(BOOL)animated {
    __weak __typeof__(self) wself = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __typeof__(self) sself = wself;
        if (sself) {
            [sself setState:STPullToRefreshStateLoading animated:animated];
        }
    });
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    UIScrollView * const scrollView = self.scrollView;
    UIEdgeInsets const contentInset = scrollView.contentInset;
    CGPoint const contentOffset = scrollView.contentOffset;
    UIView<STPullToRefreshHelperView> * const view = _view;
    CGFloat const viewHeight = [view.class naturalHeight];
    STPullToRefreshDirection const direction = _direction;
    STPullToRefreshState const state = _state;

    if (object == scrollView) {
        CGFloat const scrollViewOriginY = contentOffset.y + contentInset.top;
        CGFloat viewOriginY;
        if (state == STPullToRefreshStateLoading) {
            viewOriginY = scrollViewOriginY - viewHeight + _topContentInsetScrollAdjustment;
        } else {
            viewOriginY = scrollViewOriginY;
        }

        CGPoint viewCenter = (CGPoint){
            .x = CGRectGetMidX(scrollView.bounds),
            .y = viewOriginY + viewHeight/2.,
        };
        view.center = viewCenter;
        
        if ([keyPath isEqualToString:@"contentOffset"]) {
            if (state == STPullToRefreshStateLoading) {
                UIEdgeInsets contentInset = scrollView.contentInset;
                CGFloat topContentInsetMax = contentInset.top + _topContentInsetScrollAdjustment;
                CGFloat topContentInsetMin = topContentInsetMax - self.verticalInsetOffsetWhileLoading;
                CGFloat desiredTopContentInset = MIN(MAX(topContentInsetMin, -scrollView.contentOffset.y), topContentInsetMax);
                if (desiredTopContentInset != contentInset.top) {
                    _topContentInsetScrollAdjustment += contentInset.top - desiredTopContentInset;
                    contentInset.top = desiredTopContentInset;
                    scrollView.contentInset = contentInset;
                }
            }
            
            CGFloat const triggerDistance = [self triggerDistance];
            CGFloat const pullDistance = -(contentInset.top + contentOffset.y);

            if (state == STPullToRefreshStateIdle || state == STPullToRefreshStateWaitingForRelease) {
                if ([view respondsToSelector:@selector(setTriggerPrimingProgress:)]) {
                    [view setTriggerPrimingProgress:(pullDistance / triggerDistance)];
                }
            }

            if (state != STPullToRefreshStateLoading) {
                if (scrollView.isDragging) {
                    switch (direction) {
                        case STPullToRefreshDirectionUp: {
                            STPullToRefreshState newState;
                            if (pullDistance > triggerDistance) {
                                newState = STPullToRefreshStateWaitingForRelease;
                            } else {
                                newState = STPullToRefreshStateIdle;
                            }
                            [self setState:newState animated:NO];
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
    // Delay until we've animated for at least _minimumLoadingTime
    NSTimeInterval delay = 0;
    NSTimeInterval loadingInterval = -[_loadingStartDate timeIntervalSinceNow];
    if (loadingInterval < _minimumLoadingTime) {
        delay = _minimumLoadingTime - loadingInterval;
    }

    __typeof__(self) __weak wself = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __typeof__(self) const sself = wself;
        if (!sself) {
            return;
        }

        STPullToRefreshState const state = sself->_state;
        if (state == STPullToRefreshStateLoading) {
            [sself setState:STPullToRefreshStateLoaded animated:YES];
            [sself.scrollView flashScrollIndicators];
        }
    });
}

- (void)modifyScrollView:(UIScrollView *)scrollView forState:(STPullToRefreshState)state oldState:(STPullToRefreshState)oldState {
    return [self modifyScrollView:scrollView forState:state oldState:oldState animated:NO];
}
- (void)modifyScrollView:(UIScrollView *)scrollView forState:(STPullToRefreshState)state oldState:(STPullToRefreshState)oldState animated:(BOOL)animated {
    CGFloat verticalInsetOffset = 0;
    if (state == STPullToRefreshStateLoading && oldState != STPullToRefreshStateLoading) {
        verticalInsetOffset = self.verticalInsetOffsetWhileLoading;
    } else if (state != STPullToRefreshStateLoading && oldState == STPullToRefreshStateLoading) {
        verticalInsetOffset = _topContentInsetScrollAdjustment-self.verticalInsetOffsetWhileLoading;
        _topContentInsetScrollAdjustment = 0;
    }

    UIEdgeInsets edgeInsets = scrollView.contentInset;
    switch (_direction) {
        case STPullToRefreshDirectionUp:
            edgeInsets.top += verticalInsetOffset;
            break;
    }

    void(^animations)(void) = ^{
        // We require that the contentOffset be adjusted to compensate for the change in the contentInset
        // UIScrollView seems to do this for us *sometimes*, not not always
        // We detect when it hasn't been done, and apply the requisite compensation ourselves
        // (My theory is that UIScrollView will not do any adjustment if that adjustment will hide content that is already visible)
        
        CGPoint contentOffset = scrollView.contentOffset;
        [scrollView setContentInset:edgeInsets];
        if (contentOffset.y == scrollView.contentOffset.y) {
            contentOffset.y -= verticalInsetOffset;
            [scrollView setContentOffset:contentOffset];
        }
    };

    if (animated) {
        [UIView animateWithDuration:1./3. delay:0.0f options:UIViewAnimationOptionBeginFromCurrentState|UIViewAnimationOptionAllowUserInteraction animations:animations completion:nil];
    } else {
        animations();
    }
}

- (CGFloat)verticalInsetOffsetWhileLoading {
    UIView<STPullToRefreshHelperView> * const view = self.view;
    CGFloat const viewHeight = [view.class naturalHeight];
    CGFloat const verticalInset = viewHeight;
    switch (_direction) {
        case STPullToRefreshDirectionUp:
            return verticalInset;
    }
    return 0;
}

@end


@implementation STPullToRefreshHelperView {
@private
    STPullToRefreshState _state;
    UIActivityIndicatorView *_activityIndicatorView;
    UILabel *_pullInstructionsLabel;
    UILabel *_releaseInstructionsLabel;
}
+ (CGFloat)naturalHeight {
    return 40;
}
- (id)initWithFrame:(CGRect)frame {
    CGFloat const height = [self.class naturalHeight];
    if ((self = [super initWithFrame:CGRectMake(0, 0, 320, height)])) {
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

        void(^animations)(void) = ^{
            self->_activityIndicatorView.alpha = (state == STPullToRefreshStateLoading) ? 1 : 0;
            self->_pullInstructionsLabel.alpha = (state == STPullToRefreshStateIdle) ? 1 : 0;
            self->_releaseInstructionsLabel.alpha = (state == STPullToRefreshStateWaitingForRelease) ? 1 : 0;
        };

        void(^completion)(BOOL) = ^(BOOL finished) {
            if (self->_state != STPullToRefreshStateLoading) {
                [self->_activityIndicatorView stopAnimating];
            }
        };

        if (animated) {
            [UIView animateWithDuration:animated ? .2 : 0 delay:0 options:UIViewAnimationOptionAllowUserInteraction animations:animations completion:completion];
        } else {
            animations();
            completion(YES);
        }
    }
}

@end
