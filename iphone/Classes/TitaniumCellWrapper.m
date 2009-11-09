/**
 * Appcelerator Titanium Mobile
 * Copyright (c) 2009 by Appcelerator, Inc. All Rights Reserved.
 * Licensed under the terms of the Apache Public License
 * Please see the LICENSE included with this distribution for details.
 */

#import "TitaniumCellWrapper.h"
#import "TitaniumHost.h"
#import	"TitaniumBlobWrapper.h"
#import "UiModule.h"

#import "LayoutConstraint.h"
#import "WebFont.h"

typedef enum {
	LayoutEntryText,
	LayoutEntryImage,
	LayoutEntryButton,
} LayoutEntryType;

@interface LayoutEntry : NSObject
{
	LayoutEntryType type;
	LayoutConstraint constraint;
	TitaniumFontDescription labelFont;
	UIColor * textColor;
	NSString * name;
}

+ (LayoutEntry *) layoutWithDictionary: (NSDictionary *) layoutDict;

@property(nonatomic,readwrite,assign)	LayoutEntryType type;
@property(nonatomic,readwrite,assign)	LayoutConstraint constraint;
@property(nonatomic,readwrite,assign)	TitaniumFontDescription labelFont;
@property(nonatomic,readwrite,copy)		UIColor * textColor;
@property(nonatomic,readwrite,copy)		NSString * name;

@end

@implementation LayoutEntry
@synthesize type,constraint,labelFont,textColor,name;

+ (LayoutEntry *) layoutWithDictionary: (NSDictionary *) layoutDict;
{
	LayoutEntry * result = [[[self alloc] init] autorelease];
	
	return result;
}

@end







@implementation TitaniumCellWrapper
@synthesize jsonValues, templateCell;
@synthesize inputProxy,isButton, fontDesc, rowHeight;
@synthesize layoutArray, imageKeys;

- (id) init
{
	self = [super init];
	if (self != nil) {
		fontDesc.isBold=YES;
		fontDesc.size=15;
	}
	return self;
}

- (void) dealloc
{
	[imageKeys release];
	[layoutArray release];
	
	[templateCell release];
	[inputProxy release];

	[imagesCache release];
	[jsonValues release];
	[super dealloc];
}

- (NSString *) stringForKey: (NSString *) key;
{
	id result = [jsonValues objectForKey:key];

	//Okay, if it's blank, we default to the template. If there is no template, we get nil anyways.
	if(result == nil) return [templateCell stringForKey:key];

	if([result isKindOfClass:[NSString class]])return result;
	if ([result respondsToSelector:@selector(stringValue)])return [result stringValue];

	//If it's NSNull, then we want nil.
	return nil;
}

- (UIImage *) imageForKey: (NSString *) key;
{
	id result = [imagesCache objectForKey:key];

	//Okay, if it's blank, we default to the template. If there is no template, we get nil anyways.
	if(result == nil) return [templateCell imageForKey:key];

	if([result isKindOfClass:[NSURL class]]){
		TitaniumHost * theHost = [TitaniumHost sharedHost];
		UIImage * resultImage = [theHost imageForResource:result];
		if(resultImage!=nil)return resultImage;
		
		//Not a built-in or resource image. Consult the blobs.
		result = [theHost blobForUrl:result];
		if(result == nil)return nil; //Failed!
		[imagesCache setObject:result forKey:key];
		
		//This flows into the next if.
	}
	
	if([result isKindOfClass:[TitaniumBlobWrapper class]]){
		UIImage * resultImage = [(TitaniumBlobWrapper *)result imageBlob];
		if(resultImage!=nil)return resultImage;
		
		//Okay, we'll have to take a rain check.
		[result addObserver:self forKeyPath:@"imageBlob" options:NSKeyValueObservingOptionNew context:nil];
	}

	//If it's NSNull, then we want nil.
	return nil;
}

