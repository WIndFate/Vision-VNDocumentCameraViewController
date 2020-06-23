//
//  ViewController.m
//  Perspective-Correct
//
//  Created by Kou Syui on 2020/06/17.
//  Copyright © 2020 WIndFate. All rights reserved.
//

//#import "OpenCVManager.h"
#import "ViewController.h"
#import <Vision/Vision.h>
#import <VisionKit/VisionKit.h>

#define imageName1 @"Taxi"
#define imageName2 @"Taxi1"
#define imageName3 @"xiaopiao"
#define imageName4 @"receipt"
#define imageName5 @"receipt1"

@interface ViewController ()<VNDocumentCameraViewControllerDelegate>

@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet UIImageView *highImageView;

@property (nonatomic, strong) NSMutableDictionary<NSString *, VNDetectedObjectObservation *> *lastObsercationsDic;

@property (nonatomic, strong) NSString *recognizeText;

@property (nonatomic, assign) int imagePage;

@property (nonatomic, strong) NSArray *imageArray;

@end

@implementation ViewController

-(NSArray *) imageArray{
    
    if (!_imageArray) {
        
        _imageArray = [NSArray arrayWithObjects:imageName1,imageName2,imageName3,imageName4,imageName5, nil];
    }
    return _imageArray;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.imagePage = 4;
    self.imageView.image = [UIImage imageNamed:self.imageArray[self.imagePage]];
    
}

// 矩形检测
- (void)detectObjectWithCGImage:(CGImageRef)cgImage {
    
    if (!self.lastObsercationsDic) {
        self.lastObsercationsDic = [NSMutableDictionary dictionary];
    }
    
    CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
    
    CGSize size = self.imageView.image.size;
    
    VNImageRequestHandler *handler = [[VNImageRequestHandler alloc] initWithCGImage:cgImage options:@{}];
    VNDetectRectanglesRequest *request = [[VNDetectRectanglesRequest alloc] initWithCompletionHandler:^(VNRequest * _Nonnull request, NSError * _Nullable error) {
        
        CFAbsoluteTime end = CFAbsoluteTimeGetCurrent();
                
                NSLog(@"检测耗时： %f", end - start);
                if (!error && request.results.count > 0) {
                    for (VNDetectedObjectObservation *observation in request.results) {
                        [self.lastObsercationsDic setObject:observation forKey:observation.uuid.UUIDString];
                    }
                    
                    [self overlayImageWithSize:size];
                    
                    return ;
                }
    }];
    request.minimumAspectRatio = 0.1;
    [handler performRequests:@[request] error:nil];
}


// 绘制边框
- (void)overlayImageWithSize:(CGSize)size {
    
    NSDictionary *lastObsercationDicCopy = [NSDictionary dictionaryWithDictionary:self.lastObsercationsDic];
    NSArray *keyArr = [lastObsercationDicCopy allKeys];
    
    
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(size.width, size.height)];
    
    UIImage *overlayImage = [renderer imageWithActions:^(UIGraphicsImageRendererContext * _Nonnull rendererContext) {
        
        CGAffineTransform  transform = CGAffineTransformIdentity;
        transform = CGAffineTransformScale(transform, size.width, -size.height);
        transform = CGAffineTransformTranslate(transform, 0, -1);
        
        for (NSString *uuid in keyArr) {
            VNDetectedObjectObservation *rectangleObservation = lastObsercationDicCopy[uuid];
            
            [[UIColor redColor] setStroke];
            UIBezierPath *path = [UIBezierPath bezierPathWithRect:CGRectApplyAffineTransform(rectangleObservation.boundingBox, transform)];
            path.lineWidth = 10.0f;
            [path stroke];
            
        }
    }];
    
    NSMutableString *trackInfoStr = [NSMutableString string];
    
    for (NSString *uuid in keyArr) {
        VNDetectedObjectObservation *rectangleObservation = lastObsercationDicCopy[uuid];
        
        [trackInfoStr appendFormat:@"置信度 ： %.2f \n", rectangleObservation.confidence];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        self.highImageView.image = overlayImage;
        
        NSLog(@"--trackInfoStr : %@",trackInfoStr);
    });
}


