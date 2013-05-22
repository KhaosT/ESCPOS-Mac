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
    [self printBarcode:string Type:type Height:100 Width:3 Position:BARCODE_TXT_BLW];
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

-(void)printImage:(NSImage *)image
{
    NSBitmapImageRep *imageRep = [[image representations] lastObject];
    
	if ( ![imageRep isKindOfClass:[NSBitmapImageRep class]] ) // sanity check
		return;
    
	int pixelsWide = (int)[imageRep pixelsWide];
	int pixelsHigh = (int)[imageRep pixelsHigh];
        
    NSMutableData *commdata = [NSMutableData dataWithBytes:"\x1d\x76\x30\x00" length:4];
    [commdata appendBytes:"\x08" length:1];
    [commdata appendBytes:"\x00" length:1];
    [commdata appendBytes:"\x4B" length:1];
    [commdata appendBytes:"\x00" length:1];
    
	for ( NSUInteger x = 0; x < pixelsWide; x++ )
	{
		for ( NSUInteger y = 0; y < pixelsHigh; y++ )
		{
			NSColor *color = [imageRep colorAtX:x y:y];
			if ( color.redComponent != 0 )
			{
				[commdata appendBytes:"\xff" length:1];
			}else{
                [commdata appendBytes:"\x00" length:1];
            }
		}
	}
    //[_socket writeData:commdata withTimeout:COMM_TIME_OUT tag:2];
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
