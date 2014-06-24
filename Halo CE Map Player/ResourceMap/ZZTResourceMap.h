//
//  ZZTResourceMap.h
//  Mapper
//
//  Created by Paul Whitcomb on 6/22/14.
//  Copyright (c) 2014 Zero2. All rights reserved.
//

#ifndef Mapper_ZZTResourceMap_h
#define Mapper_ZZTResourceMap_h

typedef struct {
    uint32_t ce;
    uint32_t pc;
} RTranslator;

typedef struct {
    uint32_t version;
    uint32_t bitmapCount;
    uint32_t bitmapOffset;
    uint32_t soundCount;
    uint32_t soundOffset;
    uint32_t sizeOfMap;
} RMapHeader;

void *compileResourceMap(const RTranslator *bitmaps, const RTranslator *sounds, uint32_t bitmapsCount, uint32_t soundsCount);


#endif
