//
//  CMTextAttachmentManager.m
//  CocoaMarkdown
//
//  Created by Krzysztof Rodak on 06/01/16.
//  Copyright © 2016 Indragie Karunaratne. All rights reserved.
//

#import "CMImageAttachmentManager.h"
#import <SDWebImage/SDWebImageManager.h>
#import "CMTextAttachment.h"

@interface CMMarkdownImageWrapper()

@property (nonatomic, strong, nonnull) NSURL *imageURL;
@property (nonatomic, strong, nullable) NSURL *url;
@property (nonatomic, strong, nullable) NSString *title;
@property (nonatomic, assign) NSRange range;
@property (nonatomic, strong, nullable) NSTextAttachment *attachment;

@end

@implementation CMMarkdownImageWrapper

+ (instancetype)imageWrapperWithImageURL:(nonnull NSURL*)imageURL url:(nullable NSURL*)url title:(nullable NSString*)title range:(NSRange)range {
    CMMarkdownImageWrapper *wrapper = [CMMarkdownImageWrapper new];
    wrapper.imageURL    = imageURL;
    wrapper.url         = url;
    wrapper.title       = title;
    wrapper.range       = range;
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

    id <SDWebImageOperation> operation = [[SDWebImageManager sharedManager]
                                          downloadImageWithURL:imageWrapper.imageURL
                                          options:SDWebImageAvoidAutoSetImage | SDWebImageContinueInBackground
                                          progress:nil
                                          completed:
                                          ^(UIImage *image, NSError *error, SDImageCacheType cacheType, BOOL finished, NSURL *imageURL) {
                                              if(finished && !error) {
                                                  CMTextAttachment *attachment  = [CMTextAttachment new];
                                                  attachment.image              = image;
                                                  attachment.url                = imageWrapper.url;
                                                  imageWrapper.attachment       = attachment;

                                                  completionBlock(imageWrapper);
                                              }
                                          }];
    [self.attachments addObject:imageWrapper];
    [self.networkQueue addObject:operation];
}

- (void)dealloc {
    for(id <SDWebImageOperation> operation in self.networkQueue) {
        [operation cancel];
    }
}


@end
