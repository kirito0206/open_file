#import "./include/open_file_ios/OpenFilePlugin.h"

@interface OpenFilePlugin ()<UIDocumentInteractionControllerDelegate>
@end

static NSString *const CHANNEL_NAME = @"open_file";

@implementation OpenFilePlugin{
    FlutterResult _result;
    UIViewController *_viewController;
    UIDocumentInteractionController *_documentController;
    UIDocumentInteractionController *_interactionController;
}

+ (UIWindow *)mainWindow {
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene* windowScene in [UIApplication sharedApplication].connectedScenes) {
            if (windowScene.activationState == UISceneActivationStateForegroundActive) {
                return windowScene.windows.firstObject;
            }
        }
        // If a window has not been returned by now, the first scene's window is returned (regardless of activationState).
        UIWindowScene *windowScene = (UIWindowScene *)[[UIApplication sharedApplication].connectedScenes allObjects].firstObject;
        return windowScene.windows.firstObject;
    } else {
        return [[[UIApplication sharedApplication] delegate] window];
    }
}


+ (UIViewController *)findRootViewController {
    return [self mainWindow].rootViewController;
}


+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    FlutterMethodChannel* channel = [FlutterMethodChannel
            methodChannelWithName:CHANNEL_NAME
                  binaryMessenger:[registrar messenger]];
    // UIViewController *viewController =
    //[UIApplication sharedApplication].delegate.window.rootViewController;
    UIViewController *viewController = [self findRootViewController];
    if (viewController) {
        OpenFilePlugin* instance = [[OpenFilePlugin alloc] initWithViewController:viewController];
        [registrar addMethodCallDelegate:instance channel:channel];
    }
}

- (instancetype)initWithViewController:(UIViewController *)viewController {
    self = [super init];
    if (self) {
        _viewController = viewController;
    }
    return self;
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    if ([@"open_file" isEqualToString:call.method]) {
        _result = result;
        NSString *filePath = call.arguments[@"file_path"];
        if(filePath==nil){
            NSDictionary * dict = @{@"message":@"the file path cannot be null", @"type":@-4};
            NSData * jsonData = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:nil];
            NSString * json = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
            result(json);
            return;
        }
        NSFileManager *fileManager=[NSFileManager defaultManager];
        BOOL fileExist=[fileManager fileExistsAtPath:filePath];
        if(fileExist){
            NSURL *fileURL = [NSURL fileURLWithPath:filePath];
            _documentController = [UIDocumentInteractionController interactionControllerWithURL:fileURL];
            _documentController.delegate = self;
            BOOL isAppOpen = [call.arguments[@"isIOSAppOpen"] boolValue];
            @try {
                if (isAppOpen) {
                    [self openFileWithUIActivityViewController:fileURL];
                }else{
                    BOOL previewSucceeded = [_documentController presentPreviewAnimated:YES];
                    if (@available(iOS 18.0, *)) {
                        sleep(1);
                    }
                    if(!previewSucceeded){
                        //                    [_documentController presentOpenInMenuFromRect:CGRectMake(500,20,100,100) inView:[UIApplication sharedApplication].delegate.window.rootViewController.view animated:YES];

                        [self openFileWithUIActivityViewController:fileURL];
                    }
                }

            }@catch (NSException *exception) {
                NSString * json = [self getJson:@"File opened incorrectly。" type:@-4];
                result(json);
            }
        }else{
            NSString * json = [self getJson:@"the file does not exist。" type:@-2];
            result(json);
        }
    } else {
        result(FlutterMethodNotImplemented);
    }
}

- (void)openFileWithUIActivityViewController:(NSURL *)fileURL{
    UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:@[fileURL] applicationActivities:nil];

    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        activityViewController.popoverPresentationController.sourceView = _viewController.view;
        activityViewController.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(_viewController.view.bounds), CGRectGetMidY(_viewController.view.bounds), 0, 0);
        activityViewController.popoverPresentationController.permittedArrowDirections = UIPopoverArrowDirectionAny;
    }

    [_viewController presentViewController:activityViewController animated:YES completion:^{ [self doneEnd];}];
}

- (void)documentInteractionControllerDidEndPreview:(UIDocumentInteractionController *)controller {
    [self doneEnd];
}

- (void)documentInteractionControllerDidDismissOpenInMenu:(UIDocumentInteractionController *)controller {
    [self doneEnd];
}

