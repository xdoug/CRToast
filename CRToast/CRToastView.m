//
//  CRToastView.m
//  CRToastDemo
//
//  Created by Daniel on 12/19/14.
//  Copyright (c) 2014 Collin Ruffenach. All rights reserved.
//

#import "CRToastView.h"
#import "CRToast.h"
#import "CRToastLayoutHelpers.h"

@interface CRToastView ()
@end

static CGFloat const kCRStatusBarViewNoImageLeftContentInset = 10;
static CGFloat const kCRStatusBarViewNoImageRightContentInset = 10;

// UIApplication's statusBarFrame will return a height for the status bar that includes
// a 5 pixel vertical padding. This frame height is inappropriate to use when centering content
// vertically under the status bar. This adjustment is uesd to correct the frame height when centering
// content under the status bar.

static CGFloat const CRStatusBarViewUnderStatusBarYOffsetAdjustment = -5;

static CGFloat CRImageViewFrameXOffsetForAlignment(CRToastAccessoryViewAlignment alignment, CGSize contentSize) {
    CGFloat imageSize = contentSize.height;
    CGFloat xOffset = 0;

    if (alignment == CRToastAccessoryViewAlignmentLeft) {
        xOffset = 0;
    } else if (alignment == CRToastAccessoryViewAlignmentCenter) {
        // Calculate mid point of contentSize, then offset for x for full image width
        // that way center of image will be center of content view
        xOffset = (contentSize.width / 2) - (imageSize / 2);
    } else if (alignment == CRToastAccessoryViewAlignmentRight) {
        xOffset = contentSize.width - imageSize;
    }
    
    return xOffset;
}

static CGFloat CRContentXOffsetForViewAlignmentAndWidth(CRToastAccessoryViewAlignment alignment, CGFloat width) {
    return (width == 0 || alignment != CRToastAccessoryViewAlignmentLeft) ?
    kCRStatusBarViewNoImageLeftContentInset :
    width + kCRStatusBarViewNoImageLeftContentInset;
}

static CGFloat CRToastWidthOfViewWithAlignment(CGFloat height, BOOL showing, CRToastAccessoryViewAlignment alignment) {
    return (!showing || alignment == CRToastAccessoryViewAlignmentCenter) ?
    0 :
    height;
}

CGFloat CRContentWidthForAccessoryViewsWithAlignments(CGFloat fullContentWidth, CGFloat fullContentHeight, BOOL showingImage, CRToastAccessoryViewAlignment imageAlignment, BOOL showingActivityIndicator, CRToastAccessoryViewAlignment activityIndicatorAlignment) {
    CGFloat width = fullContentWidth;
    
    width -= CRToastWidthOfViewWithAlignment(fullContentHeight, showingImage, imageAlignment);
    width -= CRToastWidthOfViewWithAlignment(fullContentHeight, showingActivityIndicator, activityIndicatorAlignment);
    
    if (imageAlignment == activityIndicatorAlignment && showingActivityIndicator && showingImage) {
        width += fullContentWidth;
    }
    
    if (!showingImage && !showingActivityIndicator) {
        width -= (kCRStatusBarViewNoImageLeftContentInset + kCRStatusBarViewNoImageRightContentInset);
    }
    
    return width;
}

static CGFloat CRCenterXForActivityIndicatorWithAlignment(CRToastAccessoryViewAlignment alignment, CGFloat viewWidth, CGFloat contentWidth) {
    CGFloat center = 0;
    CGFloat offset = viewWidth / 2;
    
    switch (alignment) {
        case CRToastAccessoryViewAlignmentLeft:
            center = offset; break;
        case CRToastAccessoryViewAlignmentCenter:
            center = (contentWidth / 2); break;
        case CRToastAccessoryViewAlignmentRight:
            center = contentWidth - offset; break;
    }
    
    return center;
}

