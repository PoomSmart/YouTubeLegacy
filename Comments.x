#import "TweakHeader.h"
#import <objc/runtime.h>
#import <YouTubeHeader/_ASDisplayView.h>
#import <YouTubeHeader/ELMCommandResolverProxy.h>
#import <YouTubeHeader/ELMNodeController.h>
#import <YouTubeHeader/GPBUnknownFields.h>
#import <YouTubeHeader/YTElementsCellController.h>
#import <YouTubeHeader/YTIElementRenderer.h>
#import <YouTubeHeader/YTInMemoryEntityStoreV2.h>
#import <YouTubeHeader/YTUnknownEntityModel.h>

static const int32_t kYTLCommentMenuCommandField = 10;
static const int32_t kYTLSerialCommandField = 170382688;
static const int32_t kYTLSerialCommandsField = 1;
static const int32_t kYTLShowActionSheetCommandField = 278463287;
static const void *kYTLArmedKey = &kYTLArmedKey;

static YTInMemoryEntityStoreV2 *(*InjectYTInMemoryEntityStore)(void);

@interface YTLCommentOverflowTapTarget : NSObject
- (void)handleTap:(UITapGestureRecognizer *)gesture;
@end

static GPBMessage *ytl_parse(NSData *data) {
    return data.length ? [%c(GPBMessage) parseFromData:data error:nil] : nil;
}

static void ytl_forEachLengthDelimited(GPBMessage *message, void (^block)(int32_t number, NSData *data)) {
    if (!message)
        return;
    if ([message respondsToSelector:@selector(unknownFields)]) {
        for (GPBUnknownField *field in message.unknownFields.sortedFields) {
            for (NSData *data in field.lengthDelimitedList)
                block(field.number, data);
        }
        return;
    }
    for (GPBUnknownField *field in [[%c(GPBUnknownFields) alloc] initFromMessage:message]) {
        if (field.type == GPBUnknownFieldTypeLengthDelimited)
            block(field.number, field.lengthDelimited);
    }
}

static NSData *ytl_fieldData(GPBMessage *message, int32_t fieldNumber) {
    __block NSData *found = nil;
    ytl_forEachLengthDelimited(message, ^(int32_t number, NSData *data) {
        if (!found && number == fieldNumber)
            found = data;
    });
    return found;
}

// The menu command runs an unsupported InnerTube command before ShowActionSheet, so only the latter is used
static NSData *ytl_sheetCommandForEntityKey(NSString *key) {
    YTUnknownEntityModel *entity = [InjectYTInMemoryEntityStore() entityForKey:key error:nil];
    if (![entity isKindOfClass:%c(YTUnknownEntityModel)])
        return nil;
    NSData *menuCommand = ytl_fieldData(ytl_parse(entity.data), kYTLCommentMenuCommandField);
    NSData *serialCommand = ytl_fieldData(ytl_parse(menuCommand), kYTLSerialCommandField);
    __block NSData *sheetCommand = nil;
    ytl_forEachLengthDelimited(ytl_parse(serialCommand), ^(int32_t number, NSData *command) {
        if (!sheetCommand && number == kYTLSerialCommandsField && ytl_fieldData(ytl_parse(command), kYTLShowActionSheetCommandField))
            sheetCommand = command;
    });
    return sheetCommand;
}

static NSData *ytl_findSheetCommand(NSData *data) {
    NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSString *decoded = string.stringByRemovingPercentEncoding;
    if (decoded && [[NSData alloc] initWithBase64EncodedString:decoded options:0])
        return ytl_sheetCommandForEntityKey(string);
    __block NSData *command = nil;
    ytl_forEachLengthDelimited(ytl_parse(data), ^(int32_t number, NSData *blob) {
        if (!command)
            command = ytl_findSheetCommand(blob);
    });
    return command;
}

static ELMNodeController *ytl_nodeControllerForView(UIView *view) {
    for (; view; view = view.superview) {
        if (![view isKindOfClass:%c(_ASDisplayView)])
            continue;
        id controller = [((_ASDisplayView *)view).keepalive_node controller];
        if ([controller isKindOfClass:%c(ELMNodeController)])
            return controller;
    }
    return nil;
}

static NSData *ytl_elementDataForController(ELMNodeController *controller) {
    for (id responder = controller.context.parentResponder; responder; responder = [responder respondsToSelector:@selector(parentResponder)] ? [responder parentResponder] : nil) {
        if ([responder isKindOfClass:%c(YTElementsCellController)]) {
            id entry = [(YTElementsCellController *)responder elementEntry];
            return [entry isKindOfClass:%c(YTIElementRenderer)] ? ((YTIElementRenderer *)entry).elementData : nil;
        }
    }
    return nil;
}

static BOOL ytl_isCommentOverflow(ELMNodeController *controller) {
    if (![controller.owningComponent.templateURI hasPrefix:@"overflow_button.eml"])
        return NO;
    for (id parent = controller.parent; [parent isKindOfClass:%c(ELMNodeController)]; parent = ((ELMNodeController *)parent).parent) {
        if ([((ELMNodeController *)parent).owningComponent.templateURI hasPrefix:@"comment.eml"])
            return YES;
    }
    return NO;
}

@implementation YTLCommentOverflowTapTarget

- (void)handleTap:(UITapGestureRecognizer *)gesture {
    ELMNodeController *controller = ytl_nodeControllerForView(gesture.view);
    NSData *command = ytl_findSheetCommand(ytl_elementDataForController(controller));
    if (!command)
        return;
    ELMCommandContext *commandContext = [[%c(ELMCommandContext) alloc] initWithContext:controller.context senderState:nil sender:controller recognizer:gesture];
    [[[%c(ELMCommandResolverProxy) alloc] initWithCommandContext:commandContext] resolve:command];
}

@end

%hook ELMNodeController

- (void)nodeDidLoad {
    %orig;
    if (!ytl_isCommentOverflow(self) || UIDevice.currentDevice.userInterfaceIdiom != UIUserInterfaceIdiomPhone)
        return;
    UIView *view = self.node.view;
    if (objc_getAssociatedObject(view, kYTLArmedKey))
        return;
    objc_setAssociatedObject(view, kYTLArmedKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    view.userInteractionEnabled = YES;
    static YTLCommentOverflowTapTarget *target;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        target = [YTLCommentOverflowTapTarget new];
    });
    [view addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:target action:@selector(handleTap:)]];
}

%end

%ctor {
    if (!shouldEnableTweak || %c(ELMPBBottomSheetListOptionModel) || !%c(ELMCommandResolverProxy))
        return;
    NSString *moduleFrameworkPath = [NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:@"Frameworks/Module_Framework.framework/Module_Framework"];
    MSImageRef image = MSGetImageByName(moduleFrameworkPath.UTF8String);
    InjectYTInMemoryEntityStore = image ? (YTInMemoryEntityStoreV2 *(*)(void))MSFindSymbol(image, "_InjectYTInMemoryEntityStore") : NULL;
    if (!InjectYTInMemoryEntityStore)
        return;
    %init;
}
