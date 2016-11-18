#!/usr/bin/env ruby
#

require 'bio'
indexlist=ARGV.shift
indexfile=ARGV.shift
rnaseqfile=ARGV.shift

barcode_length=8

sampleif = Hash.new
samplerf = Hash.new
barcode2sample = Hash.new

open(indexlist).each_line do |l|
  (barcode, sample) = l.chomp.split
  sampleif[sample] = open(sample + "_index.fq","w")
  samplerf[sample] = open(sample + "_read.fq","w")
#  barcode2sample[barcode]=sample
  # generate single and double mutations
  (0...barcode.length).each do |i|
    mbarcode = barcode.dup
    ['A','C','G','T','N'].each do |nucm1|
      mbarcode[i]=nucm1
      if(barcode2sample[mbarcode]!=nil && barcode2sample[mbarcode]!=sample)
        $stderr.puts "too similar barcode present"
        $stderr.puts "check barcode for #{barcode2sample[mbarcode]} and #{sample}"
        exit(1)
      end
      barcode2sample[mbarcode]=sample
    end # nucm1
  end # i
end # each_line

sampleif["unknown"] = open("unknown_index.fq", "w")
samplerf["unknown"] = open("unknown_read.fq", "w")

inf = Bio::FlatFile.open(nil,indexfile)
readf = Bio::FlatFile.open(nil,rnaseqfile)

bchash = Hash.new
while ie = inf.next_entry
  re = readf.next_entry
  if ie.entry_id != re.entry_id
    $stderr.puts "entry_id mismatch!"
    exit(1)
  end
  curbarcode = ie.sequence_string[0,barcode_length].upcase
#  p curbarcode
  sample = "unknown"
  sample = barcode2sample[curbarcode] unless barcode2sample[curbarcode] == nil
  sampleif[sample].puts "@#{ie.sequence_string[barcode_length..-1]}#{ie.entry_id}\n#{ie.sequence_string}\n+\n#{ie.quality_string}\n"
  samplerf[sample].puts "@#{ie.sequence_string[barcode_length..-1]}#{re.entry_id}\n#{re.sequence_string}\n+\n#{re.quality_string}\n"
end
