//
//  ESCPOSCore.m
//  ESCPOS
//
//  Created by Khaos Tian on 5/21/13.
//  Copyright (c) 2013 Oltica. All rights reserved.
//

#import "ESCPOSCore.h"

#define COMM_TIME_OUT           0.5
#define NSGB18030StringEncoding 0x80000631

void freeRawData(void *info, const void *data, size_t size);

@implementation ESCPOSCore

+(ESCPOSCore *)CoreManager
{
    static ESCPOSCore *CoreManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        CoreManager = [[self alloc]init];
    });
    return CoreManager;
}

-(void)connectToAddress:(NSString *)address Delegate:(id)delegate
{
    if (_socket == nil) {
        _socket = [[GCDAsyncSocket alloc]initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
    }
    self.delegate = delegate;
    NSError *err = nil;
    if (![_socket connectToHost:address onPort:9100 withTimeout:COMM_TIME_OUT error:&err]) {
        NSLog(@"%@",err);
    }
}

-(void)disconnect
{
    [_socket disconnect];
}

-(void)changeBackgroundColor:(BackgroundColorType)color
{
    NSMutableData  *commdata = [NSMutableData dataWithBytes:"\x1d\x42" length:2];
    [commdata appendBytes:&color length:1];
    [_socket writeData:commdata withTimeout:COMM_TIME_OUT tag:1];
}

-(void)printString:(NSString *)string
{
    NSMutableData *commdata = [[string dataUsingEncoding:NSGB18030StringEncoding]mutableCopy];
    [commdata appendBytes:"\x0A" length:1];
    [_socket writeData:commdata withTimeout:COMM_TIME_OUT tag:2];
}

-(void)printLeftString:(NSString *)lstring RightString:(NSString *)rstring
{
    NSMutableString *str = [lstring mutableCopy];
    for (int i=0;i<32-(int)[lstring lengthOfBytesUsingEncoding:NSGB18030StringEncoding]-(int)[rstring lengthOfBytesUsingEncoding:NSGB18030StringEncoding];i++) {
        [str appendString:@" "];
    }
    [str appendString:rstring];
    [self printString:str];
}

-(void)printBarcode:(NSString *)string Type:(BarCodeType)type
{
    [self printBarcode:string Type:type Height:80 Width:3 Position:BARCODE_TXT_BLW];
}

-(void)printBarcode:(NSString *)string Type:(BarCodeType)type Height:(int)height
{
    [self printBarcode:string Type:type Height:height Width:3 Position:BARCODE_TXT_BLW];
}

-(void)printBarcode:(NSString *)string Type:(BarCodeType)type Height:(int)height Width:(int)width Position:(BarCodeTextPosition)pos 
{
    NSMutableData *setupData = [NSMutableData dataWithBytes:"\x1d\x68" length:2];
    [setupData appendBytes:&height length:1];
    //Position
    [setupData appendBytes:"\x1d\x48" length:2];
    [setupData appendBytes:&pos length:1];
    //Width
    [setupData appendBytes:"\x1d\x77" length:2];
    [setupData appendBytes:&width length:1];
    [_socket writeData:setupData withTimeout:COMM_TIME_OUT tag:2];
    
    NSMutableData   *stringData = [NSMutableData dataWithBytes:"\x1d\x6b" length:2];
    [stringData appendBytes:&type length:1];
    [stringData appendData:[string dataUsingEncoding:NSASCIIStringEncoding]];
    [stringData appendBytes:"\x00" length:1];
    [_socket writeData:stringData withTimeout:COMM_TIME_OUT tag:2];
}

#if TARGET_OS_IPHONE

-(void)printImage:(UIImage *)src{

#else

-(void)printImage:(NSImage *)src{

#endif

    dispatch_queue_t gQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(gQueue, ^{
        int width = src.size.width;
        int height = src.size.height;
        
        NSData  *initdata = [NSData dataWithBytes:"\x0a" length:1];
        [_socket writeData:initdata withTimeout:COMM_TIME_OUT tag:1];
        
        int wL = (width + 7)/8;
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceGray();
        
        CGContextRef context = CGBitmapContextCreate (nil,
                                                      wL*8,
                                                      height,
                                                      8,      // bits per component
                                                      0,
                                                      colorSpace,
                                                      kCGImageAlphaNone);
        
        CGColorSpaceRelease(colorSpace);
        
        CGContextSetRGBFillColor(context, 1.0, 1.0, 1.0, 1.0);
        CGContextFillRect(context, CGRectMake(0, 0, wL*8, height));
        
        CGContextDrawImage(context,
                           CGRectMake(0, 0, width, height), [src CGImageForProposedRect:nil context:nil hints:nil]);
        
        NSImage *grayImage = [[NSImage alloc]initWithCGImage:CGBitmapContextCreateImage(context) size:src.size];
        CGContextRelease(context);
        NSData* tiffData = [grayImage TIFFRepresentation];
        NSBitmapImageRep* bitMapRep = [NSBitmapImageRep
                                       imageRepWithData:tiffData];
        NSMutableData *tex = [NSMutableData dataWithBytes:[bitMapRep bitmapData] length:[bitMapRep pixelsWide]*[bitMapRep pixelsHigh]*[bitMapRep samplesPerPixel]*sizeof(unsigned char)];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [_delegate setImageViewImage:grayImage];
        });
        
        NSMutableData *imageData = [NSMutableData data];
        int counter = 0;
        int byte = 0;
        for (int i=0;i<tex.length;i++) {
            counter ++;
            if (counter>7) {
                [imageData appendBytes:&byte length:1];
                counter = 0;
                byte = 0;
            }
            char bytes;
            [tex getBytes:&bytes range:NSMakeRange(i, 1)];
            if (bytes == -1 || (bytes > -95 && bytes < -1)) {
                byte = byte << 1;
            }else{
                byte = byte << 1;
                byte = byte + 1;
            }
        }
        [imageData setLength:wL*height];
        
        if (height>100) {
            for (int cc=0; cc<height;) {
                if (cc<height-100) {
                    NSMutableData *commdata = [NSMutableData dataWithBytes:"\x1d\x76\x30\x00" length:4];
                    [commdata appendBytes:&wL length:1];
                    [commdata appendBytes:"\x00" length:1];
                    [commdata appendBytes:"\x64" length:1];
                    [commdata appendBytes:"\x00" length:1];
                    [commdata appendData:[imageData subdataWithRange:NSMakeRange(cc*wL, wL*100)]];
                    [commdata appendBytes:"\x1b\x4a\x00" length:3];
                    [_socket writeData:commdata withTimeout:COMM_TIME_OUT tag:2];
                    cc = cc+100;
                }else{
                    int restleng = height - cc;
                    NSMutableData *commdata = [NSMutableData dataWithBytes:"\x1d\x76\x30\x00" length:4];
                    [commdata appendBytes:&wL length:1];
                    [commdata appendBytes:"\x00" length:1];
                    [commdata appendBytes:&restleng length:1];
                    [commdata appendBytes:"\x00" length:1];
                    [commdata appendData:[imageData subdataWithRange:NSMakeRange(cc*wL, restleng*wL)]];
                    [commdata appendBytes:"\x1b\x4a\x00" length:3];
                    [_socket writeData:commdata withTimeout:COMM_TIME_OUT tag:2];
                    cc = cc+restleng;
                }
                [NSThread sleepForTimeInterval:0.1];
            }
        }else{
            NSMutableData *commdata = [NSMutableData dataWithBytes:"\x1d\x76\x30\x00" length:4];
            [commdata appendBytes:&wL length:1];
            [commdata appendBytes:"\x00" length:1];
            [commdata appendBytes:&height length:1];
            [commdata appendBytes:"\x00" length:1];
            [commdata appendData:imageData];
            [commdata appendBytes:"\x0A" length:1];
            [_socket writeData:commdata withTimeout:COMM_TIME_OUT tag:2];
        }

    });
}

