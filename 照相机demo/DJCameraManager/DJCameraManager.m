//
//  DJCameraManager.m
//  照相机demo
//
//  Created by Jason on 11/1/16.
//  Copyright © 2016年 Jason. All rights reserved.
//

#import "DJCameraManager.h"
#import "UIImage+DJResize.h"
#define adjustingFocus @"adjustingFocus"
#define ShowAlert(title) [[[UIAlertView alloc] initWithTitle:@"提示" message:title delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil, nil] show]
@interface DJCameraManager () <AVCaptureVideoDataOutputSampleBufferDelegate,AVCaptureMetadataOutputObjectsDelegate>
@property (nonatomic) dispatch_queue_t sessionQueue;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;
@property (nonatomic, strong) AVCaptureDeviceInput *inputDevice;
@property (nonatomic, strong) AVCaptureStillImageOutput *stillImageOutput;
@property (nonatomic, strong) AVCaptureMetadataOutput *metadataOutput;
@property (nonatomic, copy) void (^finishBlock)();
@property (nonatomic, strong) UIImageView *focusImageView;
@property (nonatomic, strong) UIImageView *faceImageView;
@property (nonatomic, assign) BOOL isManualFocus;//判断是否手动对焦
@property (nonatomic, assign) BOOL isStartFaceRecognition;
@end

@implementation DJCameraManager
- (void)dealloc
{
    NSLog(@"照相机管理人释放了");
    if ([self.session isRunning]) {
        [self.session stopRunning];
        self.session = nil;
    }
    [self setFocusObserver:NO];
}
- (instancetype)init
{
    self = [super init];
    if (self) {
        [self setup];
    }
    return self;
}

- (instancetype)initWithParentView:(UIView *)view
{
    self = [super init];
    if (self) {
        [self setup];
        [self configureWithParentLayer:view];
    }
    return self;
}
- (void)setup
{
    self.session = [[AVCaptureSession alloc] init];
    self.previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.session];
    self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    
    //对焦队列
    [self createQueue];
    //加入输入设备（前置或后置摄像头）
    [self addVideoInputFrontCamera:NO];
    //加入输出设备
    [self addStillImageOutput];
    //对焦MVO
    [self setFocusObserver:YES];
}

- (void)configureWithParentLayer:(UIView *)parent
{
    if (!parent) {
        ShowAlert(@"请加入负载视图");
        return;
    }
    
    
    self.previewLayer.frame = parent.bounds;
    [parent.layer addSublayer:self.previewLayer];
    //加入对焦框
    [self initfocusImageWithParent:parent];
    //加入脸部识别框
    [self initFaceImageWithParent:parent];
    [self.session startRunning];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.isStartFaceRecognition = YES;
    });
}

/**
 *  对焦的框
 */
- (void)initfocusImageWithParent:(UIView *)view;
{
    if (self.focusImageView) {
        return;
    }
    self.focusImageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"touch_focus_x.png"]];
    self.focusImageView.alpha = 0;
    if (view.superview!=nil) {
        [view.superview addSubview:self.focusImageView];
    }else{
        self.focusImageView = nil;
    }
}
/**
 *  脸部识别的框
 *
 *  @param view
 */
- (void)initFaceImageWithParent:(UIView *)view;
{
    if (self.faceImageView) {
        return;
    }
    self.faceImageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"face.png"]];
    self.faceImageView.alpha = 0;
    if (view.superview) {
        [view.superview addSubview:self.faceImageView];
    }else{
        self.faceImageView = nil;
    }
}

/**
 *  创建一个队列，防止阻塞主线程
 */
- (void)createQueue {
    dispatch_queue_t sessionQueue = dispatch_queue_create("session queue", DISPATCH_QUEUE_SERIAL);
    self.sessionQueue = sessionQueue;
}
/**
 *  添加输入设备
 *
 *  @param front 前或后摄像头
 */