- (UIViewController *)documentInteractionControllerViewControllerForPreview:(UIDocumentInteractionController *)controller {
    return [UIApplication sharedApplication].delegate.window.rootViewController;
}

- (BOOL) isBlankString:(NSString *)string {
    if (string == nil || string == NULL) {
        return YES;
    }
    if ([string isKindOfClass:[NSNull class]]) {
        return YES;
    }
    if ([[string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] length]==0){
        return YES;
    }
    return NO;
}

- (NSString*) getJson:(NSString *)message type:(NSNumber*)type {
    NSDictionary * dict = @{@"message":message, @"type":type};
    NSData * jsonData = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:nil];
    NSString * json = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];

    return json;
}

- (void)doneEnd {
    NSString * json = [self getJson:@"done" type:@0];
    _result(json);
}

-(void) setControllerUTI:(NSString*) filePath __attribute__(( deprecated ( "Now it's automatic" ))){
//    NSURL *resourceToOpen = [NSURL fileURLWithPath:filePath];
    NSString *exestr = [[filePath pathExtension] lowercaseString];
    if([exestr isEqualToString:@"rtf"]){
        _documentController.UTI=@"public.rtf";
    }else if([exestr isEqualToString:@"txt"]){
        _documentController.UTI=@"public.plain-text";
    }else if([exestr isEqualToString:@"html"]||[exestr isEqualToString:@"htm"]){
        _documentController.UTI=@"public.html";
    }else if([exestr isEqualToString:@"xml"]){
        _documentController.UTI=@"public.xml";
    }else if([exestr isEqualToString:@"tar"]){
        _documentController.UTI=@"public.tar-archive";
    }else if([exestr isEqualToString:@"gz"]||[exestr isEqualToString:@"gzip"]){
        _documentController.UTI=@"org.gnu.gnu-zip-archive";
    }else if([exestr isEqualToString:@"tgz"]){
        _documentController.UTI=@"org.gnu.gnu-zip-tar-archive";
    }else if([exestr isEqualToString:@"jpg"]||
             [exestr isEqualToString:@"jpeg"]){
        _documentController.UTI=@"public.jpeg";
    }else if([exestr isEqualToString:@"png"]){
        _documentController.UTI=@"public.png";
    }else if([exestr isEqualToString:@"avi"]){
        _documentController.UTI=@"public.avi";
    }else if([exestr isEqualToString:@"mpg"]||
             [exestr isEqualToString:@"mpeg"]){
        _documentController.UTI=@"public.mpeg";
    }else if([exestr isEqualToString:@"mp4"]){
        _documentController.UTI=@"public.mpeg-4";
    }else if([exestr isEqualToString:@"3gpp"]||
             [exestr isEqualToString:@"3gp"]){
        _documentController.UTI=@"public.3gpp";
    }else if([exestr isEqualToString:@"mp3"]){
        _documentController.UTI=@"public.mp3";
    }else if([exestr isEqualToString:@"zip"]){
        _documentController.UTI=@"com.pkware.zip-archive";
    }else if([exestr isEqualToString:@"gif"]){
        _documentController.UTI=@"com.compuserve.gif";
    }else if([exestr isEqualToString:@"bmp"]){
        _documentController.UTI=@"com.microsoft.bmp";
    }else if([exestr isEqualToString:@"ico"]){
        _documentController.UTI=@"com.microsoft.ico";
    }else if([exestr isEqualToString:@"doc"]){
        _documentController.UTI=@"com.microsoft.word.doc";
    }else if([exestr isEqualToString:@"xls"]){
        _documentController.UTI=@"com.microsoft.excel.xls";
    }else if([exestr isEqualToString:@"ppt"]){
        _documentController.UTI=@"com.microsoft.powerpoint.​ppt";
    }else if([exestr isEqualToString:@"wav"]){
        _documentController.UTI=@"com.microsoft.waveform-​audio";
    }else if([exestr isEqualToString:@"wm"]){
        _documentController.UTI=@"com.microsoft.windows-​media-wm";
    }else if([exestr isEqualToString:@"wmv"]){
        _documentController.UTI=@"com.microsoft.windows-​media-wmv";
    }else if([exestr isEqualToString:@"pdf"]){
        _documentController.UTI=@"com.adobe.pdf";
    }else {
        NSLog(@"doc type not supported for preview");
        NSLog(@"%@", exestr);
    }
}

@end
