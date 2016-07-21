# bdf_to_oled
Font Converter for efficient drawing on SH1106-ish OLED screens. Generates header files. No known character size
limitations, although the per-character byte-length header is only 16-bits wide. 


    Usage: bfd_to_oled.rb [options]
        -v, --[no-]verbose               Run verbosely
        -h, --header                     Include Header
        -s, --single-line
        -t, --typedef                    Include Typedef
        -r, --range RANGE                Character range to print, fmt 'a-b'
        -n, --name NAME                  Name (identifier) of font (probably should be camel-case)
        

This code is not well-tested, but it does work for me.

How it's laid out
-----------------
Used as part of a build script to generate appropriate bitmap fonts for use on an oled screen.
The screen is arranged in vertical 8-bit pages starting on the top-left. The next byte is
vertical and directly to the right. After reaching the right limit of the first 8-bit tall "row",
the page increments and the column resets.


    // 006D: 'm' (6d, 180 bytes)
    //     box: 45 30
    //     offset: 22249
    //  0123456789abcdef....
    // 1-0----------##------------------------------------
    //   1---------###------------------------------------
    //   2-------#####------------------------------------
    //   3----########------#####---------######----------
    //   4############----#########-----##########--------
    //   5############---###########---###########--------
    //   6-----########-############--#############-------
    //   7------#########----##########----########-------
    // 2-0------########------########------########------
    //   1------########-------#######-------#######------
    //   2-------######--------######--------#######------
    //   3-------######--------######--------#######------
    //   4-------######--------######--------#######------
    //   5-------######--------######--------#######------
    //   6-------######--------######--------#######------
    //   7-------######--------######--------#######------
    // 3-0-------######--------######--------#######------
    //   1-------######--------######--------#######------
    //   2--------#####-------#######--------#######------
    //   3--------#####-------#######--------######-------
    //   4--------#####------########-------#######-------
    //   5--------#####----###########------#######-------
    //   6-------######-----------######--#########-------
    //   7------########-----------------##########-------
    // 4-0--#############------------------#########------
    //   1--#################-----------------######------
    //   2--------------------------------------####------
    //   3----------------------------------------###-----
    //   4-----------------------------------------####---
    //   5-------------------------------------------##---

What code is generated?
-----------------------
Characters are variably sized. The first three bytes of each character are a header consisting of 
the pixel width (bbx) and bytesize (a uint16_t as two bytes, MSB). So how do you find an individual
character? A lookup table is generated showing the offset of each character starting with the first,
which is specified by the `--range` option.

    const font_t bebas_big = {
      .data = _bebas_big_data,
      .startchar = ' ',
      .length = 94,
      .lookup = {0x00, 0x03, 0x30, ... },
    };

How do I use it?
----------------
    uint8_t charnum = c - font->startchar;       // If the font starts with 'A', change 'A' to 0, for the 0th char
    int offset = font->lookup[charnum];          // Get the offset into the font table
    const uint8_t * glyph = &font->data[offset]; // Get the glyph data, starting with width and byte length
    
    uint8_t width = *glyph++;
    uint16_t bytelen  = *glyph++ << 8;
		    		 bytelen |= *glyph++;
		uint8_t pages = bytelen / width; 

From there you can dump it into your screen buffer however you see fit.
    
