/*
 Copyright (c) 2009, OpenEmu Team
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
     * Redistributions of source code must retain the above copyright
       notice, this list of conditions and the following disclaimer.
     * Redistributions in binary form must reproduce the above copyright
       notice, this list of conditions and the following disclaimer in the
       documentation and/or other materials provided with the distribution.
     * Neither the name of the OpenEmu Team nor the
       names of its contributors may be used to endorse or promote products
       derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY OpenEmu Team ''AS IS'' AND ANY
 EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL OpenEmu Team BE LIABLE FOR ANY
 DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "GameDocument.h"
#import "OECorePlugin.h"
#import "GameDocumentController.h"
#import "GameAudio.h"
#import "OEGameLayer.h"
#import "GameCore.h"
#import "OEGameCoreController.h"
#import "GameQTRecorder.h"
@implementation GameDocument

@synthesize gameCore;
@synthesize gameWindow;
@synthesize emulatorName;

- (NSString *)windowNibName
{
    // Override returning the nib file name of the document
    // If you need to use a subclass of NSWindowController or if your document supports multiple NSWindowControllers, you should remove this method and override -makeWindowControllers instead.
    return @"GameDocument";
}

static void OE_bindGameLayer(OEGameLayer *gameLayer)
{
    NSUserDefaultsController *ctrl = [NSUserDefaultsController sharedUserDefaultsController];
    [gameLayer bind:@"filterName"   toObject:ctrl withKeyPath:@"values.filterName" options:nil];
    [gameLayer bind:@"vSyncEnabled" toObject:ctrl withKeyPath:@"values.vsync"      options:nil];
}

- (void)windowControllerDidLoadNib:(NSWindowController *) aController
{        
    [gameCore setupEmulation];
    
    [gameWindow makeFirstResponder:view];
    [gameWindow setAcceptsMouseMovedEvents:YES];
    [view setNextResponder:gameCore];
    
    //recorder = [[GameQTRecorder alloc] initWithGameCore:gameCore];
    //Setup Layer hierarchy
    rootLayer = [CALayer layer];
        
    rootLayer.layoutManager = [CAConstraintLayoutManager layoutManager];
    rootLayer.backgroundColor = CGColorCreateGenericRGB(0.0f,0.0f, 0.0f, 1.0f);
    
    //Show the layer
    [view setLayer:rootLayer];
    [view setWantsLayer:YES];
        
    gameLayer = [OEGameLayer layer];
    [gameLayer setDocController:[GameDocumentController sharedDocumentController]];
    OE_bindGameLayer(gameLayer);
    
    [gameLayer setOwner:self];
    
    [gameLayer setGameCore:gameCore];
     
    gameLayer.name = @"game";
    gameLayer.frame = CGRectMake(0,0,1,1);
    [gameLayer addConstraint:[CAConstraint constraintWithAttribute:kCAConstraintMidX relativeTo:@"superlayer" attribute:kCAConstraintMidX]];
    [gameLayer addConstraint:[CAConstraint constraintWithAttribute:kCAConstraintMidY relativeTo:@"superlayer" attribute:kCAConstraintMidY]];
    
    rootLayer.bounds = CGRectMake(0, 0, [gameCore screenWidth],  [gameCore screenHeight]);
    gameLayer.bounds = CGRectMake(0, 0, [gameCore screenWidth],  [gameCore screenHeight]);
    //Add the NESLayer to the hierarchy
    [rootLayer addSublayer:gameLayer];
    
    // we probably want to set this to yes, and implement 
    // -(BOOL)canDrawInCGLContext:(CGLContextObj)glContext pixelFormat:(CGLPixelFormatObj)pixelFormat forLayerTime:(CFTimeInterval)timeInterval displayTime:(const CVTimeStamp *)timeStamp
    // in our OEGameLayer
    gameLayer.asynchronous = YES;
    
        
    // FIXME: possible leak
    audio = [[GameAudio alloc] initWithCore:gameCore];
    
    [audio bind:@"volume"
       toObject:[NSUserDefaultsController sharedUserDefaultsController]
    withKeyPath:@"values.volume"
        options:nil];
    
    [audio startAudio];
    
//    if([gameCore respondsToSelector:@selector(outputSize)])
  //     aspect = [gameCore outputSize];
    //else
    //CGSize aspect = NSMakeSize([gameCore screenWidth], [gameCore screenHeight]);
    [gameWindow setContentSize:NSMakeSize([gameCore screenWidth], [gameCore screenHeight])];
    //[gameWindow setContentResizeIncrements:aspect];
    [rootLayer setNeedsLayout];
    
    [gameCore startEmulation];    

    //[recorder startRecording];
    [gameWindow makeKeyAndOrderFront:self];
    
    if([self defaultsToFullScreenMode])
        [self toggleFullScreen:self];
   
}

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError
{
    if (outError != NULL)
        *outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:unimpErr userInfo:NULL];
    return nil;
}

- (BOOL)readFromURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError
{
    NSLog(@"%@",self);
    
    GameDocumentController *docControl = [GameDocumentController sharedDocumentController];
    OECorePlugin *plugin = [docControl pluginForType:typeName];
    emulatorName = [[plugin displayName] retain];
    gameCore = [[plugin controller] newGameCoreWithDocument:self];
    NSLog(@"gameCore class: %@", [gameCore class]);
    [gameWindow makeFirstResponder:gameCore];
     
    if ([gameCore loadFileAtPath:[absoluteURL path]]) return YES;
    NSLog(@"Incorrect file");
    if (outError) *outError = [[NSError alloc] initWithDomain:@"Bad file" code:0 userInfo:nil];
    return NO;
}

- (void)refresh
{    
   // [gameLayer setNeedsDisplay];
}

- (BOOL)backgroundPauses
{
    return [[[NSUserDefaultsController sharedUserDefaultsController] valueForKeyPath:@"values.backgroundPause"] boolValue];
}

- (BOOL)defaultsToFullScreenMode
{
    return [[[NSUserDefaultsController sharedUserDefaultsController] valueForKeyPath:@"values.fullScreen"] boolValue];
}

- (BOOL)isEmulationPaused
{
    return [gameCore isEmulationPaused];
}

- (void)setPauseEmulation:(BOOL)flag
{
    [gameCore setPauseEmulation:flag];
    if(flag) [audio pauseAudio];
    else     [audio startAudio];
}

- (void)windowDidBecomeKey:(NSNotification *)notification
{
    GameDocumentController* docControl = [GameDocumentController sharedDocumentController];
    [docControl setGameLoaded:YES];
    [self setPauseEmulation:NO];
}

- (void)windowDidResignKey:(NSNotification *)notification
{
    if(gameCore != nil && [self backgroundPauses])
    {
        if(![self isFullScreen])
        {
            @try {
                [self setPauseEmulation:YES];
            }
            @catch (NSException * e) {
                NSLog(@"Failed to pause");
            }
        }
    }
}

- (NSSize)windowWillResize:(NSWindow *)sender toSize:(NSSize)proposedFrameSize
{
    
    //we want to force aspect ratio with resize increments
    int scale;
    if( proposedFrameSize.width < proposedFrameSize.height )
        scale = proposedFrameSize.width /[gameCore screenWidth];
    else
        scale = proposedFrameSize.height /[gameCore screenHeight];
    scale = MAX(scale, 1);
    
    NSRect newContentRect = NSMakeRect(0,0, [gameCore screenWidth] * scale, [gameCore screenHeight] * scale);
    return [sender frameRectForContentRect:newContentRect].size;
}

- (void)windowDidResize:(NSNotification *)notification
{
    //adjust the window to zoom from the center
    if ([gameWindow isZoomed])
        [gameWindow center];
    
    [gameLayer setNeedsDisplay];
}

- (void)windowWillClose:(NSNotification *)notification
{
    if([view isInFullScreenMode])
        [view exitFullScreenModeWithOptions:nil];
    [gameCore stopEmulation];
    [audio stopAudio];
    [gameCore release];
    gameCore = nil;
    
    //[recorder finishRecording];
    [gameLayer setDocController:nil];
    GameDocumentController* docControl = [GameDocumentController sharedDocumentController];
    [docControl setGameLoaded:NO];
}

- (void)performClose:(id)sender
{
    [gameWindow performClose:sender];
}
    
- (BOOL)isFullScreen
{
    return [view isInFullScreenMode];
}

- (IBAction)toggleFullScreen:(id)sender
{
    [self setPauseEmulation:YES];
    if(![view isInFullScreenMode])
    {
        [view enterFullScreenMode:[[view window] screen]
                      withOptions:[NSDictionary dictionaryWithObjectsAndKeys:
                                   [NSNumber numberWithBool:NO], NSFullScreenModeAllScreens,
                                   [NSNumber numberWithInt:0], NSFullScreenModeWindowLevel, nil]];
        [NSCursor hide];
    }
    else
    {
        [view exitFullScreenModeWithOptions:nil];           
        [NSCursor unhide];
    }
    [self setPauseEmulation:NO];
    [[view window] makeFirstResponder:gameCore];
}

- (IBAction)saveState:(id)sender
{
    [[NSSavePanel savePanel] beginSheetForDirectory:nil
                                               file:nil 
                                     modalForWindow:gameWindow
                                      modalDelegate:self
                                     didEndSelector:@selector(savePanelDidEnd:returnCode:contextInfo:)
                                        contextInfo:NULL];
}

- (void)saveStateToFile:(NSString *)fileName
{
    if([gameCore respondsToSelector:@selector(saveStateToFileAtPath:)])
        [gameCore saveStateToFileAtPath: fileName];
}

- (void)savePanelDidEnd:(NSSavePanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
    if(returnCode == NSOKButton) [self saveStateToFile:[sheet filename]];
}

- (IBAction)loadState:(id)sender
{
    [[NSOpenPanel openPanel] beginSheetForDirectory:nil
                                               file:nil
                                     modalForWindow:gameWindow
                                      modalDelegate:self
                                     didEndSelector:@selector(openPanelDidEnd:returnCode:contextInfo:)
                                        contextInfo:NULL];
}

- (void)openPanelDidEnd:(NSOpenPanel *)panel returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
    if(returnCode == NSOKButton) [self loadStateFromFile:[panel filename]];
}

- (void)loadStateFromFile:(NSString *)fileName
{
    if([gameCore respondsToSelector:@selector(loadStateFromFileAtPath:)])
        [gameCore loadStateFromFileAtPath: fileName];
}

- (IBAction)scrambleRam:(id)sender
{
    [self scrambleBytesInRam:100];
}

- (void)scrambleBytesInRam:(NSUInteger)bytes
{
    for(NSUInteger i = 0; i < bytes; i++)
        [gameCore setRandomByte];
}

- (IBAction)resetGame:(id)sender
{
    [gameCore resetEmulation];
}

- (IBAction)pauseGame:(id)sender
{
    if([self isEmulationPaused])
    {
        [self setPauseEmulation:NO];
        [sender setImage:[NSImage imageNamed:NSImageNameStopProgressTemplate]];
        [sender setLabel:@"Pause"];
    }
    else
    {
        [self setPauseEmulation:YES];
        [sender setImage:[NSImage imageNamed:NSImageNameRightFacingTriangleTemplate]];
        [sender setLabel:@"Play"];
    }
}

- (NSImage*)screenShot
{
    return [gameLayer imageForCurrentFrame];
}

@end