- (UIImage *) stretchableImageForKey: (NSString *) key;
{
	id result = [imagesCache objectForKey:key];

	//Okay, if it's blank, we default to the template. If there is no template, we get nil anyways.
	if(result == nil) return [templateCell stretchableImageForKey:key];

	if([result isKindOfClass:[NSURL class]]){
		TitaniumHost * theHost = [TitaniumHost sharedHost];
		UIImage * resultImage = [theHost stretchableImageForResource:result];
		if(resultImage!=nil)return resultImage;
	}

	//If it's NSNull, then we want nil.
	return nil;
}


- (NSString *) title;
{
	return [self stringForKey:@"title"];
}

- (NSString *) html;
{
	return [self stringForKey:@"html"];
}

- (NSString *) name;
{
	return [self stringForKey:@"name"];
}

- (NSString *) value;
{
	return [self stringForKey:@"value"];
}

- (UIImage *) image;
{
	return [self imageForKey:@"image"];
}

- (UIFont *) font;
{
	return FontFromDescription(&fontDesc);
}

- (NSString *) stringValue;
{
	NSMutableString * result = [NSMutableString stringWithString:@"{"];
	SBJSON * packer = [[SBJSON alloc] init];
	
	Class blobClass = [TitaniumBlobWrapper class];
	Class urlClass = [NSURL class];
	
	BOOL needsComma=NO;
	
	for (NSString * thisKey in jsonValues) {
		id thisValue = [imagesCache objectForKey:thisKey];
		if (thisValue == nil) {
			thisValue = [jsonValues objectForKey:thisKey];
		}
		
		if([thisValue isKindOfClass:blobClass]){
			thisValue = [thisValue virtualUrl];
		}else if ([thisValue isKindOfClass:urlClass]) {
			thisValue = [thisValue absoluteURL];
		}
		
		if (needsComma) {
			[result appendString:@","];
		}
		
		[result appendFormat:@"%@:%@",[packer stringWithFragment:thisKey error:nil],
				[packer stringWithFragment:thisValue error:nil]];
		needsComma = YES;
	}

	[result appendString:@"}"];

	return result;
}

- (UITableViewCellAccessoryType) accessoryType;
{
	SEL boolSel = @selector(boolValue);

	NSNumber * hasDetail = [jsonValues objectForKey:@"hasDetail"];
	if ([hasDetail respondsToSelector:boolSel] && [hasDetail boolValue]){
		return UITableViewCellAccessoryDetailDisclosureButton;
	}

	NSNumber * hasChild = [jsonValues objectForKey:@"hasChild"];
	if ([hasChild respondsToSelector:boolSel] && [hasChild boolValue]){
		return UITableViewCellAccessoryDisclosureIndicator;
	}
	
	NSNumber * isSelected = [jsonValues objectForKey:@"selected"];
	if ([isSelected respondsToSelector:boolSel] && [isSelected boolValue]){
		return UITableViewCellAccessoryCheckmark;
	}

	return UITableViewCellAccessoryNone;
}

- (void) setAccessoryType:(UITableViewCellAccessoryType) newType;
{
	NSNumber * falseNum = [NSNumber numberWithBool:NO];

	[jsonValues setObject:((newType==UITableViewCellAccessoryDetailDisclosureButton)?
						   [NSNumber numberWithBool:YES]:falseNum) forKey:@"hasDetail"];

	[jsonValues setObject:((newType==UITableViewCellAccessoryDisclosureIndicator)?
						   [NSNumber numberWithBool:YES]:falseNum) forKey:@"hasChild"];

	[jsonValues setObject:((newType==UITableViewCellAccessoryCheckmark)?
						   [NSNumber numberWithBool:YES]:falseNum) forKey:@"selected"];

}



