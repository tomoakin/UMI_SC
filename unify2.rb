#!/usr/bin/env ruby
require 'set'
#require 'bio'

gene_trans_map = ARGV.shift

class Sam
  def initialize(str)
    @data=str.chomp.split("\t")
  end
  def to_s
    @data.join("\t")
  end
  def query
    @data[0]
  end
  def target
    @data[2]
  end
end


gene2trans=Hash.new
trans2gene=Hash.new

open(gene_trans_map).each_line do |line|
  (gene,trans)=line.chomp.split
  if(gene2trans[gene] == nil)
    gene2trans[gene]=Array.new
  end
  gene2trans[gene] << trans
  trans2gene[trans] = gene
end

umi2reads=Hash.new

last_pos = ""
last_set = Hash.new
last_umi = nil

def select_record_from_gene(gene, samarray)
  # we have same umi, same gene
  # we should select one query read from the set
  read_name2sams = Hash.new
  target_counts = Hash.new
  samarray.each do |sam|
    read_name = sam.query
    if read_name2sams[read_name] == nil
      read_name2sams[read_name] = Array.new
    end
    read_name2sams[read_name] << sam
    if target_counts[sam.target] == nil
      target_counts[sam.target] = 0
    end
    target_counts[sam.target] += 1
  end
  max_target_count = 0
  target_counts.each_value do |count|
    max_target_count = count if count > max_target_count
  end
  max_hit_targets = Set.new
  target_counts.each do |target, count|
    max_hit_targets << target if count == max_target_count
  end
  chosen_target = max_hit_targets.to_a[rand(max_hit_targets.size)]
  # find reads mapping to the specific target
  candidates = Array.new
  samarray.each do |sam|
    next if sam.target != chosen_target
    if max_hit_targets == Set.new(read_name2sams[sam.query].map{|x| x.target})
      read_name2sams[sam.query].each{|sam| puts sam}
      return
    end
    candidates << sam  
  end
  min_target = -1
  min_target_query = nil
  candidates.each do |sam|
    target_count =  read_name2sams[sam.query].size
    if min_target == -1 or target_count < min_target
      min_target = target_count
      min_target_query = sam.query
    end
  end
  if min_target_query != nil
    read_name2sams[min_target_query].each{|sam| puts sam}
  end
end


def select_record_from_umi(sampool, t2gmap)
  gene2sams = Hash.new
  sampool.each do |sam|
    gene = t2gmap[sam.target]
    if gene2sams[gene] == nil
      gene2sams[gene] = Array.new
    end
    gene2sams[gene] << sam
  end
  gene2sams.each do |gene, samarray|
    select_record_from_gene(gene, samarray)
  end
end

last_umi =  ""
reads = Array.new
ARGF.each_line do |line|
  if line =~ /^@/
    puts line
    next
  end
  sam=Sam.new(line)
  read_id = sam.query
  umi = read_id[0..7]
  if umi!= last_umi
    select_record_from_umi(reads, trans2gene) unless reads.size==0
    reads=Array.new
    last_umi = umi
  end
  reads << sam
end
select_record_from_umi(reads, trans2gene)