- (void)addVideoInputFrontCamera:(BOOL)front {
    NSArray *devices = [AVCaptureDevice devices];
    AVCaptureDevice *frontCamera;
    AVCaptureDevice *backCamera;
    for (AVCaptureDevice *device in devices) {
        if ([device hasMediaType:AVMediaTypeVideo]) {
            if ([device position] == AVCaptureDevicePositionBack) {
                backCamera = device;
            }  else {
                frontCamera = device;
            }
        }
    }
    NSError *error = nil;
    if (front) {
        AVCaptureDeviceInput *frontFacingCameraDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:frontCamera error:&error];
        if (!error) {
            if ([_session canAddInput:frontFacingCameraDeviceInput]) {
                [_session addInput:frontFacingCameraDeviceInput];
                self.inputDevice = frontFacingCameraDeviceInput;
            } else {
                NSLog(@"Couldn't add front facing video input");
            }
        }else{
            NSLog(@"你的设备没有照相机");
        }
    } else {
        AVCaptureDeviceInput *backFacingCameraDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:backCamera error:&error];
        if (!error) {
            if ([_session canAddInput:backFacingCameraDeviceInput]) {
                [_session addInput:backFacingCameraDeviceInput];
                self.inputDevice = backFacingCameraDeviceInput;
            } else {
                NSLog(@"Couldn't add back facing video input");
            }
        }else{
            NSLog(@"你的设备没有照相机");
        }
    }
    if (error) {
        ShowAlert(@"您的设备没有照相机");
    }
}

/**
 *  添加输出设备
 */
- (void)addStillImageOutput
{
    
    
    AVCaptureStillImageOutput *tmpOutput = [[AVCaptureStillImageOutput alloc] init];
    NSDictionary *outputSettings = [[NSDictionary alloc] initWithObjectsAndKeys:AVVideoCodecJPEG,AVVideoCodecKey,nil];//输出jpeg
    tmpOutput.outputSettings = outputSettings;
    
//    AVCaptureConnection *videoConnection = [self findVideoConnection];
    
    [_session addOutput:tmpOutput];
    
    self.stillImageOutput = tmpOutput;
    
//    AVCaptureVideoDataOutput *dataOutput = [[AVCaptureVideoDataOutput alloc] init];
//    if ([self.session canAddOutput:dataOutput]) {
//        [self.session addOutput:dataOutput];
//        dispatch_queue_t cameraQueue;
//        cameraQueue = dispatch_queue_create("cameraQueue", DISPATCH_QUEUE_SERIAL);
//        [dataOutput setSampleBufferDelegate:self queue:cameraQueue];
//    }
    
    AVCaptureConnection *videoConnection = [self findVideoConnection];
    if (!videoConnection) {
        ShowAlert(@"您的设备没有照相机");
        return;
    }
    
    
    AVCaptureMetadataOutput *metadataOutput = [[AVCaptureMetadataOutput alloc] init];
    if ([_session canAddOutput:metadataOutput]) {
        [_session addOutput:metadataOutput];
        [metadataOutput setMetadataObjectTypes:@[AVMetadataObjectTypeFace]];
        [metadataOutput setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];
        self.metadataOutput = metadataOutput;
    }
}
/**
 *  拍照
 *
 *  @param block
 */
