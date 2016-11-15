#!/usr/bin/env ruby

# variables describing the read data
# input_file_for_index
# input_file_for_read
# sample index file name

# variables to specify the reference
# refname
# trans2genemap

# non essential options
# bowtie threads
# samtools sort threads


require 'optparse'

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: makemakefile.rb [options]"
  opts.on("-iFILE", "--index-fq=FILE", "index fastq (.gz)") do |f|
    options[:index_fq_z] = f
  end
  opts.on("-rFILE", "--read-fq=FILE", "read fastq (.gz)") do |f|
    options[:read_fq_z] = f
  end
  opts.on("-sFILE", "--sample-file=FILE", "sample names for indices") do |f|
    options[:sample_file] = f
  end

  opts.on("-RPATH", "--reference=PATH", "reference preprared with rsem-prepare-reference") do |f|
    options[:ref_name] = f
  end
  opts.on("-tFILE", "--transcript-to-gene-map=FILE", String, "transcript to gene map") do |f|
    options[:trans2genemap] = f
  end

  opts.on("-pINT", "--proc INT", Integer, "number of processors to use") do |p|
    options[:p] = p
  end

  opts.on("-v", "--[no-]verbose", "Run verbosely") do |v|
    options[:verbose] = v
  end
end.parse!

sample_file = options[:sample_file]

indices = Array.new

open(sample_file).each_line do |line|
  indices << line.chomp.split
end

mf=open("Makefile", "w")

mf.puts "SHELL := /bin/bash"
mf.puts "all: genes.count.matrix isoforms.count.matrix"
mf.puts ".PHONY: sub_clean"

mf.puts "ifdef NSLOTS"
mf.puts '  thread_arg = -p ${NSLOTS}'
mf.puts '  thread_arg_sort = -@ ${NSLOTS}'
mf.puts 'else'
if options[:p] == nil
  mf.puts 'thread_arg = ""'
  mf.puts 'thread_arg_sort = ""'
else
  mf.puts "thread_arg = \"-p #{options[:p]}\""
  mf.puts "thread_arg_sort = \"-@ #{options[:p]}\""
end
mf.puts "endif"

read_fq_targets = indices.map{|a| "#{a[1]}_read.fq"}.join(" ")

index_fq_z=options[:index_fq_z]
read_fq_z=options[:read_fq_z]

if index_fq_z =~ /.gz$/
  index_fq_dec = "<(gzip -dc #{index_fq_z})"
elsif index_fq_z =~ /.bz2$/
  index_fq_dec = "<(bzip2 -dc #{index_fq_z})"
else
  index_fq_dec = index_fq_z
end

if read_fq_z =~ /.gz$/
  read_fq_dec = "<(gzip -dc #{read_fq_z})"
elsif read_fq_z =~ /.bz2$/
  read_fq_dec = "<(bzip2 -dc #{read_fq_z})"
else
  read_fq_dec = read_fq_z
end

mf.puts "#{read_fq_targets}: #{read_fq_z} #{index_fq_z} #{sample_file}"
mf.puts "\truby sortbarcode1.rb #{index_fq_dec} #{read_fq_dec} #{sample_file}"

samples = indices.map{|a| a[1]}.join(" ")
mf.puts "sub_clean:"
mf.puts "\trm -rf #{samples}"

#rule for mapping
bams = indices.map{|a| "#{a[1]}/#{a[1]}.bam"}.join(" ")
mf.puts "bams = #{bams}"
mf.puts "$(bams) : #{options[:ref_name]}.rev.1.bt2"
mf.puts

indices.each do |ip|
  sample_name = ip[1]
  mf.puts "#{sample_name}/#{sample_name}.bam: #{sample_name}_read.fq"
  mf.puts "\t(mkdir -p #{sample_name}; bowtie -q --phred33-quals -n 2 -e 99999999 -l 25 $(thread_arg) -a -m 200 -S #{options[:ref_name]} $< | samtools view -Sb -o $@ -)"
end
mf.puts

system("mkdir -p jobs")
system("mkdir -p logs")
open("jobs/map","w") do |jf|
  jf.puts "#!/bin/bash"
  jf.puts "#$ -cwd -S /bin/bash -V"
  jf.puts "#$ -pe def_slot 1-20"
  jf.puts "#$ -e logs -o logs"
  jf.puts "#$ -t 1:#{indices.size}"
  jf.puts "samples=(dummy #{samples})"
  jf.puts "sample=${samples[$SGE_TASK_ID]}"
  jf.puts "make $sample/$sample.bam"
end

