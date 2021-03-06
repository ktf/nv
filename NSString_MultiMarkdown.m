//
//  NSString_MultiMarkdown.m
//  Notation
//
//  Created by Christian Tietze on 2010-10-10.
//

#import "NSString_MultiMarkdown.h"
#import "PreviewController.h"
#import "AppController.h"

@implementation NSString (MultiMarkdown)

/**
 * Locating a MultiMarkdown parsing script.  The options are as follows:
 *   1.  ~/Library/Application Support/MultiMarkdown/bin/mmd2ZettelXHTML.pl
 *   2.  ~/Library/Application Support/MultiMarkdown/bin/mmd2XHTML.pl
 *   3.  <Application>/MultiMarkdown/bin/mmd2ZettelXHTML.pl
 *
 * The third option should be a safe fallback since the appropriate MMD bundle
 * is included and shipped with this application.
 */
+(NSString*)mmdDirectory {
    // fallback path in this program's directiory
    NSString *bundlePath = [[[[[NSBundle mainBundle] resourcePath] 
                              stringByAppendingPathComponent:@"MultiMarkdown"] 
                             stringByAppendingPathComponent:@"bin"] 
                            stringByAppendingPathComponent:@"mmd2ZettelXHTML.pl"];
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    
    if ([paths count] > 0) {
        NSString *path = [[[paths objectAtIndex:0] 
                           stringByAppendingPathComponent:@"MultiMarkdown"] 
                          stringByAppendingPathComponent:@"bin"];
        NSFileManager *mgr = [NSFileManager defaultManager];
        NSString *mmdZettel = [path stringByAppendingPathComponent:@"mmd2ZettelXHTML.pl"];
        NSString *mmdDefault = [path stringByAppendingPathComponent:@"mmd2XHTML.pl"];
        
        if ([mgr fileExistsAtPath:mmdZettel]) {
            return mmdZettel;
        } else if ([mgr fileExistsAtPath:mmdDefault]) {
            return mmdDefault;
        }
    }
    
    return bundlePath;
} // mmdDirectory

+(NSString*)processMultiMarkdown:(NSString*)inputString
{
	NSString* mdScriptPath = [[self class] mmdDirectory];
    
	NSTask* task = [[[NSTask alloc] init] autorelease];
	NSMutableArray* args = [NSMutableArray array];
	
	[task setArguments:args];
	
	NSPipe* stdinPipe = [NSPipe pipe];
	NSPipe* stdoutPipe = [NSPipe pipe];
	NSFileHandle* stdinFileHandle = [stdinPipe fileHandleForWriting];
	NSFileHandle* stdoutFileHandle = [stdoutPipe fileHandleForReading];
	
	[task setStandardInput:stdinPipe];
	[task setStandardOutput:stdoutPipe];
	
	[task setLaunchPath: [mdScriptPath stringByExpandingTildeInPath]];
	[task launch];
	
	[stdinFileHandle writeData:[inputString dataUsingEncoding:NSUTF8StringEncoding]];
	[stdinFileHandle closeFile];
	
	NSData* outputData = [stdoutFileHandle readDataToEndOfFile];
	NSString* outputString = [[[NSString alloc] initWithData:outputData encoding:NSUTF8StringEncoding] autorelease];
	[stdoutFileHandle closeFile];
	
	[task waitUntilExit];
	
	return outputString;
	
}

+(NSString*)documentWithProcessedMultiMarkdown:(NSString*)inputString
{
    AppController *app = [[NSApplication sharedApplication] delegate];
	NSString *rawString = [@"format: snippet\n\n" stringByAppendingString:inputString]; 
    NSString *processedString = [self processMultiMarkdown:rawString];
	NSString *htmlString = [[PreviewController class] html];
	NSString *cssString = [[PreviewController class] css];
	NSMutableString *outputString = [NSMutableString stringWithString:(NSString *)htmlString];
	NSString *noteTitle =  ([app selectedNoteObject]) ? [NSString stringWithFormat:@"%@",titleOfNote([app selectedNoteObject])] : @"";
	
	NSString *nvSupportPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/Notational Velocity"];
	[outputString replaceOccurrencesOfString:@"{%support%}" withString:nvSupportPath options:0 range:NSMakeRange(0, [outputString length])];
	[outputString replaceOccurrencesOfString:@"{%title%}" withString:noteTitle options:0 range:NSMakeRange(0, [outputString length])];
	[outputString replaceOccurrencesOfString:@"{%content%}" withString:processedString options:0 range:NSMakeRange(0, [outputString length])];
	[outputString replaceOccurrencesOfString:@"{%style%}" withString:cssString options:0 range:NSMakeRange(0, [outputString length])];

	return outputString;
}

+(NSString*)xhtmlWithProcessedMultiMarkdown:(NSString*)inputString
{
	AppController *app = [[NSApplication sharedApplication] delegate];
	NSString *noteTitle =  ([app selectedNoteObject]) ? [NSString stringWithFormat:@"%@",titleOfNote([app selectedNoteObject])] : @"";
	inputString = [[NSString stringWithFormat:@"format: complete\ntitle: %@\n\n",noteTitle] stringByAppendingString:inputString];
	return [self processMultiMarkdown:inputString];
}

+(NSString*)stringWithProcessedMultiMarkdown:(NSString*)inputString
{
	inputString = [@"format: snippet\n\n" stringByAppendingString:inputString];
	return [self processMultiMarkdown:inputString];
} // stringWithProcessedMultiMarkdown:

@end // NSString (MultiMarkdown)