- (void)takePhotoWithImageBlock:(void (^)(UIImage *, UIImage *, UIImage *))block
{
    
    AVCaptureConnection *videoConnection = [self findVideoConnection];
    if (!videoConnection) {
        NSLog(@"你的设备没有照相机");
        ShowAlert(@"您的设备没有照相机");
        return;
    }
    __weak typeof(self) weak = self;
    [self.stillImageOutput captureStillImageAsynchronouslyFromConnection:videoConnection completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
        NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
        UIImage *originImage = [[UIImage alloc] initWithData:imageData];
        NSLog(@"originImage=%@",originImage);
        CGFloat squareLength = weak.previewLayer.bounds.size.width;
        CGFloat previewLayerH = weak.previewLayer.bounds.size.height;
//            CGFloat headHeight = weak.previewLayer.bounds.size.height - squareLength;
//            NSLog(@"heeadHeight=%f",headHeight);
        CGSize size = CGSizeMake(squareLength*2, previewLayerH*2);
        UIImage *scaledImage = [originImage resizedImageWithContentMode:UIViewContentModeScaleAspectFill bounds:size interpolationQuality:kCGInterpolationHigh];
        NSLog(@"scaledImage=%@",scaledImage);
        CGRect cropFrame = CGRectMake((scaledImage.size.width - size.width) / 2, (scaledImage.size.height - size.height) / 2, size.width, size.height);
        NSLog(@"cropFrame:%@", [NSValue valueWithCGRect:cropFrame]);
        UIImage *croppedImage = [scaledImage croppedImage:cropFrame];
        NSLog(@"croppedImage=%@",croppedImage);
        UIDeviceOrientation orientation = [UIDevice currentDevice].orientation;
        if (orientation != UIDeviceOrientationPortrait) {
            CGFloat degree = 0;
            if (orientation == UIDeviceOrientationPortraitUpsideDown) {
                degree = 180;// M_PI;
            } else if (orientation == UIDeviceOrientationLandscapeLeft) {
                degree = -90;// -M_PI_2;
            } else if (orientation == UIDeviceOrientationLandscapeRight) {
                degree = 90;// M_PI_2;
            }
            croppedImage = [croppedImage rotatedByDegrees:degree];
            scaledImage = [scaledImage rotatedByDegrees:degree];
            originImage = [originImage rotatedByDegrees:degree];
        }
        if (block) {
            block(originImage,scaledImage,croppedImage);
        }
    }];
    
}
/**
 *  切换闪光灯模式
 *  （切换顺序：最开始是auto，然后是off，最后是on，一直循环）
 *  @param sender: 闪光灯按钮
 */
- (void)switchFlashMode:(UIButton*)sender
{
    Class captureDeviceClass = NSClassFromString(@"AVCaptureDevice");
    if (!captureDeviceClass) {
        ShowAlert(@"您的设备没有拍照功能");
        return;
    }
    NSString *imgStr = @"";
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    [device lockForConfiguration:nil];
    if ([device hasFlash]) {
        if (device.flashMode == AVCaptureFlashModeOff) {
            device.flashMode = AVCaptureFlashModeOn;
            imgStr = @"flashing_on.png";
            
        } else if (device.flashMode == AVCaptureFlashModeOn) {
            device.flashMode = AVCaptureFlashModeAuto;
            imgStr = @"flashing_auto.png";
            
        } else if (device.flashMode == AVCaptureFlashModeAuto) {
            device.flashMode = AVCaptureFlashModeOff;
            imgStr = @"flashing_off.png";
        }
        if (sender) {
            [sender setImage:[UIImage imageNamed:imgStr] forState:UIControlStateNormal];
        }
    } else {
        ShowAlert(@"您的设备没有闪光灯功能");
    }
    [device unlockForConfiguration];
}
/**
 *  前后镜
 *
 *  @param isFrontCamera 
 */
- (void)switchCamera:(BOOL)isFrontCamera didFinishChanceBlock:(void (^)())block
{
    if (!_inputDevice) {
        
        if (block) {
            block();
        }
        ShowAlert(@"您的设备没有摄像头");
        return;
    }
    if (block) {
        self.finishBlock = [block copy];
    }
    CABasicAnimation *caAnimation = [CABasicAnimation animationWithKeyPath:@"transform.rotation.y"];
//    caAnimation.removedOnCompletion = NO;
//    caAnimation.fillMode = kCAFillModeForwards;
    caAnimation.fromValue = @(0);
    caAnimation.toValue = @(M_PI);
    caAnimation.duration = 1.f;
    caAnimation.repeatCount = 1;
    caAnimation.delegate = self;
    caAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.previewLayer addAnimation:caAnimation forKey:@"anim"];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [_session beginConfiguration];
        [_session removeInput:_inputDevice];
        [self addVideoInputFrontCamera:isFrontCamera];
        [_session commitConfiguration];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
        });
    });
}
- (void)animationDidStop:(CAAnimation *)anim finished:(BOOL)flag
{
    if (self.finishBlock) {
        self.finishBlock();
    }
}
/**
 *  点击对焦
 *
 *  @param devicePoint
 */
