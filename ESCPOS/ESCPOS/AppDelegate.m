//
//  AppDelegate.m
//  ESCPOS
//
//  Created by Khaos Tian on 5/21/13.
//  Copyright (c) 2013 Oltica. All rights reserved.
//

#import "AppDelegate.h"

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [[NSNotificationCenter defaultCenter]addObserverForName:NSControlTextDidChangeNotification object:_addressField queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        if (_addressField.stringValue.length>0) {
            [_conntectButton setEnabled:YES];
        }else{
            [_conntectButton setEnabled:NO];
        }
    }];
    // Insert code here to initialize your application
}

- (IBAction)Connect:(id)sender {
    if (![[ESCPOSCore CoreManager]connected]) {
        [[ESCPOSCore CoreManager]connectToAddress:_addressField.stringValue Delegate:self];
    }else{
        [[ESCPOSCore CoreManager]disconnect];
    }
}

- (IBAction)PrintTest:(id)sender {
    [[ESCPOSCore CoreManager]printString:_ContentField.stringValue];
    _ContentField.stringValue = @"";
}

- (IBAction)CutPaperButton:(id)sender {
    [[ESCPOSCore CoreManager]cutPaper];
}

- (IBAction)PrintBarCode:(id)sender {
    [[ESCPOSCore CoreManager]printBarcode:_ContentField.stringValue Type:_BarCodeSelector.indexOfSelectedItem Height:_BarCodeSize.intValue];
     _ContentField.stringValue = @"";
}

- (IBAction)BarCodeSizeDidChange:(id)sender {
    [_BarCodeSizeDisplay setStringValue:[NSString stringWithFormat:@"%i",_BarCodeSize.intValue]];
}

- (IBAction)printImageAct:(id)sender {
    [[ESCPOSCore CoreManager]printImage:_ImageView.image];
    [_RePrintButton setEnabled:YES];
}

- (IBAction)printLeftRight:(id)sender {
    [[ESCPOSCore CoreManager]printLeftString:_ContentField.stringValue RightString:[NSString stringWithFormat:@"%i",_BarCodeSize.intValue]];
    _ContentField.stringValue = @"";
}

- (IBAction)printQRCode:(id)sender {
    [[ESCPOSCore CoreManager]printQRCode:_ContentField.stringValue withDimension:_BarCodeSize.intValue];
    _ContentField.stringValue = @"";
}

-(void)setImageViewImage:(NSImage *)image
{
    [_ImageView setImage:image];
}

- (void)didConnectToHost:(NSString *)host
{
    [_TestButton setEnabled:YES];
    [_ContentField setEnabled:YES];
    [_QRButton setEnabled:YES];
    [_BarCodeButton setEnabled:YES];
    [_PLRButton setEnabled:YES];
    [_PaperCutButton setEnabled:YES];
    [_ImageView setEnabled:YES];
    [_ImageView setEditable:YES];
    [_conntectButton setTitle:@"Disconnect"];
}

- (void)didDisconnect
{
    [_TestButton setEnabled:NO];
    [_ContentField setEnabled:NO];
    [_RePrintButton setEnabled:NO];
    [_QRButton setEnabled:NO];
    [_BarCodeButton setEnabled:NO];
    [_PLRButton setEnabled:NO];
    [_PaperCutButton setEnabled:NO];
    [_ImageView setEnabled:NO];
    [_ImageView setEditable:NO];
    [_conntectButton setTitle:@"Connect"];
}

@end
