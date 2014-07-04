//  ZZTHCEReader.m

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

#import "ZZTHCEReader.h"
#import "ZZTHaloMemory.h"
#import "mach_override.h"
#import "ZZTDeathstar.h"
#import "ZZTTagData.h"
#import "ZZTResourceMap.h"

#define THIS_BUNDLE [NSBundle bundleWithIdentifier:@"me.zero2.Halo-CE-Map-Player"]

@implementation ZZTHCEReader

static void setupIncyclopedia();
static void setupDataOfTag(Tag tag, Tag *loadedTag, Tag *ownTags, uint32_t ownTagsCount);

static bool fixMap = true;

static MapData map;
static Tag *tags;
static uint32_t tagCount;
static void *fakeTag;
static bool *tagSetupAlready;
static int64_t incyMagic;
static void *resourceMap;
static void *resourceMapMp;

static HaloMapHeader *loadedheader = (HaloMapHeader *)(0x3AD204);

typedef struct {
    uint32_t signature; //0x0
    uint16_t width; //0x4
    uint16_t height; //0x6
    uint16_t depth; //0x8
    uint16_t type; //0xA
    uint16_t format; //0xC
    uint16_t flags; //0xE
    uint16_t x; //0x10
    uint16_t y; //0x12
    uint16_t mipmapCount; //0x14
    uint16_t padding; //0x16
    uint32_t pixelOffset; //0x18
    uint32_t pixelCount; //0x1C
    uint32_t uk8; //0x20
    uint32_t uk9; //0x24
    uint32_t uk10; //0x28
    uint32_t ul11; //0x2C
} __attribute__((packed)) BitmTagBitmap; //0x30

typedef struct {
    char name[0x20]; //0x0
    float skipFraction; //0x20
    float gain; //0x24
    uint16_t compression; //0x28
    uint16_t nextPermutation; //0x2A
    char padding[0x14]; //0x2C
    uint32_t samples; //0x40
    uint32_t flags; //0x44
    uint32_t offset; //0x48
    char padding1[0x8]; //0x44
    uint32_t mouthdata; //0x54
    char padding2[0x10]; //0x58
    uint32_t subtitleData; //0x68
    char padding3[0x10];
} __attribute__((packed)) SndRangePermutation;

typedef enum {
    RES_BITM,
    RES_SND
} HCEResourceType;

typedef enum {
    MAP_CE = 0x261,
    MAP_PC = 0x7,
    MAP_DEMO = 0x6
} HaloMapVersion;

static uint32_t translateResource(uint32_t ceOffset, HCEResourceType type);

static void *(*doStuff)(void *a, void *b, void *c, void *d, void *e, void *f, void *g, void *h) = NULL;
static void *overrideStuff(void *a, void *b, void *c, void *d, void *e, void *f, void *g, void *h) {
    //I don't know what this does, but Halo calls this before reading the map
    void *returnValue = doStuff(a,b,c,d,e,f,g,h);
    
    if(fixMap && *(uint32_t *)(0x3AD208) != MAP_PC) {
        fixMap = false;
        setupIncyclopedia();
        
        //do z-team deprotection
        void *fakeMap = malloc(sizeof(HaloMapHeader) + loadedheader->metaSize);
        memcpy(fakeMap,loadedheader,sizeof(*loadedheader));
        void *indexMemoryOffset = (void *)0x40440000;
        memcpy(fakeMap + sizeof(*loadedheader),indexMemoryOffset,loadedheader->metaSize);
        HaloMapHeader *fakeHeader = (HaloMapHeader *)fakeMap;
        fakeHeader->indexOffset = sizeof(*loadedheader);
        fakeHeader->length = fakeHeader->indexOffset + fakeHeader->metaSize;
        HaloMapIndex *fakeIndex = (void *)(fakeMap + fakeHeader->indexOffset);
        uint32_t fakeMagic = 0x40440000 - fakeHeader->indexOffset;
        MapTag *maptags = fakeMap + (fakeIndex->tagIndexOffset - fakeMagic);
        void *scenarioTag = fakeMap + (maptags[fakeIndex->scenarioTag.tagTableIndex].dataOffset - fakeMagic);
        uint32_t realBspCount = *(uint32_t *)(scenarioTag + 0x5A4);
        *(uint32_t *)(scenarioTag + 0x5A4) = 0;
        MapData fakeMapStruct = openMapFromBuffer(fakeMap);
        fakeMapStruct = zteam_deprotect(fakeMapStruct);
        free(fakeMap);
        fakeHeader = (HaloMapHeader *)fakeMapStruct.buffer;
        memcpy(indexMemoryOffset,fakeMapStruct.buffer + fakeHeader->indexOffset,fakeHeader->metaSize);
        free(fakeMapStruct.buffer);
        
        HaloMapIndex *index = (HaloMapIndex *)(0x40440000);
        uint32_t ownTagCount = index->tagCount;
        Tag *ownTags = (void *)index->tagIndexOffset;
        *(uint32_t *)(ownTags[index->scenarioTag.tagTableIndex].data + 0x5A4) = realBspCount;
        for(uint32_t i=0;i<ownTagCount;i++) {
            if(ownTags[i].notInsideMap) {
                bool useFakeData = ownTags[i].classA == *(uint32_t *)&USTR;
                for(uint32_t t=0;t<tagCount;t++) {
                    if(ownTags[i].classA == tags[t].classA && strcmp(ownTags[i].name,tags[t].name) == 0 ) {
                        setupDataOfTag(tags[t],&(ownTags[i]),ownTags,ownTagCount);
                        useFakeData = false;
                        break;
                    }
                }
                if(useFakeData)
                    ownTags[i].data = fakeTag;
            }
            else if(ownTags[i].classA == *(uint32_t *)&BITM) {
                TagReflexive *loadedBitmaps = (TagReflexive *)(ownTags[i].data + 0x60);
                BitmTagBitmap *loadedBitmBitmaps = (BitmTagBitmap *)(loadedBitmaps->offset);
                for(uint32_t l=0;l<loadedBitmaps->count;l++) {
                    if((((loadedBitmBitmaps[l].flags) >> 8) & 0x1) == 0) continue;
                    loadedBitmBitmaps[l].pixelOffset = translateResource(loadedBitmBitmaps[l].pixelOffset, RES_BITM);
                }
            }
            else if(ownTags[i].classA == *(uint32_t *)&SND) {
                TagReflexive *loadedPitchRanges = (ownTags[i].data + 0x98);
                for(uint32_t l=0;l<loadedPitchRanges->count;l++) {
                    TagReflexive *loadedPermutations = (TagReflexive *)(loadedPitchRanges->offset + l * 72 + 0x3C);
                    SndRangePermutation *loadedPermData = (SndRangePermutation *)(loadedPermutations->offset);
                    for(uint32_t p=0;p<loadedPermutations->count;p++) {
                        if((loadedPermData[p].flags & 0x1) == 0) continue;
                        loadedPermData[p].offset = translateResource(loadedPermData[p].offset,RES_SND);
                    }
                }
            }
        }
    }
    return returnValue;
}