- (void)focusInPoint:(CGPoint)devicePoint
{
    if (CGRectContainsPoint(_previewLayer.bounds, devicePoint) == NO) {
        return;
    }
    self.isManualFocus = YES;
    [self focusImageAnimateWithCenterPoint:devicePoint];
    devicePoint = [self convertToPointOfInterestFromViewCoordinates:devicePoint];
    [self focusWithMode:AVCaptureFocusModeAutoFocus exposeWithMode:AVCaptureExposureModeContinuousAutoExposure atDevicePoint:devicePoint monitorSubjectAreaChange:YES];
    
}
- (void)focusImageAnimateWithCenterPoint:(CGPoint)point
{
    [self.focusImageView setCenter:point];
    self.focusImageView.transform = CGAffineTransformMakeScale(2.0, 2.0);
    __weak typeof(self) weak = self;
    [UIView animateWithDuration:0.3f delay:0.f options:UIViewAnimationOptionAllowUserInteraction animations:^{
        weak.focusImageView.alpha = 1.f;
        weak.focusImageView.transform = CGAffineTransformMakeScale(1.0, 1.0);
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.5f delay:0.5f options:UIViewAnimationOptionAllowUserInteraction animations:^{
            weak.focusImageView.alpha = 0.f;
        } completion:^(BOOL finished) {
            weak.isManualFocus = NO;
        }];
    }];
}

- (void)focusWithMode:(AVCaptureFocusMode)focusMode exposeWithMode:(AVCaptureExposureMode)exposureMode atDevicePoint:(CGPoint)point monitorSubjectAreaChange:(BOOL)monitorSubjectAreaChange
{
    
    dispatch_async(_sessionQueue, ^{
        AVCaptureDevice *device = [self.inputDevice device];
        NSError *error = nil;
        if ([device lockForConfiguration:&error])
        {
            if ([device isFocusPointOfInterestSupported] && [device isFocusModeSupported:focusMode])
            {
                [device setFocusMode:focusMode];
                [device setFocusPointOfInterest:point];
            }
            if ([device isExposurePointOfInterestSupported] && [device isExposureModeSupported:exposureMode])
            {
                [device setExposureMode:exposureMode];
                [device setExposurePointOfInterest:point];
            }
            [device setSubjectAreaChangeMonitoringEnabled:monitorSubjectAreaChange];
            [device unlockForConfiguration];
        }
        else
        {
            NSLog(@"%@", error);
        }
    });
}

/**
 *  外部的point转换为camera需要的point(外部point/相机页面的frame)
 *
 *  @param viewCoordinates 外部的point
 *
 *  @return 相对位置的point
 */
