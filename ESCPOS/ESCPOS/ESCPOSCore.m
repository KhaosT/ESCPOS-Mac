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

- (void)bitmapWithImage:(NSImage *)src
{
    int width = src.size.width;
	int height = src.size.height;
    
    if (height>255) {
        return;
    }
    
    NSData  *initdata = [NSData dataWithBytes:"\x0a" length:1];
    [_socket writeData:initdata withTimeout:COMM_TIME_OUT tag:1];
    
    int wL = (width + 7)/8;
    NSLog(@"%i",wL);
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceGray();
    
	CGContextRef context = CGBitmapContextCreate (nil,
                                                  width,
                                                  height,
                                                  8,      // bits per component
                                                  0,
                                                  colorSpace,
                                                  kCGImageAlphaNone);
    
	CGColorSpaceRelease(colorSpace);
    
	CGContextDrawImage(context,
                       CGRectMake(0, 0, width, height), [src CGImageForProposedRect:nil context:nil hints:nil]);
    
	NSImage *grayImage = [[NSImage alloc]initWithCGImage:CGBitmapContextCreateImage(context) size:src.size];
	CGContextRelease(context);
    NSData* tiffData = [grayImage TIFFRepresentation];
    NSBitmapImageRep* bitMapRep = [NSBitmapImageRep
                                   imageRepWithData:tiffData];
    NSMutableData *tex = [NSMutableData dataWithBytes:[bitMapRep bitmapData] length:[bitMapRep pixelsWide]*[bitMapRep pixelsHigh]*[bitMapRep samplesPerPixel]*sizeof(unsigned char)];
    NSMutableData *commdata = [NSMutableData dataWithBytes:"\x1d\x76\x30\x00" length:4];
    [commdata appendBytes:&wL length:1];
    [commdata appendBytes:"\x00" length:1];
    [commdata appendBytes:&height length:1];
    [commdata appendBytes:"\x00" length:1];
    //NSLog(@"%@,%li",[tex description],(unsigned long)[tex length]);
    //NSMutableString *binary = [[NSMutableString alloc]initWithString:@""];
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
    [commdata appendData:imageData];
    [_socket writeData:commdata withTimeout:COMM_TIME_OUT tag:2];
    [_delegate setImageViewImage:grayImage];
}