- (id) initWithMode:(MDPluginMode)mode {
    self = [super init];
    if(self != nil) {
        fakeTag = calloc(0x1000,0x1); //Have ustrs use 0's. It's good for them.
        mach_override_ptr((void *)(0xc3150), overrideStuff, (void **)&doStuff);
        void *protectLocation = (void *)0x62000;
        mprotect(protectLocation, 0x1000, PROT_READ | PROT_WRITE); //make sure Halo doesn't reject a map because of its version
        void *memsetLocation = (void *)(0x62fd9);
        memset(memsetLocation,0x90,3);
        *(uint8_t *)(0x62fdc) = 0xEB;
        mprotect(protectLocation, 0x1000, PROT_READ | PROT_EXEC);
        NSData *rmap = [NSData dataWithContentsOfURL:[THIS_BUNDLE URLForResource:@"rmap" withExtension:@"zrmap"]];
        NSData *rmap_mp = [NSData dataWithContentsOfURL:[THIS_BUNDLE URLForResource:@"rmap-mp" withExtension:@"zrmap"]];
        resourceMap = malloc([rmap length]);
        memcpy(resourceMap,[rmap bytes],[rmap length]);
        resourceMapMp = malloc([rmap_mp length]);
        memcpy(resourceMapMp,[rmap_mp bytes],[rmap_mp length]);
    }
    return self;
}

static void setupIncyclopedia() {
    
    NSData *mapData = [NSData dataWithContentsOfURL:[THIS_BUNDLE URLForResource:@"incyclopedia" withExtension:@"map"]];
    
    free(map.buffer);
    free(tagSetupAlready);
    void *bytes = malloc([mapData length]);
    memcpy(bytes,(void *)[mapData bytes],[mapData length]);
    map = openMapFromBuffer(bytes);
    HaloMapHeader *header = (HaloMapHeader *)bytes;
    HaloMapIndex *index = (HaloMapIndex *)(bytes + header->indexOffset);
    
    incyMagic = (int64_t)(map.buffer + header->indexOffset - 0x40440000);
    
    tagSetupAlready = calloc(sizeof(bool),index->tagCount);
    
    tagCount=index->tagCount;
    tags = (void *)(index->tagIndexOffset + incyMagic);
    
    for(uint32_t i=0;i<tagCount;i++) {
        if(tags[i].data != 0) tags[i].data += incyMagic;
        tags[i].name += incyMagic;
    }
}

