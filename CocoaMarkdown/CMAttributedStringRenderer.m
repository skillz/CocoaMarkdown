//
//  CMAttributedStringRenderer.m
//  CocoaMarkdown
//
//  Created by Indragie on 1/14/15.
//  Copyright (c) 2015 Indragie Karunaratne. All rights reserved.
//

#import "CMAttributedStringRenderer.h"
#import "CMAttributeRun.h"
#import "CMCascadingAttributeStack.h"
#import "CMStack.h"
#import "CMHTMLElementTransformer.h"
#import "CMHTMLElement.h"
#import "CMHTMLUtilities.h"
#import "CMTextAttributes.h"
#import "CMNode.h"
#import "CMParser.h"
#import "CMImageAttachmentManager.h"
#import "Ono.h"
#import <UIKit/UIKit.h>

@interface CMAttributedStringRenderer () <CMParserDelegate>

@property (nonatomic, strong, nonnull) CMDocument *document;
@property (nonatomic, strong) CMTextAttributes *attributes;
@property (nonatomic, strong) CMStack *HTMLStack;
@property (nonatomic, strong) CMCascadingAttributeStack *attributeStack;
@property (nonatomic, strong) NSMutableDictionary *tagNameToTransformerMapping;
@property (nonatomic, strong) NSMutableAttributedString *buffer;
@property (nonatomic, strong) NSAttributedString *attributedString;

@property (nonatomic, strong) CMImageAttachmentManager *attachmentsManager;

@property (nonatomic, weak) UITextView *textView;

@end

@implementation CMAttributedStringRenderer

#pragma mark - Initialization