- (CGPoint)convertToPointOfInterestFromViewCoordinates:(CGPoint)viewCoordinates {
    CGPoint pointOfInterest = CGPointMake(.5f, .5f);
    CGSize frameSize = _previewLayer.bounds.size;
    
    AVCaptureVideoPreviewLayer *videoPreviewLayer = self.previewLayer;
    
    if([[videoPreviewLayer videoGravity] isEqualToString:AVLayerVideoGravityResize]) {
        pointOfInterest = CGPointMake(viewCoordinates.y / frameSize.height, 1.f - (viewCoordinates.x / frameSize.width));
    } else {
        CGRect cleanAperture;
        for(AVCaptureInputPort *port in [[self.session.inputs lastObject]ports]) {
            if([port mediaType] == AVMediaTypeVideo) {
                cleanAperture = CMVideoFormatDescriptionGetCleanAperture([port formatDescription], YES);
                CGSize apertureSize = cleanAperture.size;
                CGPoint point = viewCoordinates;
                
                CGFloat apertureRatio = apertureSize.height / apertureSize.width;
                CGFloat viewRatio = frameSize.width / frameSize.height;
                CGFloat xc = .5f;
                CGFloat yc = .5f;
                
                if([[videoPreviewLayer videoGravity]isEqualToString:AVLayerVideoGravityResizeAspect]) {
                    if(viewRatio > apertureRatio) {
                        CGFloat y2 = frameSize.height;
                        CGFloat x2 = frameSize.height * apertureRatio;
                        CGFloat x1 = frameSize.width;
                        CGFloat blackBar = (x1 - x2) / 2;
                        if(point.x >= blackBar && point.x <= blackBar + x2) {
                            xc = point.y / y2;
                            yc = 1.f - ((point.x - blackBar) / x2);
                        }
                    } else {
                        CGFloat y2 = frameSize.width / apertureRatio;
                        CGFloat y1 = frameSize.height;
                        CGFloat x2 = frameSize.width;
                        CGFloat blackBar = (y1 - y2) / 2;
                        if(point.y >= blackBar && point.y <= blackBar + y2) {
                            xc = ((point.y - blackBar) / y2);
                            yc = 1.f - (point.x / x2);
                        }
                    }
                } else if([[videoPreviewLayer videoGravity]isEqualToString:AVLayerVideoGravityResizeAspectFill]) {
                    if(viewRatio > apertureRatio) {
                        CGFloat y2 = apertureSize.width * (frameSize.width / apertureSize.height);
                        xc = (point.y + ((y2 - frameSize.height) / 2.f)) / y2;
                        yc = (frameSize.width - point.x) / frameSize.width;
                    } else {
                        CGFloat x2 = apertureSize.height * (frameSize.height / apertureSize.width);
                        yc = 1.f - ((point.x + ((x2 - frameSize.width) / 2)) / x2);
                        xc = point.y / frameSize.height;
                    }
                    
                }
                
                pointOfInterest = CGPointMake(xc, yc);
                break;
            }
        }
    }
    
    return pointOfInterest;
}
/**
 *  人脸框的动画
 *
 *  @param rect 
 */
- (void)showFaceImageWithFrame:(CGRect)rect
{
    if (self.isStartFaceRecognition) {
        self.isStartFaceRecognition = NO;
        self.faceImageView.frame = CGRectMake(rect.origin.y * self.previewLayer.frame.size.width-10, rect.origin.x * self.previewLayer.frame.size.height - 20, rect.size.width * self.previewLayer.frame.size.width * 2, rect.size.height * self.previewLayer.frame.size.height);
        
        self.faceImageView.transform = CGAffineTransformMakeScale(1.5, 1.5);
        __weak typeof(self) weak = self;
        [UIView animateWithDuration:0.3f animations:^{
            weak.faceImageView.alpha = 1.f;
            weak.faceImageView.transform = CGAffineTransformMakeScale(1.0, 1.0);
        } completion:^(BOOL finished) {
            [UIView animateWithDuration:2.f animations:^{
                weak.faceImageView.alpha = 0.f;
            } completion:^(BOOL finished) {
                if (weak.faceRecognitonCallBack) {
                    weak.faceRecognitonCallBack(weak.faceImageView.frame);
                }
                weak.isStartFaceRecognition = YES;
                
            }];
        }];
    }
}

/**
 *  查找摄像头连接设备
 *
 *  @return
 */
- (AVCaptureConnection *)findVideoConnection
{
    AVCaptureConnection *videoConnection = nil;
    for (AVCaptureConnection *connection in _stillImageOutput.connections) {
        for (AVCaptureInputPort *port in connection.inputPorts) {
            if ([[port mediaType] isEqual:AVMediaTypeVideo]) {
                videoConnection = connection;
                break;
            }
        }
        if (videoConnection) {
            break;
        }
    }
    return videoConnection;
}

