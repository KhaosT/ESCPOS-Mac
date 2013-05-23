//
//  AppDelegate.h
//  ESCPOS
//
//  Created by Khaos Tian on 5/21/13.
//  Copyright (c) 2013 Oltica. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "ESCPOSCore.h"

@interface AppDelegate : NSObject <NSApplicationDelegate,NSTextFieldDelegate,ESCPOSCoreDelegate>

@property (assign) IBOutlet NSWindow *window;
@property (weak) IBOutlet NSTextField *addressField;
@property (weak) IBOutlet NSButton *conntectButton;
@property (weak) IBOutlet NSButton *TestButton;
@property (weak) IBOutlet NSTextField *ContentField;
@property (weak) IBOutlet NSComboBox *BarCodeSelector;
@property (weak) IBOutlet NSSlider *BarCodeSize;
@property (weak) IBOutlet NSTextField *BarCodeSizeDisplay;
@property (weak) IBOutlet NSImageView *ImageView;
@property (weak) IBOutlet NSButton *BarCodeButton;
@property (weak) IBOutlet NSButton *PLRButton;
@property (weak) IBOutlet NSButton *PaperCutButton;
@property (weak) IBOutlet NSButton *QRButton;
@property (weak) IBOutlet NSButton *RePrintButton;

- (IBAction)Connect:(id)sender;
- (IBAction)PrintTest:(id)sender;
- (IBAction)CutPaperButton:(id)sender;
- (IBAction)PrintBarCode:(id)sender;
- (IBAction)BarCodeSizeDidChange:(id)sender;
- (IBAction)printImageAct:(id)sender;
- (IBAction)printLeftRight:(id)sender;
- (IBAction)printQRCode:(id)sender;

@end