- (instancetype)initWithDocument:(CMDocument *)document attributes:(CMTextAttributes *)attributes
{
    if ((self = [super init])) {
        _document = document;
        _attributes = attributes;
        _tagNameToTransformerMapping = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void)registerHTMLElementTransformer:(id<CMHTMLElementTransformer>)transformer
{
    NSParameterAssert(transformer);
    self.tagNameToTransformerMapping[[transformer.class tagName]] = transformer;
}

#pragma mark - Rendering

- (void)prerendering {
    self.attributeStack = [[CMCascadingAttributeStack alloc] init];
    self.HTMLStack = [[CMStack alloc] init];
    self.buffer = [[NSMutableAttributedString alloc] init];
    self.attachmentsManager = [CMImageAttachmentManager new];
}

- (NSAttributedString *)render
{
    if (self.attributedString == nil) {
        [self prerendering];
        CMParser *parser = [[CMParser alloc] initWithDocument:self.document delegate:self];
        [parser parse];
        
        self.attributedString = [self.buffer copy];
        self.attributeStack = nil;
        self.HTMLStack = nil;
        self.buffer = nil;
    }
    
    return self.attributedString;
}

- (void)renderAndSyncWithTextView:(UITextView *)textView {
    self.textView = textView;
    [self prerendering];
    CMParser *parser = [[CMParser alloc] initWithDocument:self.document delegate:self];
    [parser parse];
    self.attributedString = [self.buffer copy];
    self.attributeStack = nil;
    self.HTMLStack = nil;

    textView.attributedText = self.attributedString;

}

#pragma mark - CMParserDelegate

- (void)parserDidStartDocument:(CMParser *)parser
{
    [self.attributeStack push:CMDefaultAttributeRun(self.attributes.textAttributes)];
}

- (void)parserDidEndDocument:(CMParser *)parser
{
    CFStringTrimWhitespace((__bridge CFMutableStringRef)_buffer.mutableString);
}

- (void)parser:(CMParser *)parser foundText:(NSString *)text
{
    CMHTMLElement *element = [self.HTMLStack peek];
    if (element != nil) {
        [element.buffer appendString:text];
    } else {
        [self appendString:text];
    }
}

- (void)parser:(CMParser *)parser didStartHeaderWithLevel:(NSInteger)level
{
    [self.attributeStack push:CMDefaultAttributeRun([self.attributes attributesForHeaderLevel:level])];
}

- (void)parser:(CMParser *)parser didEndHeaderWithLevel:(NSInteger)level
{
    [self appendString:@"\n"];
    [self.attributeStack pop];
}

- (void)parserDidStartParagraph:(CMParser *)parser
{
    [self appendLineBreakIfNotTightForNode:parser.currentNode];
}

- (void)parserDidEndParagraph:(CMParser *)parser
{
    [self appendLineBreakIfNotTightForNode:parser.currentNode];
}

- (void)parserDidStartEmphasis:(CMParser *)parser
{
    BOOL hasExplicitFont = self.attributes.emphasisAttributes[NSFontAttributeName] != nil;
    [self.attributeStack push:CMTraitAttributeRun(self.attributes.emphasisAttributes, hasExplicitFont ? 0 : CMFontTraitItalic)];
}

- (void)parserDidEndEmphasis:(CMParser *)parser
{
    [self.attributeStack pop];
}

- (void)parserDidStartStrong:(CMParser *)parser
{
    BOOL hasExplicitFont = self.attributes.strongAttributes[NSFontAttributeName] != nil;
    [self.attributeStack push:CMTraitAttributeRun(self.attributes.strongAttributes, hasExplicitFont ? 0 : CMFontTraitBold)];
}

- (void)parserDidEndStrong:(CMParser *)parse
{
    [self.attributeStack pop];
}

- (void)parser:(CMParser *)parser didStartLinkWithURL:(NSURL *)URL title:(NSString *)title
{
    NSMutableDictionary *baseAttributes = [NSMutableDictionary dictionaryWithObjectsAndKeys:URL, NSLinkAttributeName, nil];
#if !TARGET_OS_IPHONE
    if (title != nil) {
        baseAttributes[NSToolTipAttributeName] = title;
    }
#endif
    [baseAttributes addEntriesFromDictionary:self.attributes.linkAttributes];
    [self.attributeStack push:CMDefaultAttributeRun(baseAttributes)];
}

- (void)parser:(CMParser *)parser didEndLinkWithURL:(NSURL *)URL title:(NSString *)title
{
    [self.attributeStack pop];
}

- (void)parser:(CMParser *)parser foundHTML:(NSString *)HTML
{
    NSString *tagName = CMTagNameFromHTMLTag(HTML);
    if (tagName.length != 0) {
        CMHTMLElement *element = [self newHTMLElementForTagName:tagName HTML:HTML];
        if (element != nil) {
            [self appendHTMLElement:element];
        }
    }
}

- (void)parser:(CMParser *)parser foundInlineHTML:(NSString *)HTML
{
    NSString *tagName = CMTagNameFromHTMLTag(HTML);
    if (tagName.length != 0) {
        CMHTMLElement *element = nil;
        if (CMIsHTMLVoidTagName(tagName)) {
            element = [self newHTMLElementForTagName:tagName HTML:HTML];
            if (element != nil) {
                [self appendHTMLElement:element];
            }
        } else if (CMIsHTMLClosingTag(HTML)) {
            if ((element = [self.HTMLStack pop])) {
                NSAssert([element.tagName isEqualToString:tagName], @"Closing tag does not match opening tag");
                [element.buffer appendString:HTML];
                [self appendHTMLElement:element];
            }
        } else if (CMIsHTMLTag(HTML)) {
            element = [self newHTMLElementForTagName:tagName HTML:HTML];
            if (element != nil) {
                [self.HTMLStack push:element];
            }
        }
    }
}

- (void)parser:(CMParser *)parser foundCodeBlock:(NSString *)code info:(NSString *)info
{
    [self.attributeStack push:CMDefaultAttributeRun(self.attributes.codeBlockAttributes)];
    [self appendString:[NSString stringWithFormat:@"\n\n%@\n\n", code]];
    [self.attributeStack pop];
}

- (void)parser:(CMParser *)parser foundInlineCode:(NSString *)code
{
    [self.attributeStack push:CMDefaultAttributeRun(self.attributes.inlineCodeAttributes)];
    [self appendString:code];
    [self.attributeStack pop];
}

- (void)parserFoundSoftBreak:(CMParser *)parser
{
    [self appendString:@"\n"];
}

- (void)parserFoundLineBreak:(CMParser *)parser
{
    [self appendString:@"\n"];
}

- (void)parserDidStartBlockQuote:(CMParser *)parser
{
    [self.attributeStack push:CMDefaultAttributeRun(self.attributes.blockQuoteAttributes)];
}

- (void)parserDidEndBlockQuote:(CMParser *)parser
{
    [self.attributeStack pop];
}

- (void)parser:(CMParser *)parser didStartUnorderedListWithTightness:(BOOL)tight
{
    [self.attributeStack push:CMDefaultAttributeRun(self.attributes.unorderedListAttributes)];
    [self appendString:@"\n"];
}

- (void)parser:(CMParser *)parser didEndUnorderedListWithTightness:(BOOL)tight
{
    [self.attributeStack pop];
}

- (void)parser:(CMParser *)parser didStartOrderedListWithStartingNumber:(NSInteger)num tight:(BOOL)tight
{
    [self.attributeStack push:CMOrderedListAttributeRun(self.attributes.orderedListAttributes, num)];
    [self appendString:@"\n"];
}

- (void)parser:(CMParser *)parser didEndOrderedListWithStartingNumber:(NSInteger)num tight:(BOOL)tight
{
    [self.attributeStack pop];
}

- (void)parserDidStartListItem:(CMParser *)parser
{
    CMNode *node = parser.currentNode.parent;
    switch (node.listType) {
        case CMListTypeNone:
            NSAssert(NO, @"Parent node of list item must be a list");
            break;
        case CMListTypeUnordered: {
            [self appendString:@"\u2022 "];
            [self.attributeStack push:CMDefaultAttributeRun(self.attributes.unorderedListItemAttributes)];
            break;
        }
        case CMListTypeOrdered: {
            CMAttributeRun *parentRun = [self.attributeStack peek];
            [self appendString:[NSString stringWithFormat:@"%ld. ", (long)parentRun.orderedListItemNumber]];
            parentRun.orderedListItemNumber++;
            [self.attributeStack push:CMDefaultAttributeRun(self.attributes.orderedListItemAttributes)];
            break;
        }
        default:
            break;
    }
}

- (void)parserDidEndListItem:(CMParser *)parser
{
    [self appendString:@"\n"];
    [self.attributeStack pop];
}


- (void)parser:(CMParser *)parser didStartImageWithURL:(NSURL *)URL title:(NSString *)title {

    if(!self.textView) {
        return;
    }

    [self appendString:@"\n"];

    NSTextAttachment *attachment    = [NSTextAttachment new];
    attachment.image                = [UIImage imageNamed:@"placeholder@2x.png"];
    NSAttributedString *string      = [NSAttributedString attributedStringWithAttachment:attachment];
    NSRange range                   = NSMakeRange(self.buffer.mutableString.length, 1);

    [self.buffer appendAttributedString:string];

    __weak typeof(self) weakSelf = self;

    [self.attachmentsManager addMarkdownImageToDownload: [CMMarkdownImageWrapper imageWrapperWithURL:URL title:title range:range]
                                        completionBlock:^(CMMarkdownImageWrapper * _Nonnull updatedImage) {
                                            NSAttributedString *updatedString = [NSAttributedString attributedStringWithAttachment:updatedImage.attachment];
                                            [weakSelf.buffer replaceCharactersInRange:updatedImage.range withAttributedString:updatedString];
                                            weakSelf.textView.attributedText = weakSelf.buffer.copy;

    }];

}

- (void)parser:(CMParser *)parser didEndImageWithURL:(NSURL *)URL title:(NSString *)title {
    [self appendString:@"\n"];
}

#pragma mark - Private

- (CMHTMLElement *)newHTMLElementForTagName:(NSString *)tagName HTML:(NSString *)HTML
{
    NSParameterAssert(tagName);
    id<CMHTMLElementTransformer> transformer = self.tagNameToTransformerMapping[tagName];
    if (transformer != nil) {
        CMHTMLElement *element = [[CMHTMLElement alloc] initWithTransformer:transformer];
        [element.buffer appendString:HTML];
        return element;
    }
    return nil;
}

- (void)appendLineBreakIfNotTightForNode:(CMNode *)node
{
    CMNode *grandparent = node.parent.parent;
    if (!grandparent.listTight) {
        [self appendString:@"\n"];
    }
}

- (void)appendString:(NSString *)string
{
    NSAttributedString *attrString = [[NSAttributedString alloc] initWithString:string attributes:self.attributeStack.cascadedAttributes];
    [self.buffer appendAttributedString:attrString];
}

- (void)appendHTMLElement:(CMHTMLElement *)element
{
    NSError *error = nil;
    ONOXMLDocument *document = [ONOXMLDocument HTMLDocumentWithString:element.buffer encoding:NSUTF8StringEncoding error:&error];
    if (document == nil) {
        NSLog(@"Error creating HTML document for buffer \"%@\": %@", element.buffer, error);
        return;
    }
    
    ONOXMLElement *XMLElement = document.rootElement[0][0];
    NSDictionary *attributes = self.attributeStack.cascadedAttributes;
    NSAttributedString *attrString = [element.transformer attributedStringForElement:XMLElement attributes:attributes];
    
    if (attrString != nil) {
        CMHTMLElement *parentElement = [self.HTMLStack peek];
        if (parentElement == nil) {
            [self.buffer appendAttributedString:attrString];
        } else {
            [parentElement.buffer appendString:attrString.string];
        }
    }
}

@end
