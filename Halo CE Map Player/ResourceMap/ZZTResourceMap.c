//  ZZTResourceMap.c

/*
 
 Copyright (c) 2014, Paul Whitcomb
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Paul Whitcomb nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS
 BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 
 */

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