-(void)printQRCode:(NSString *)string withDimension:(int)imageWidth
{
    if (string.length == 0) {
        return;
    }
    
    [self printImage:[self quickResponseImageForString:string withDimension:imageWidth]];
}

void freeRawData(void *info, const void *data, size_t size) {
    free((unsigned char *)data);
}

- (NSImage *)quickResponseImageForString:(NSString *)dataString withDimension:(int)imageWidth {
    
    QRcode *resultCode = QRcode_encodeString([dataString UTF8String], 0, QR_ECLEVEL_L, QR_MODE_8, 1);
    
    unsigned char *pixels = (*resultCode).data;
    int width = (*resultCode).width;
    int len = width * width;
    
    if (imageWidth < width)
        imageWidth = width;
    
    // Set bit-fiddling variables
    int bytesPerPixel = 4;
    int bitsPerPixel = 8 * bytesPerPixel;
    int bytesPerLine = bytesPerPixel * imageWidth;
    int rawDataSize = bytesPerLine * imageWidth;
    
    int pixelPerDot = imageWidth / width;
    int offset = (int)((imageWidth - pixelPerDot * width) / 2);
    
    // Allocate raw image buffer
    unsigned char *rawData = (unsigned char*)malloc(rawDataSize);
    memset(rawData, 0xFF, rawDataSize);
    
    // Fill raw image buffer with image data from QR code matrix
    int i;
    for (i = 0; i < len; i++) {
        char intensity = (pixels[i] & 1) ? 0 : 0xFF;
        
        int y = i / width;
        int x = i - (y * width);
        
        int startX = pixelPerDot * x * bytesPerPixel + (bytesPerPixel * offset);
        int startY = pixelPerDot * y + offset;
        int endX = startX + pixelPerDot * bytesPerPixel;
        int endY = startY + pixelPerDot;
        
        int my;
        for (my = startY; my < endY; my++) {
            int mx;
            for (mx = startX; mx < endX; mx += bytesPerPixel) {
                rawData[bytesPerLine * my + mx    ] = intensity;    //red
                rawData[bytesPerLine * my + mx + 1] = intensity;    //green
                rawData[bytesPerLine * my + mx + 2] = intensity;    //blue
                rawData[bytesPerLine * my + mx + 3] = 255;          //alpha
            }
        }
    }
    
    CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, rawData, rawDataSize, (CGDataProviderReleaseDataCallback)&freeRawData);
    CGColorSpaceRef colorSpaceRef = CGColorSpaceCreateDeviceRGB();
    CGBitmapInfo bitmapInfo = kCGBitmapByteOrderDefault;
    CGColorRenderingIntent renderingIntent = kCGRenderingIntentDefault;
    CGImageRef imageRef = CGImageCreate(imageWidth, imageWidth, 8, bitsPerPixel, bytesPerLine, colorSpaceRef, bitmapInfo, provider, NULL, NO, renderingIntent);
    
    NSImage *quickResponseImage = [[NSImage alloc]initWithCGImage:imageRef size:NSZeroSize];
    
    CGImageRelease(imageRef);
    CGColorSpaceRelease(colorSpaceRef);
    CGDataProviderRelease(provider);
    QRcode_free(resultCode);
    
    return quickResponseImage;
}

-(void)cutPaper
{
    NSMutableData *commdata = [[@"\n\n\n\n\n\n" dataUsingEncoding:NSGB18030StringEncoding]mutableCopy];
    [commdata appendBytes:"\x1d\x56\x00" length:3];
    [_socket writeData:commdata withTimeout:COMM_TIME_OUT tag:2];
}

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(UInt16)port
{
    _connected = YES;
    NSData  *commdata = [NSData dataWithBytes:"\x1b\x40" length:2];
    [_socket writeData:commdata withTimeout:COMM_TIME_OUT tag:1];
    if ([self.delegate respondsToSelector:@selector(didConnectToHost:)]) {
        [_delegate didConnectToHost:host];
    }
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err
{
    _connected = NO;
    if ([self.delegate respondsToSelector:@selector(didDisconnect)]) {
        [_delegate didDisconnect];
    }
}

- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag
{
    
}

@end