@implementation CRToastView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.userInteractionEnabled = YES;
        self.accessibilityLabel = NSStringFromClass([self class]);
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        
        UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectZero];
        imageView.userInteractionEnabled = NO;
        imageView.contentMode = UIViewContentModeCenter;
        [self addSubview:imageView];
        self.imageView = imageView;
        
        UIActivityIndicatorView *activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
        activityIndicator.userInteractionEnabled = NO;
        [self addSubview:activityIndicator];
        self.activityIndicator = activityIndicator;
        
        UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
        label.userInteractionEnabled = NO;
        [self addSubview:label];
        self.label = label;
        
        UILabel *subtitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        subtitleLabel.userInteractionEnabled = NO;
        [self addSubview:subtitleLabel];
        self.subtitleLabel = subtitleLabel;
        
        self.isAccessibilityElement = YES;
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGRect contentFrame = self.bounds;
    CGSize imageSize = self.imageView.image.size;
    
    CGFloat statusBarYOffset = self.toast.displayUnderStatusBar ? (CRGetStatusBarHeight()+CRStatusBarViewUnderStatusBarYOffsetAdjustment) : 0;
    contentFrame.size.height = CGRectGetHeight(contentFrame) - statusBarYOffset;
    
    self.backgroundView.frame = self.bounds;
    
    CGFloat imageXOffset = CRImageViewFrameXOffsetForAlignment(self.toast.imageAlignment, contentFrame.size);
    self.imageView.frame = CGRectMake(imageXOffset,
                                      statusBarYOffset,
                                      imageSize.width == 0 ?
                                      0 :
                                      CGRectGetHeight(contentFrame),
                                      imageSize.height == 0 ?
                                      0 :
                                      CGRectGetHeight(contentFrame));
    
    CGFloat imageWidth = imageSize.width == 0 ? 0 : CGRectGetMaxX(_imageView.frame);
    CGFloat x = CRContentXOffsetForViewAlignmentAndWidth(self.toast.imageAlignment, imageWidth);
    
    if (self.toast.showActivityIndicator) {
        CGFloat centerX = CRCenterXForActivityIndicatorWithAlignment(self.toast.activityViewAlignment, CGRectGetHeight(contentFrame), CGRectGetWidth(contentFrame));
        self.activityIndicator.center = CGPointMake(centerX,
                                     CGRectGetMidY(contentFrame) + statusBarYOffset);
        
        [self.activityIndicator startAnimating];
        x = MAX(CRContentXOffsetForViewAlignmentAndWidth(self.toast.activityViewAlignment, CGRectGetHeight(contentFrame)), x);

        [self bringSubviewToFront:self.activityIndicator];
    }
    
    BOOL showingImage = imageSize.width > 0;
    
    CGFloat width = CRContentWidthForAccessoryViewsWithAlignments(CGRectGetWidth(contentFrame),
                                                                  CGRectGetHeight(contentFrame),
                                                                  showingImage,
                                                                  self.toast.imageAlignment,
                                                                  self.toast.showActivityIndicator,
                                                                  self.toast.activityViewAlignment);
    
    if (self.toast.subtitleText == nil) {
        self.label.frame = CGRectMake(x,
                                      statusBarYOffset,
                                      width,
                                      CGRectGetHeight(contentFrame));
    } else {
        CGFloat height = MIN([self.toast.text boundingRectWithSize:CGSizeMake(width, MAXFLOAT)
                                                           options:NSStringDrawingUsesLineFragmentOrigin
                                                        attributes:@{NSFontAttributeName : self.toast.font}
                                                           context:nil].size.height,
                             CGRectGetHeight(contentFrame));
        CGFloat subtitleHeight = [self.toast.subtitleText boundingRectWithSize:CGSizeMake(width, MAXFLOAT)
                                                                       options:NSStringDrawingUsesLineFragmentOrigin
                                                                    attributes:@{NSFontAttributeName : self.toast.subtitleFont }
                                                                       context:nil].size.height;
        if ((CGRectGetHeight(contentFrame) - (height + subtitleHeight)) < 5) {
            subtitleHeight = (CGRectGetHeight(contentFrame) - (height))-10;
        }
        CGFloat offset = (CGRectGetHeight(contentFrame) - (height + subtitleHeight))/2;
        
        self.label.frame = CGRectMake(x,
                                      offset+statusBarYOffset,
                                      CGRectGetWidth(contentFrame)-x-kCRStatusBarViewNoImageRightContentInset,
                                      height);
        
        
        self.subtitleLabel.frame = CGRectMake(x,
                                              height+offset+statusBarYOffset,
                                              CGRectGetWidth(contentFrame)-x-kCRStatusBarViewNoImageRightContentInset,
                                              subtitleHeight);
    }
}

#pragma mark - Overrides

- (void)setToast:(CRToast *)toast {
    _toast = toast;
    _label.text = toast.text;
    _label.font = toast.font;
    _label.textColor = toast.textColor;
    _label.textAlignment = toast.textAlignment;
    _label.numberOfLines = toast.textMaxNumberOfLines;
    _label.shadowOffset = toast.textShadowOffset;
    _label.shadowColor = toast.textShadowColor;
    if (toast.subtitleText != nil) {
        _subtitleLabel.text = toast.subtitleText;
        _subtitleLabel.font = toast.subtitleFont;
        _subtitleLabel.textColor = toast.subtitleTextColor;
        _subtitleLabel.textAlignment = toast.subtitleTextAlignment;
        _subtitleLabel.numberOfLines = toast.subtitleTextMaxNumberOfLines;
        _subtitleLabel.shadowOffset = toast.subtitleTextShadowOffset;
        _subtitleLabel.shadowColor = toast.subtitleTextShadowColor;
    }
    
    if (!CGSizeEqualToSize(self.toast.imageSize, CGSizeZero)) {
        UIGraphicsBeginImageContextWithOptions(self.toast.imageSize, NO, 0.0);
        [toast.image drawInRect:CGRectMake(0, 0, self.toast.imageSize.width, self.toast.imageSize.height)];
        UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
        _imageView.image = newImage;
        UIGraphicsEndImageContext();
    } else {
        _imageView.image = toast.image;
    }
    _imageView.contentMode = toast.imageContentMode;
    
    if (toast.imageCornerRadius > 0) {
        // Begin a new image that will be the new image with the rounded corners
        // (here with the size of an UIImageView)
        UIGraphicsBeginImageContextWithOptions(self.toast.imageSize, NO, 1.0);
        
        CGRect imageRect = CGRectMake(0, 0, self.toast.imageSize.width, self.toast.imageSize.height);
        
        // Add a clip before drawing anything, in the shape of an rounded rect
        [[UIBezierPath bezierPathWithRoundedRect:imageRect
                                    cornerRadius:toast.imageCornerRadius] addClip];
        // Draw your image
        [_imageView.image drawInRect:imageRect];
        
        // Get the image, here setting the UIImageView image
        _imageView.image = UIGraphicsGetImageFromCurrentImageContext();
        
        // Lets forget about that we were drawing
        UIGraphicsEndImageContext();
    }
    
    _imageView.contentMode = toast.imageContentMode;
    
    _activityIndicator.activityIndicatorViewStyle = toast.activityIndicatorViewStyle;
    self.backgroundColor = toast.backgroundColor;
    
    if (toast.backgroundView) {
        _backgroundView = toast.backgroundView;
        if (!_backgroundView.superview) {
            [self insertSubview:_backgroundView atIndex:0];
        }
    }
}

@end