- (void) noteImage: (NSString *)key relativeToUrl: (NSURL *) baseUrl;
{
	id oldImageEntry = [imagesCache objectForKey:key];
	id jsonEntry = [jsonValues objectForKey:key];

//Okay, first make sure we don't already have this.

//First check to see if they're both null, or both the same datablob.
	if(oldImageEntry==jsonEntry)return;

//Okay, try it being a relative string.
	if ([jsonEntry isKindOfClass:[NSString class]]) {
		NSURL * newImageUrl = [[NSURL URLWithString:jsonEntry relativeToURL:baseUrl] absoluteURL];
		if([newImageUrl isEqual:oldImageEntry])return;
		
		if ([oldImageEntry isKindOfClass:[TitaniumBlobWrapper class]] && 
				([newImageUrl isEqual:[oldImageEntry url]] ||
				[[newImageUrl absoluteString] isEqual:[oldImageEntry virtualUrl]])){
			return; //The old entry contains the url already.
		}
		//Okay, this is a new url. Update it.
		[imagesCache setObject:newImageUrl forKey:key];
		return;

	}
	
	if ([jsonEntry isKindOfClass:[TitaniumBlobWrapper class]]){
		[imagesCache setObject:jsonEntry forKey:key];
		return;
	}
	
	if(jsonEntry == [NSNull null]){
		[imagesCache setObject:[NSNull null] forKey:key];
		return;
	}
	
	//No image!
	[imagesCache removeObjectForKey:key];
}



- (void) useProperties: (NSDictionary *) propDict withUrl: (NSURL *) baseUrl;
{
	[self willChangeValueForKey:@"jsonValues"];
	if (jsonValues != nil) {
		[jsonValues removeAllObjects];
		[jsonValues addEntriesFromDictionary:propDict];
	} else {
		jsonValues = [propDict mutableCopy];
	}
	[self didChangeValueForKey:@"jsonValues"];

	NSArray * newlayoutArray = [propDict objectForKey:@"layout"];
	if ([newlayoutArray isKindOfClass:[NSArray class]]) {
		if (layoutArray != nil) {
			[layoutArray removeAllObjects];
		} else {
			layoutArray = [[NSMutableArray alloc] initWithCapacity:[newlayoutArray count]];
		}
		
		//Generate actual layoutArray and image Keys from layoutArray.
		
	} else {
		[layoutArray release];
		
		NSMutableSet * templateKeys;
		if (newlayoutArray==(id)[NSNull null]) {
			layoutArray = (id)[NSNull null];
			templateKeys = nil;
		} else {
			layoutArray = nil;
			templateKeys = [templateCell imageKeys];
		}

		if(templateKeys == nil){
			if (imageKeys == nil) {
				imageKeys = [[NSMutableSet alloc] initWithObjects:@"image",nil];
			} else {
				[imageKeys removeAllObjects];
				[imageKeys addObject:@"image"];
			}
		} else {
			[imageKeys release];
			imageKeys = [templateKeys mutableCopy];
		}
	}


	NSArray * oldKeys = [imagesCache allKeys];
	for (NSString * thisKey in oldKeys) {
		if([imageKeys containsObject:thisKey])continue;
		
		[imagesCache removeObjectForKey:thisKey];
	}

	if (imagesCache==nil) {
		[self willChangeValueForKey:@"imagesCache"];
		imagesCache = [[NSMutableDictionary alloc] init];
		[self didChangeValueForKey:@"imagesCache"];
	}
	
	
	for (NSString * thisKey in imageKeys) {
		[self noteImage:@"image" relativeToUrl:baseUrl];
	}


	Class stringClass = [NSString class];

	NSString * rowType = [propDict objectForKey:@"type"];
	if ([rowType isKindOfClass:stringClass]){
		isButton = [rowType isEqualToString:@"button"];
	} else isButton = NO;
	
	
	id rowHeightObject = [propDict objectForKey:@"rowHeight"];
	if ([rowHeightObject respondsToSelector:@selector(floatValue)]) rowHeight = [rowHeightObject floatValue];
	else rowHeight = 0;
	
	NSDictionary * inputProxyDict = [propDict objectForKey:@"input"];
	if ([inputProxyDict isKindOfClass:[NSDictionary class]]){
		UiModule * theUiModule = (UiModule *)[[TitaniumHost sharedHost] moduleNamed:@"UiModule"];
		NativeControlProxy * thisInputProxy = [theUiModule proxyForObject:inputProxyDict scan:YES recurse:YES];
		if (thisInputProxy != nil) [self setInputProxy:thisInputProxy];
	} else [self setInputProxy:nil];
	
	UpdateFontDescriptionFromDict(propDict, &fontDesc);
}


@end
