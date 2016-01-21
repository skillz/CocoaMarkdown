//
//  CMTextAttachment.m
//  CocoaMarkdown
//
//  Created by Krzysztof Rodak on 06/01/16.
//  Copyright © 2016 Indragie Karunaratne. All rights reserved.
//

#import "CMTextAttachment.h"

static CGFloat CM_IMAGE_WIDTH = 0.95;

@interface CMTextAttachment()

@property (strong, nonatomic) NSURL *url;

@end

@implementation CMTextAttachment

- (CGRect)attachmentBoundsForTextContainer:(NSTextContainer *)textContainer
                      proposedLineFragment:(CGRect)lineFrag
                             glyphPosition:(CGPoint)position
                            characterIndex:(NSUInteger)charIndex {

    CGFloat width = lineFrag.size.width;

    return [self scaleImageSizeToWidth:width];
}

- (CGRect)scaleImageSizeToWidth:(CGFloat)width {
    CGFloat scalingFactor = 1.0;
    CGSize imageSize = [self.image size];

    if (width < imageSize.width) {
        scalingFactor = (width * CM_IMAGE_WIDTH) / imageSize.width;
    }

    CGRect rect = CGRectMake(0, 0, imageSize.width * scalingFactor, imageSize.height * scalingFactor);
    return rect;
}

- (void)setupWithURL:(NSURL*)url {
    _url = url;
}


@end