sortedbams = indices.map{|a| "#{a[1]}/#{a[1]}.readname.bam"}.join(" ")
mf.puts "sortedbams = #{sortedbams}"
mf.puts "$(sortedbams) : %.readname.bam : %.bam"
mf.puts "\tsamtools sort -n -o $@ $(thread_arg_sort) $<"

open("jobs/sort","w") do |jf|
  jf.puts "#!/bin/bash"
  jf.puts "#$ -cwd -S /bin/bash -V"
  jf.puts "#$ -pe def_slot 1-20"
  jf.puts "#$ -e logs -o logs"
  jf.puts "#$ -t 1:#{indices.size}"
  jf.puts "samples=(dummy #{samples})"
  jf.puts "sample=${samples[$SGE_TASK_ID]}"
  jf.puts "make $sample/$sample.readname.bam"
end

unifiedsams = indices.map{|a| "#{a[1]}/#{a[1]}.unified2.sam"}.join(" ")
mf.puts "unifiedsams = #{unifiedsams}"
mf.puts "$(unifiedsams) : %.unified2.sam : %.readname.bam "
mf.puts "\tsamtools view -h -F 4 $< | ruby unify2.rb /home/tomoaki/Ppatens/v3.3/Ppatrans2genemap > $@"

open("jobs/unify","w") do |jf|
  jf.puts "#!/bin/bash"
  jf.puts "#$ -cwd -S /bin/bash -V"
  jf.puts "#$ -pe def_slot 1-20"
  jf.puts "#$ -e logs -o logs"
  jf.puts "#$ -t 1:#{indices.size}"
  jf.puts "samples=(dummy #{samples})"
  jf.puts "sample=${samples[$SGE_TASK_ID]}"
  jf.puts "make $sample/$sample.unified2.sam"
end

iso_results = indices.map{|a| "#{a[1]}/#{a[1]}.isoforms.results"}.join(" ")
gen_results = indices.map{|a| "#{a[1]}/#{a[1]}.genes.results"}.join(" ")
indices.each do |a|
  s = a[1]
  mf.puts "#{s}/#{s}.isoforms.results #{s}/#{s}.genes.results: #{s}/#{s}.unified2.sam"
  mf.puts "\t(cd #{s}; rsem-calculate-expression $(thread_arg) --forward-prob=0.95 --sam #{s}.unified2.sam #{options[:ref_name]} #{s})"
end

open("jobs/rsem","w") do |jf|
  jf.puts "#!/bin/bash"
  jf.puts "#$ -cwd -S /bin/bash -V"
  jf.puts "#$ -pe def_slot 1-20"
  jf.puts "#$ -e logs -o logs"
  jf.puts "#$ -t 1:#{indices.size}"
  jf.puts "samples=(dummy #{samples})"
  jf.puts "sample=${samples[$SGE_TASK_ID]}"
  jf.puts "make $sample/$sample.genes.results"
end

mf.puts "isoforms.count.matrix: #{iso_results}"
mf.puts "\tRscript makeMatrix_isoforms.R"
mf.puts "genes.count.matrix: #{gen_results}"
mf.puts "\tRscript makeMatrix_genes.R"

open("jobs/combine","w") do |jf|
  jf.puts "#!/bin/bash"
  jf.puts "#$ -cwd -S /bin/bash -V"
  jf.puts "#$ -e logs -o logs"
  jf.puts "#$ -pe def_slot 1-20"
  jf.puts "N=$NSLOTS"
  jf.puts "NSLOTS=1 make -j $N all"
end

sample_file = options[:sample_file]

sample_name_a = indices.map{|a| a[1]}

open("makeMatrix_genes.R", "w") do |rf|
  sample_name_a.each do |s|
    rf.puts "dfg_#{s} <- read.table(\"#{s}/#{s}.genes.results\", head=T)"
  end
  rf.puts "g_matrix = data.frame(id = dfg_#{sample_name_a[0]}$gene_id, #{sample_name_a.map{|s| "g_#{s} = dfg_#{s}$expected_count"}.join(", ")} )"
  rf.puts 'write.table(g_matrix, "genes.counts.matrix")'
end

open("makeMatrix_isoforms.R", "w") do |rf|
  sample_name_a.each do |s|
    rf.puts "dfi_#{s} <- read.table(\"#{s}/#{s}.isoforms.results\", head=T)"
  end
  rf.puts "i_matrix = data.frame(id = dfi_#{sample_name_a[0]}$transcript_id, #{sample_name_a.map{|s| "i_#{s} = dfi_#{s}$expected_count"}.join(", ")} )"
  rf.puts 'write.table(i_matrix, "isoforms.counts.matrix")'
end
