//
//  ESCPOSCore.h
//  ESCPOS
//
//  Created by Khaos Tian on 5/21/13.
//  Copyright (c) 2013 Oltica. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GCDAsyncSocket.h"

typedef NS_ENUM(NSInteger, BarCodeType) {
	BARCODE_UPC_A = 0,
	BARCODE_UPC_E,
    BARCODE_EAN13,
    BARCODE_EAN8,
    BARCODE_CODE39,
    BARCODE_ITF,
    BARCODE_NW7
};

typedef NS_ENUM(NSInteger, BarCodeTextPosition) {
	BARCODE_TXT_OFF = 0,
	BARCODE_TXT_ABV,
    BARCODE_TXT_BLW,
    BARCODE_TXT_BTH
};

typedef NS_ENUM(NSInteger, BackgroundColorType) {
	BGColorWhite = 0,
	BGColorBlack,
};

@protocol ESCPOSCoreDelegate
@optional

-(void)didConnectToHost:(NSString *)host;
-(void)didDisconnect;
-(void)setImageViewImage:(NSImage *)image;

@end

@interface ESCPOSCore : NSObject<GCDAsyncSocketDelegate>{
    GCDAsyncSocket  *_socket;
}

@property (nonatomic,assign)    id    delegate;
@property (nonatomic,readwrite) BOOL  connected;

+(ESCPOSCore *)CoreManager;

-(void)connectToAddress:(NSString *)address Delegate:(id)delegate;
-(void)disconnect;

-(void)changeBackgroundColor:(BackgroundColorType)color;
-(void)cutPaper;

-(void)printString:(NSString *)string;
-(void)printLeftString:(NSString *)lstring RightString:(NSString *)rstring;
-(void)printBarcode:(NSString *)string Type:(BarCodeType)type;
-(void)printBarcode:(NSString *)string Type:(BarCodeType)type Height:(int)height;
-(void)printBarcode:(NSString *)string Type:(BarCodeType)type Height:(int)height Width:(int)width Position:(BarCodeTextPosition)pos;
-(void)printImage:(NSImage *)image;

@end