/*
 检查是否有相机权限
 */
+ (BOOL)checkAuthority
{
    NSString *mediaType = AVMediaTypeVideo;
    AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:mediaType];
    if(authStatus == AVAuthorizationStatusRestricted || authStatus == AVAuthorizationStatusDenied){
        return NO;
    }
    return YES;
}
#pragma -mark Observer
- (void)setFocusObserver:(BOOL)yes
{
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    if (device && [device isFocusPointOfInterestSupported]) {
        if (yes) {
            [device addObserver:self forKeyPath:adjustingFocus options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld context:nil];
        }else{
            [device removeObserver:self forKeyPath:adjustingFocus context:nil];
        }
    }else{
        ShowAlert(@"你的设备没有照相机");
    }
}

//监听对焦是否完成了
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:adjustingFocus]) {
        BOOL isAdjustingFocus = [[change objectForKey:NSKeyValueChangeNewKey] boolValue];
        if (isAdjustingFocus) {
            if (self.isManualFocus==NO) {
                [self focusImageAnimateWithCenterPoint:CGPointMake(self.previewLayer.bounds.size.width/2, self.previewLayer.bounds.size.height/2)];
            }
            if ([self.delegate respondsToSelector:@selector(cameraDidStareFocus)]) {
                [self.delegate cameraDidStareFocus];
            }
        }else{
            if ([self.delegate respondsToSelector:@selector(cameraDidFinishFocus)]) {
                [self.delegate cameraDidFinishFocus];
            }
        }
    }
}
#pragma -mark AVCaptureMetadataOutputObjectsDelegate
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection
{
    if (self.canFaceRecognition) {
        for(AVMetadataObject *metadataObject in metadataObjects) {
            if([metadataObject.type isEqualToString:AVMetadataObjectTypeFace]) {
                [self showFaceImageWithFrame:metadataObject.bounds];
            }
        }
    }
}

/*
#pragma -mark AVCaptureVideoDataOutputSampleBufferDelegate
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
//    if (self.isStartFaceRecognition) {
//        UIImage *curImage = [self getSampleBufferImageWithSampleBuffer:sampleBuffer];
//        CIContext *context = [CIContext contextWithOptions:@{kCIContextUseSoftwareRenderer:@YES}];
//        CIDetector *detector = [CIDetector detectorOfType:CIDetectorTypeFace context:context options:@{CIDetectorAccuracy:CIDetectorAccuracyHigh}];
//        
//    }
    
}

- (UIImage *)getSampleBufferImageWithSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
    CVImageBufferRef buffer;
    buffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    
    CVPixelBufferLockBaseAddress(buffer, 0);
    
    //从 CVImageBufferRef 取得影像的细部信息
    uint8_t *base;
    size_t width, height, bytesPerRow;
    base = CVPixelBufferGetBaseAddress(buffer);
    width = CVPixelBufferGetWidth(buffer);
    height = CVPixelBufferGetHeight(buffer);
    bytesPerRow = CVPixelBufferGetBytesPerRow(buffer);
    
    //利用取得影像细部信息格式化 CGContextRef
    CGColorSpaceRef colorSpace;
    CGContextRef cgContext;
    colorSpace = CGColorSpaceCreateDeviceRGB();
    cgContext = CGBitmapContextCreate(base, width, height, 8, bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    CGColorSpaceRelease(colorSpace);
    
    //透过 CGImageRef 将 CGContextRef 转换成 UIImage
    CGImageRef cgImage;
    UIImage *image;
    cgImage = CGBitmapContextCreateImage(cgContext);
    image = [UIImage imageWithCGImage:cgImage];
    CGImageRelease(cgImage);
    CGContextRelease(cgContext);
    
    CVPixelBufferUnlockBaseAddress(buffer, 0);
    
    return image;
}
 */
@end