// 文字区域检测
- (void)detectTextAreaWithCGImage:(CGImageRef)cgImage {

    VNImageRequestHandler *handler = [[VNImageRequestHandler alloc] initWithCGImage:cgImage options:@{}];
    VNDetectTextRectanglesRequest *request = [[VNDetectTextRectanglesRequest alloc] initWithCompletionHandler:^(VNRequest * _Nonnull request, NSError * _Nullable error) {
        
        if (nil == error) {
            
            CGSize size = self.imageView.image.size;

            UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:size];
            UIImage *overlayImage = [renderer imageWithActions:^(UIGraphicsImageRendererContext * _Nonnull rendererContext) {
                
                CGAffineTransform  transform= CGAffineTransformIdentity;
                transform = CGAffineTransformScale(transform, size.width, -size.height);
                transform = CGAffineTransformTranslate(transform, 0, -1);

                for (VNTextObservation *textObservation in request.results)
                {
                    [[UIColor redColor] setStroke];
                    [[UIBezierPath bezierPathWithRect:CGRectApplyAffineTransform(textObservation.boundingBox, transform)] stroke];
                    for (VNRectangleObservation *rectangleObservation in textObservation.characterBoxes)
                    {
                        [[UIColor blueColor] setStroke];
                        [[UIBezierPath bezierPathWithRect:CGRectApplyAffineTransform(rectangleObservation.boundingBox, transform)] stroke];
                    }
                }
            }];

            dispatch_async(dispatch_get_main_queue(), ^{
                self.highImageView.image = overlayImage;
            });
        }
    }];

    request.reportCharacterBoxes = YES;
    [handler performRequests:@[request] error:nil];
}

// 文字内容检测
- (void)detectTextContentWithCGImage:(CGImageRef)cgImage {
    
    self.recognizeText = @"";
    VNImageRequestHandler *handler = [[VNImageRequestHandler alloc] initWithCGImage:cgImage options:@{}];
    VNRecognizeTextRequest *request = [[VNRecognizeTextRequest alloc] initWithCompletionHandler:^(VNRequest * _Nonnull request, NSError * _Nullable error) {
        
        if (nil == error) {
            
            for (VNRecognizedTextObservation *recognizedTextObservation in request.results)
            {
                
                VNRecognizedText *text = [[recognizedTextObservation topCandidates:1] firstObject];
                NSLog(@"%@",text.string);
                self.recognizeText = [NSString stringWithFormat:@"%@ %@",self.recognizeText,text.string];
            }
            
            
            UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"只能识别英文" message:self.recognizeText preferredStyle:UIAlertControllerStyleAlert];
            
            //add cancel button；
            [alertController addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
                
            }]];
            
            [self presentViewController:alertController animated:YES completion:nil];
        }
    }];

//    request.recognitionLanguages = @[@"ja-JP"];
    request.recognitionLevel = VNRequestTextRecognitionLevelAccurate;
    [handler performRequests:@[request] error:nil];
    
}

- (IBAction)nextImage:(id)sender {
    
    self.imagePage ++;
    if (self.imagePage > 4) {
        
        self.imagePage = 0;
        
    }
    
    self.imageView.image = [UIImage imageNamed:self.imageArray[self.imagePage]];
    self.highImageView.image = nil;
}

- (IBAction)resumeClick:(id)sender {
    
    self.imageView.image = [UIImage imageNamed:self.imageArray[4]];
    self.highImageView.image = nil;
}

- (IBAction)photoHandle:(id)sender {
    
    [self.lastObsercationsDic removeAllObjects];
    [self detectObjectWithCGImage:self.imageView.image.CGImage];
    
}
- (IBAction)textArea:(id)sender {
    
    [self detectTextAreaWithCGImage:self.imageView.image.CGImage];
}

- (IBAction)textHandle:(id)sender {
    
    [self detectTextContentWithCGImage:self.imageView.image.CGImage];
}

- (IBAction)cameraClick:(id)sender {
    
    if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
        
        VNDocumentCameraViewController* dcVc = [[VNDocumentCameraViewController alloc] init];

        dcVc.delegate=self;

        [self presentViewController:dcVc animated:YES completion:nil];
        
    } else {
        NSLog(@"不能使用模拟器进行拍照");
    }
    
}


#pragma mark - VNDocumentCameraViewControllerDelegate

- (void)documentCameraViewController:(VNDocumentCameraViewController *)controller didFinishWithScan:(VNDocumentCameraScan *)scan API_AVAILABLE(ios(13)){

    for(int i = 0; i < [scan pageCount]; i++) {
        
        UIImage* img = [scan imageOfPageAtIndex:i];
        
        self.imageView.image = img;
    
    }

    [controller dismissViewControllerAnimated:YES completion:nil];
}

- (void)documentCameraViewControllerDidCancel:(VNDocumentCameraViewController *)controller API_AVAILABLE(ios(13)){

    [controller dismissViewControllerAnimated:YES completion:nil];

}

- (void)documentCameraViewController:(VNDocumentCameraViewController *)controller didFailWithError:(NSError *)error API_AVAILABLE(ios(13)){



}

@end