static void setupDataOfTag(Tag tag, Tag *loadedTag, Tag *ownTags, uint32_t ownTagsCount) {
    if(tag.data == 0) return;
    int64_t addMagic = incyMagic;
    if(tagSetupAlready[tag.identity.tagTableIndex]) addMagic = 0;
    tagSetupAlready[tag.identity.tagTableIndex] = true;
    if(tag.classA == *(uint32_t *)&SND) {
        TagDependency *promotionSound = (tag.data + 0x70);
        if(promotionSound->identity.tagTableIndex != 0xFFFF) {
            char *name = tags[promotionSound->identity.tagTableIndex].name;
            bool foundTag = false;
            for(uint32_t i=0;i<ownTagsCount;i++) {
                if(ownTags[i].classA == *(uint32_t *)&SND && strcmp(name,ownTags[i].name) == 0) {
                    promotionSound->identity = ownTags[i].identity;
                    foundTag = true;
                    break;
                }
            }
            if(foundTag == false) {
                TagID nullID = {0xFFFF, 0xFFFF};
                promotionSound->identity= nullID;
            }
        }
        TagReflexive *pitchRanges = (tag.data + 0x98);
        pitchRanges->offset += addMagic;
        for(uint32_t i=0;i<pitchRanges->count;i++) {
            TagReflexive *permutations = (TagReflexive *)(pitchRanges->offset + i * 72 + 0x3C);
            permutations->offset += addMagic;
            for(uint32_t p=0;p<permutations->count;p++) {
                *(TagID *)(permutations->offset + p * 124 + 0x34) = loadedTag->identity;
                *(TagID *)(permutations->offset + p * 124 + 0x3C) = loadedTag->identity;
            }
        }
        loadedTag->data = tag.data;
    }
    else if(tag.classA == *(uint32_t *)BITM) {
        TagReflexive *sequences = (TagReflexive *)(tag.data + 0x54);
        sequences->offset += addMagic;
        for(uint32_t i=0;i<sequences->count;i++) {
            TagReflexive *sequenceSequences = (TagReflexive *)(sequences->offset + i * 64 + 0x34);
            sequenceSequences->offset += addMagic;
        }
        TagReflexive *bitmaps = (TagReflexive *)(tag.data + 0x60);
        bitmaps->offset += addMagic;
        loadedTag->data = tag.data;
    }
    else if(tag.classA == *(uint32_t *)FONT) {
        TagReflexive *charTables = (TagReflexive *)(tag.data + 0x30);
        charTables->offset += addMagic;
        for(uint32_t i=0;i<charTables->count;i++) {
            TagReflexive *charTablesTables = (TagReflexive *)(charTables->offset + i * 12);
            charTablesTables->offset += addMagic;
        }
        TagReflexive *chars = (TagReflexive *)(tag.data + 0x7C);
        chars->offset += addMagic;
        TagReflexive *unknown = (TagReflexive *)(tag.data + 0x90);
        unknown->offset += addMagic;
        loadedTag->data = tag.data;
    }
    else if(tag.classA == *(uint32_t *)USTR) {
        TagReflexive *stringReferences = (tag.data + 0x0);
        stringReferences->offset += addMagic;
        for(uint32_t i=0;i<stringReferences->count;i++) {
            TagReflexive *string = (TagReflexive *)(stringReferences->offset + i * 20 + 0x8);
            string->offset += addMagic;
        }
        loadedTag->data = tag.data;
    }
    else if(tag.classA == *(uint32_t *)HMT) {
        TagReflexive *unknown = (TagReflexive *)(tag.data + 0x8);
        unknown->offset += addMagic;
        TagReflexive *elements = (TagReflexive *)(tag.data + 0x14);
        elements->offset += addMagic;
        TagReflexive *messages = (TagReflexive *)(tag.data + 0x20);
        messages->offset += addMagic;
        loadedTag->data = tag.data;
    }
    return;
}

static uint32_t translateResource(uint32_t ceOffset, HCEResourceType type) {
    RMapHeader *rmap = resourceMapMp;
    uint32_t count = 0;
    RTranslator *translator = NULL;
    if(type == RES_BITM) {
        translator = resourceMapMp + rmap->bitmapOffset;
        count = rmap->bitmapCount;
    }
    else if(type == RES_SND) {
        translator = resourceMapMp + rmap->soundOffset;
        count = rmap->soundCount;
    }
    for(uint32_t i=0;i<count;i++) {
        if(translator[i].ce == ceOffset) return translator[i].pc;
    }
    
    rmap = resourceMap;
    count = 0;
    translator = NULL;
    
    if(type == RES_BITM) {
        translator = resourceMap + rmap->bitmapOffset;
        count = rmap->bitmapCount;
    }
    else if(type == RES_SND) {
        translator = resourceMap + rmap->soundOffset;
        count = rmap->soundCount;
    }
    for(uint32_t i=0;i<count;i++) {
        if(translator[i].ce == ceOffset) return translator[i].pc;
    }
    
    return ceOffset;
}


- (void) mapDidBegin:(NSString *)mapName {
    static bool firstRun = true;
    
    static void (*runCommand)(char *command,char *error_result,char *command_name) = (void *)0x11e3de;
    if(firstRun) {
        runCommand("sv_maplist_show_all 1","%s","sv_maplist_show_all");
        firstRun = false;
    }
}

- (void) mapDidEnd:(NSString *)mapName {
    fixMap = true;
}

@end
