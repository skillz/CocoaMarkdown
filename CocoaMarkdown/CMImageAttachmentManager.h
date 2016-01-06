//
//  CMTextAttachmentManager.h
//  CocoaMarkdown
//
//  Created by Krzysztof Rodak on 06/01/16.
//  Copyright © 2016 Indragie Karunaratne. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface CMMarkdownImageWrapper : NSObject

@property (nonatomic, readonly, nonnull) NSURL *url;
@property (nonatomic, readonly, nullable) NSString *title;
@property (nonatomic, readonly) NSRange range;
@property (nonatomic, readonly, nullable) NSTextAttachment *attachment;

+ (instancetype)imageWrapperWithURL:(nonnull NSURL*)url title:(nullable NSString*)title range:(NSRange)range;

@end

@interface CMImageAttachmentManager : NSObject

- (void)addMarkdownImageToDownload:(nonnull CMMarkdownImageWrapper*)imageWrapper
                   completionBlock:(nonnull void (^) (CMMarkdownImageWrapper* _Nonnull updateImage))completionBlock;


@end
