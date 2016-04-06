#一个AVFoundation的封装，开发者利用封装好的manager可随意自定义自己想要的UI照相机。

##4月1号更新功能：人脸识别

设置是否使用人脸识别：

manager.canFaceRecognition = YES;

开启脸部位置监听：

[manager setFaceRecognitonCallBack:^(CGRect faceFrame) {

 NSLog(@"你的脸在%@",NSStringFromCGRect(faceFrame));
      
 }];

##初始化：

  DJCameraManager *manager = [[DJCameraManager alloc] initWithParentView:pickView];
  
  pickView 是你要装载这个摄像视图的View 它的frame就是摄像范围。
  
添加摄像范围到View

\- (void)configureWithParentLayer:(UIView *)parent;

切换前后镜

\- (void)switchCamera:(BOOL)isFrontCamera didFinishChanceBlock:(void(^)())block;

拍照

\- (void)takePhotoWithImageBlock:(void(^)(UIImage *originImage,UIImage *scaledImage,UIImage *croppedImage))block; 

切换闪光灯模式

\- (void)switchFlashMode:(UIButton*)sender;

点击对焦

\- (void)focusInPoint:(CGPoint)devicePoint;

开启对焦监听 默认YES

\- (void)setFocusObserver:(BOOL)yes;

###喜欢的朋友帮忙Star一下哦，射射！