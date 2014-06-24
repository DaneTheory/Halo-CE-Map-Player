//
//  ZZTResourceMap.c
//  Mapper
//
//  Created by Paul Whitcomb on 6/22/14.
//  Copyright (c) 2014 Zero2. All rights reserved.
//

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#import "ZZTResourceMap.h"

void *compileResourceMap(const RTranslator *bitmaps, const RTranslator *sounds, uint32_t bitmapsCount, uint32_t soundsCount) {
    RMapHeader header;
    header.version = 1;
    header.bitmapCount = bitmapsCount;
    header.soundCount = soundsCount;
    
    header.sizeOfMap = sizeof(RMapHeader) + (bitmapsCount + soundsCount) * sizeof(RTranslator);
    
    header.bitmapOffset = sizeof(RMapHeader);
    header.soundOffset = header.bitmapOffset + sizeof(RTranslator) * bitmapsCount;
    
    void *map = malloc(header.sizeOfMap);
    memcpy(map,&header,sizeof(header));
    memcpy(map + header.bitmapOffset,bitmaps,bitmapsCount * sizeof(RTranslator));
    memcpy(map + header.soundOffset,sounds,soundsCount * sizeof(RTranslator));
    return map;
}