-(void)printImage:(NSImage *)image
{
    [self bitmapWithImage:image];
    /*NSBitmapImageRep *imageRep = [[image representations] lastObject];
    
	if ( ![imageRep isKindOfClass:[NSBitmapImageRep class]] ) // sanity check
		return;
    
	int pixelsWide = (int)[imageRep pixelsWide];
	int pixelsHigh = (int)[imageRep pixelsHigh];
    int wL = (pixelsWide + 7)/8;
        
    NSMutableData *commdata = [NSMutableData dataWithBytes:"\x1d\x76\x30\x00" length:4];
    [commdata appendBytes:&wL length:1];
    [commdata appendBytes:"\x00" length:1];
    [commdata appendBytes:&pixelsHigh length:1];
    [commdata appendBytes:"\x00" length:1];
    
	for ( NSUInteger x = 0; x < pixelsWide; x++ )
	{
		for ( NSUInteger y = 0; y < pixelsHigh; y++ )
		{
			NSColor *color = [imageRep colorAtX:x y:y];
            float imgcolor = color.redComponent + color.greenComponent + color.blueComponent;
			if ( imgcolor<=1.0*3.0 )
			{
                NSLog(@"Called1");
			}else{
                NSLog(@"Called2");
            }
		}
	}*/
    /*Byte byte[] = {
                  0x00,0x00,0x00,0x00,0x00,0xe0,0x00,0x00,0x00,0x00,
                  0x00,0x00,0x00,0x00,0x01,0xf0,0x00,0x00,0x00,0x00,
                  0x00,0x00,0x00,0x00,0x03,0xf0,0x00,0x00,0x00,0x00,
                  0x00,0x00,0x00,0x00,0x03,0xf8,0x00,0x00,0x00,0x00,
                  0x00,0x00,0x00,0x00,0x07,0xf8,0x00,0x00,0x00,0x00,
                  0x00,0x00,0x00,0x00,0x0f,0xf8,0x00,0x00,0x00,0x00,
                  0x00,0x00,0x00,0x00,0x1f,0xfc,0x00,0x00,0x00,0x00,
                  0x00,0x00,0x00,0x00,0x1f,0xfc,0x00,0x00,0x00,0x00,
                  0x00,0x00,0x00,0x00,0x3f,0xfc,0x00,0x00,0x00,0x00,
                  0x00,0x00,0x00,0x00,0x7f,0xfe,0x00,0x00,0x00,0x00,
                  0x00,0x00,0x00,0x00,0x7f,0xfe,0x00,0x00,0x00,0x00,
                  0x00,0x00,0x00,0x00,0xff,0xfe,0x00,0x00,0x00,0x00,
                  0x00,0x00,0x00,0x01,0xff,0xff,0x00,0x00,0x00,0x00,
                  0x00,0x00,0x00,0x03,0xff,0xff,0x00,0x00,0x00,0x00,
                  0x00,0x00,0x00,0x03,0xff,0xff,0x00,0x00,0x00,0x00,
                  0x00,0x00,0x00,0x07,0xff,0xff,0x80,0x00,0x00,0x00,
                  0x00,0x00,0x00,0x07,0xff,0xff,0x80,0x00,0x00,0x00,
                  0x00,0x00,0x00,0x07,0xff,0xff,0x80,0x00,0x00,0x00,
                  0x00,0x00,0x00,0x0f,0xff,0xff,0x80,0x00,0x00,0x00,
                  0x00,0x00,0x00,0x0f,0xff,0xff,0x80,0x00,0x00,0x00,
                  0x7f,0xff,0xfc,0x0f,0xff,0xff,0x80,0x00,0x00,0x00,
                  0xff,0xff,0xff,0x0f,0xff,0xff,0x80,0x00,0x00,0x00,
                  0xff,0xff,0xff,0xcf,0xff,0xff,0x80,0x00,0x00,0x00,
                  0xff,0xff,0xff,0xef,0xff,0xff,0x80,0x00,0x00,0x00,
                  0x7f,0xff,0xff,0xf7,0xff,0xff,0x80,0x00,0x00,0x00,
                  0x3f,0xff,0xff,0xff,0xfb,0xff,0x00,0x00,0x00,0x00,
                  0x3f,0xff,0xff,0xff,0xf1,0xff,0x3f,0xf0,0x00,0x00,
                  0x1f,0xff,0xff,0xff,0xf1,0xfe,0xff,0xfe,0x00,0x00,
                  0x0f,0xff,0xff,0xff,0xf1,0xff,0xff,0xff,0xc0,0x00,
                  0x0f,0xff,0xff,0xff,0xe1,0xff,0xff,0xff,0xf8,0x00,
                  0x07,0xff,0xff,0xff,0xe1,0xff,0xff,0xff,0xff,0x00,
                  0x03,0xff,0xff,0xff,0xe1,0xff,0xff,0xff,0xff,0xc0,
                  0x01,0xff,0xff,0x3f,0xe1,0xff,0xff,0xff,0xff,0xe0,
                  0x01,0xff,0xfe,0x07,0xe3,0xff,0xff,0xff,0xff,0xe0,
                  0x00,0xff,0xff,0x03,0xe3,0xff,0xff,0xff,0xff,0xe0,
                  0x00,0x7f,0xff,0x00,0xf7,0xff,0xff,0xff,0xff,0xc0,
                  0x00,0x3f,0xff,0xc0,0xff,0xc0,0x7f,0xff,0xff,0x80,
                  0x00,0x1f,0xff,0xf0,0xff,0x00,0x3f,0xff,0xff,0x00,
                  0x00,0x0f,0xff,0xff,0xff,0x00,0x7f,0xff,0xfc,0x00,
                  0x00,0x07,0xff,0xff,0xff,0x01,0xff,0xff,0xf8,0x00,
                  0x00,0x01,0xff,0xff,0xff,0xff,0xff,0xff,0xf0,0x00,
                  0x00,0x00,0x7f,0xff,0xff,0xff,0xff,0xff,0xc0,0x00,
                  0x00,0x00,0x1f,0xfc,0x7f,0xff,0xff,0xff,0x80,0x00,
                  0x00,0x00,0x7f,0xf8,0x78,0xff,0xff,0xfe,0x00,0x00,
                  0x00,0x00,0xff,0xf0,0x78,0x7f,0xff,0xfc,0x00,0x00,
                  0x00,0x01,0xff,0xe0,0xf8,0x7f,0xff,0xf0,0x00,0x00,
                  0x00,0x03,0xff,0xc0,0xf8,0x3f,0xdf,0xc0,0x00,0x00,
                  0x00,0x07,0xff,0xc1,0xfc,0x3f,0xe0,0x00,0x00,0x00,
                  0x00,0x07,0xff,0x87,0xfc,0x1f,0xf0,0x00,0x00,0x00,
                  0x00,0x0f,0xff,0xcf,0xfe,0x1f,0xf8,0x00,0x00,0x00,
                  0x00,0x0f,0xff,0xff,0xff,0x1f,0xf8,0x00,0x00,0x00,
                  0x00,0x1f,0xff,0xff,0xff,0x1f,0xfc,0x00,0x00,0x00,
                  0x00,0x1f,0xff,0xff,0xff,0xff,0xfc,0x00,0x00,0x00,
                  0x00,0x1f,0xff,0xff,0xff,0xff,0xfe,0x00,0x00,0x00,
                  0x00,0x3f,0xff,0xff,0xff,0xff,0xfe,0x00,0x00,0x00,
                  0x00,0x3f,0xff,0xff,0xff,0xff,0xfe,0x00,0x00,0x00,
                  0x00,0x3f,0xff,0xff,0x3f,0xff,0xfe,0x00,0x00,0x00,
                  0x00,0x7f,0xff,0xff,0x3f,0xff,0xfe,0x00,0x00,0x00,
                  0x00,0x7f,0xff,0xff,0x3f,0xff,0xfe,0x00,0x00,0x00,
                  0x00,0x7f,0xff,0xfe,0x3f,0xff,0xfe,0x00,0x00,0x00,
                  0x00,0xff,0xff,0xfc,0x1f,0xff,0xfe,0x00,0x00,0x00,
                  0x00,0xff,0xff,0xf8,0x1f,0xff,0xfe,0x00,0x00,0x00,
                  0x00,0xff,0xff,0xe0,0x0f,0xff,0xfe,0x00,0x00,0x00,
                  0x01,0xff,0xff,0x80,0x07,0xff,0xfe,0x00,0x00,0x00,
                  0x01,0xff,0xfc,0x00,0x03,0xff,0xfe,0x00,0x00,0x00,
                  0x01,0xff,0xe0,0x00,0x01,0xff,0xfe,0x00,0x00,0x00,
                  0x01,0xff,0x00,0x00,0x00,0xff,0xfe,0x00,0x00,0x00,
                  0x00,0xf8,0x00,0x00,0x00,0x7f,0xfe,0x00,0x00,0x00,
                  0x00,0x00,0x00,0x00,0x00,0x1f,0xfe,0x00,0x00,0x00,
                  0x00,0x00,0x00,0x00,0x00,0x0f,0xfe,0x00,0x00,0x00,
                  0x00,0x00,0x00,0x00,0x00,0x07,0xfe,0x00,0x00,0x00,
                  0x00,0x00,0x00,0x00,0x00,0x01,0xfe,0x00,0x00,0x00,
                  0x00,0x00,0x00,0x00,0x00,0x00,0xfe,0x00,0x00,0x00,
                  0x00,0x00,0x00,0x00,0x00,0x00,0x7e,0x00,0x00,0x00,
                  0x00,0x00,0x00,0x00,0x00,0x00,0x1c,0x00,0x00,0x00
    };
    
    NSMutableData *commdata = [NSMutableData dataWithBytes:"\x1d\x76\x30\x00" length:4];
    [commdata appendBytes:"\x0a" length:1];
    [commdata appendBytes:"\x00" length:1];
    [commdata appendBytes:"\x4b" length:1];
    [commdata appendBytes:"\x00" length:1];
    [commdata appendBytes:&byte length:750];
    [_socket writeData:commdata withTimeout:COMM_TIME_OUT tag:2];*/
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
