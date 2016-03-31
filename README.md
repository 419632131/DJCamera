一个AVFoundation的封装，开发者利用封装好的manager可随意自定义自己想要的UI照相机。
/**
 *  添加摄像范围到View
 *
 *  @param parent 传进来的parent的大小，就是摄像范围的大小
 */
- (void)configureWithParentLayer:(UIView *)parent;
/**
 *  切换前后镜
 *
 *  @param isFrontCamera
 */
- (void)switchCamera:(BOOL)isFrontCamera didFinishChanceBlock:(void(^)())block;
/**
 *  拍照
 *
 *  @param block 原图 比例图 裁剪图
 */
- (void)takePhotoWithImageBlock:(void(^)(UIImage *originImage,UIImage *scaledImage,UIImage *croppedImage))block;
/**
 *  切换闪光灯模式
 *
 *  @param sender 
 */
- (void)switchFlashMode:(UIButton*)sender;
/**
 *  点击对焦
 *
 *  @param devicePoint 
 */
- (void)focusInPoint:(CGPoint)devicePoint;

/**
 *  开启对焦监听 默认YES
 *
 *  @param  
 */
- (void)setFocusObserver:(BOOL)yes;
