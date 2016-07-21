#!/usr/bin/env ruby

############################################################
##
## Modify this
##

fonts = [
  {name: "myfont_sm",  size: 10, file: "ActualFontSomewhere.otf"},
  {name: "myfont_med", size: 16, file: "ActualFontSomewhere.otf"},
  {name: "myfont_big", size: 48, file: "ActualFontSomewhere.otf"},
]

c_file_name = "font_data.c"
h_file_name = "font_data.h"

##
############################################################

dir = File.expand_path(File.dirname(__FILE__))

if fonts.collect{|x| x[:name]}.uniq.length < fonts.length
  puts "Font names much be unique"
  exit 1
end


fonts.each do | font |
  puts "Building #{font.inspect}"

  # Build BDF
  system "#{File.join(dir, 'otf2bdf')} -p #{font[:size]} #{File.join(dir, font[:file])} -o #{File.join(dir, font[:name])}.bdf"
  
  # Build C file
  system "bfd_to_oled.rb -h  --name #{font[:name]} #{File.join(dir, font[:name])}.bdf > #{File.join(dir, font[:name])}.c"
end

# Build header file 
File.open(File.join(File.expand_path(File.dirname(__FILE__)), h_file_name), "w") do |f|
  f.puts  <<-EOH
#ifndef FONTS_H
#define FONTS_H

typedef struct  {
	const uint8_t * data;
	char startchar;
	uint8_t length;
	int16_t lookup[];
} font_t;
EOH


  fonts.each do | font |
    f.puts "extern const font_t #{font[:name]}; // #{font[:file]} size #{font[:size]}"
  end
  
  f.puts "#endif"
end
  

# Build source file. Include this in something to bring them into your program
File.open(File.join(File.expand_path(File.dirname(__FILE__)), c_file_name), "w") do |f|

  fonts.each do | font |
    f.puts "#include \"#{font[:name]}.c\" // #{font[:file]} size #{font[:size]}"
  end
end