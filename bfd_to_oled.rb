#!/usr/bin/env ruby

require "optparse"



class Char
  attr_accessor :code
  attr_accessor :name
  attr_accessor :swidth
  attr_accessor :dwidth

  attr_accessor :bbx
  attr_accessor :bby
  attr_accessor :bboffx
  attr_accessor :bboffy
  
  attr_accessor :data
  
  def initialize(code)
    self.data = []
    self.code = code
  end
  
  def printself
    self.data.each_with_index do |line, line_i|
      print "// "
      line.each do |byte|
        (0..7).each do |i|
          if byte & (1 << 7-i) != 0
            print '#'
          else
            print "-"
          end
        end
      end
      print "\n"
    end
  end
  
  def printselfd
    self.data.each do |line|
      line.reverse.each do |byte|
        (0..7).each do |i|
          if (((byte >> i) & 0x01) == 1)
            print i
          else
            print "-"
          end
        end
      end
      print "\n"
    end
  end
  
  
  def rotate
    out = []
    
    lines = self.data.length
    return out if lines < 1
    return out if self.bbx.nil? or self.bbx < 1
    
    line = 0
    page_count = (self.data.length / 8.0).ceil

    page_count.times do |page|

      self.bbx.times do |bitpos|

        # read this column
        byte = 0
        8.times do |line|
          src = self.data[page * 8 + line][(bitpos/8) ] || 0 rescue 0
          byte |= 1 << line if src & (1 << (7 - bitpos%8)) != 0
        end
        out << byte

      end      
    end
    
    out
    
  end
end


class BDFParser
  
  attr_accessor :name
  attr_accessor :filepath
  attr_accessor :chars
  attr_accessor :range
  
  def initialize(filepath=nil)
    self.filepath = filepath
    self.range = 32..126
    self.chars = []
  end
  
  def identifier
    self.name.downcase.gsub(/[^\d\w]/, '_') 
  end
  
  def parse
    raise ArgumentError("File Not Set") if self.filepath.nil?
    
    File.open(File.expand_path(ARGV[0]), encoding: 'ISO-8859-1:UTF-8') do |f|
    
      current_char_name = nil
      current_char = nil
      reading_bitmap = false
  
      f.each_line do |line|
        case line
        when /FAMILY_NAME \"(.+)\"/
          self.name = $1.strip
          
        when /^STARTCHAR (.+)\n/
          current_char_name = $1

        when /^ENCODING ([A-Z0-9]+)/
          code = $1.to_i
          current_char = if range.include?(code)
            c = Char.new(code)
            c.name = current_char_name
            chars << c
            c
          else
            nil
          end
      
        when /SWIDTH (\d+) (\d+)/
          unless current_char.nil?
            # puts "swidth: " + [$1.to_i, $2.to_i].inspect
            current_char.swidth = [$1.to_i, $2.to_i]
          end
    
        when /DWIDTH (\d+) (\d+)/
          unless current_char.nil?
            # puts "dwidth: " + [$1.to_i, $2.to_i].inspect
            current_char.dwidth = [$1.to_i, $2.to_i]
          end
    
        when /BBX (\d+) (\d+) (-?\d+) (-?\d+)/
          unless current_char.nil?
            current_char.bbx    = $1.to_i
            current_char.bby    = $2.to_i
            current_char.bboffx = $3.to_i
            current_char.bboffy = $4.to_i
          end
    
        when /BITMAP/
          unless current_char.nil?
            reading_bitmap = true
          end
        
        when /ENDCHAR/
          reading_bitmap = false
    
        when /([A-F0-9][A-F0-9])+/
          if reading_bitmap
            # current_char.data << line.strip.unpack("C*")
            current_char.data << line.strip.scan(/../).collect{|hex| hex.to_i(16)}
          end
        end
      end
    end
  end
end



options = {
  :single_line=> false
}
optparse = OptionParser.new do |opts|
  opts.banner = "Usage: bfd_to_oled.rb [options]"
  opts.accept(Range) do |range_format|
    a,b = range_format.strip.split('-')
    (a.to_i..b.to_i)
  end

  opts.on("-v", "--[no-]verbose", "Run verbosely") do |v|
    options[:verbose] = v
  end
  
  opts.on "-h", "--header", "Include Header" do |h|
    options[:include_header] = true
  end

  opts.on "-s", "--single-line" do
    options[:single_line] = true
  end
  
  opts.on "-t", "--typedef", "Include Typedef" do
    options[:typedef] = true
  end
  
  opts.on "-r", "--range RANGE", "Character range to print, fmt 'a-b'", Range do |range|
    puts "Got Range: #{range}"
    options[:range] = range
  end
  
  opts.on "-n", "--name NAME", "Name (identifier) of font", String do |name|
    options[:name] = name
  end
  
end

if ARGV.count < 1
  print optparse
  exit(1)
end
  
optparse.parse!

p = BDFParser.new(File.expand_path(ARGV.last))
p.range = options[:range] if options[:range]
p.parse
p.name = options[:name] if options[:name]

if options[:include_header]
  puts <<-EOH
/** 
  These glyphs are arranged in pages for SH1106. By bit:

  Page  0123
        ----
        aaaa
        9999
        8888
        7777
        6666
        5555
        4444
        3333
        2222
        1111

  Font: #{p.name}
**/
  EOH
  
end


puts "// Got #{p.chars.count} chars"
puts "const uint8_t _#{p.identifier}_data[] = {"

byte_offset = 0 # the offset of the glyph into the font
lookup = []
p.chars.each do |c|
  rotated = c.rotate
  byte_count = rotated.count || 0
  unless options[:single_line]
    printf("// %s: '%c' (%02x, %d bytes)\n", c.name, c.code, c.code, rotated.count)
    printf("//     box: %d %d\n", c.bbx || -1, c.bby || -1)
    printf("//     offset: %d\n", byte_offset)
    c.printself 
    printf("0x%02x, 0x%02x, 0x%02x,   ", c.bbx || 0, byte_count >> 8, byte_count & 0xff)
    print rotated.collect{|x| "0x%02x, " % x }.join
    print "\n\n"
  else
    #Single line
    print "  "
    printf("0x%02x, 0x%02x, 0x%02x,   ", c.bbx || 0, byte_count >> 8, byte_count & 0xff)
    print rotated.collect{|x| "0x%02x" % x }.join(", ")
    printf(" // %s: '%c' (%02x, %d bytes)\n", c.name, c.code, c.code, rotated.count)
  end
    
  lookup << byte_offset
  byte_offset += rotated.count + 3 # bytesize of glyph plus header (width, length high, length low)
end

puts <<-EOD
};

const font_t #{p.identifier} = {
  .data = _#{p.identifier}_data,
  .startchar = '#{p.range.first.chr}',
  .length = #{p.range.last - p.range.first},
  .lookup = {#{lookup.collect{|x| "0x%02x, " % x}.join}},
};
EOD
