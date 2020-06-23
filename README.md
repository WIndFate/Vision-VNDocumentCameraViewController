# Vision+VNDocumentCameraViewController
iOS13使用Vision进行一些检测的例子

### 内容效果
```objective-c
1.矩形检测
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

2.文字区域检测
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

3.文字内容检测
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

```  
