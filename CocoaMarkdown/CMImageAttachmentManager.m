//
//  CMTextAttachmentManager.m
//  CocoaMarkdown
//
//  Created by Krzysztof Rodak on 06/01/16.
//  Copyright © 2016 Indragie Karunaratne. All rights reserved.
//

#import "CMImageAttachmentManager.h"
#import <SDWebImage/SDWebImageManager.h>

@interface CMMarkdownImageWrapper()

@property (nonatomic, strong, nonnull) NSURL *url;
@property (nonatomic, strong, nullable) NSString *title;
@property (nonatomic, assign) NSRange range;
@property (nonatomic, strong, nullable) NSTextAttachment *attachment;

@end

@implementation CMMarkdownImageWrapper

+ (instancetype)imageWrapperWithURL:(nonnull NSURL*)url title:(nullable NSString*)title range:(NSRange)range {
    CMMarkdownImageWrapper *wrapper = [CMMarkdownImageWrapper new];
    wrapper.url = url;
    wrapper.title = title;
    wrapper.range = range;
    return wrapper;
}

@end

@interface CMImageAttachmentManager()

@property (nonatomic, strong, nonnull) NSMutableArray<CMMarkdownImageWrapper*> *attachments;
@property (nonatomic, strong, nonnull) NSMutableArray<id<SDWebImageOperation>> *networkQueue;

@end

@implementation CMImageAttachmentManager

- (id)init {
    if (self = [super init]) {
        _attachments = [NSMutableArray new];
    }
    return self;
}

- (void)addMarkdownImageToDownload:(CMMarkdownImageWrapper*)imageWrapper
                   completionBlock:(void(^)(CMMarkdownImageWrapper* updateImage))completionBlock {

    [self.attachments addObject:imageWrapper];
    id <SDWebImageOperation> operation = [[SDWebImageManager sharedManager]
                                          downloadImageWithURL:imageWrapper.url
                                          options:SDWebImageAvoidAutoSetImage | SDWebImageContinueInBackground
                                          progress:nil
                                          completed:
                                          ^(UIImage *image, NSError *error, SDImageCacheType cacheType, BOOL finished, NSURL *imageURL) {
                                              if(finished && !error) {
                                                  NSTextAttachment *attachment = [NSTextAttachment new];
                                                  attachment.image = image;
                                                  imageWrapper.attachment = attachment;
                                                  completionBlock(imageWrapper);
                                              }
                                          }];
    [self.networkQueue addObject:operation];

}

- (void)dealloc {
    for(id <SDWebImageOperation> operation in self.networkQueue) {
        [operation cancel];
    }
}


@end
