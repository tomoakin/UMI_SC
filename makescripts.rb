#!/usr/bin/env ruby
require 'mkmf'

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
# trimmomatic -threads threads

grid_conf_default = <<EOS
split_fq: -pe def_slot 1-3
map: -pe def_slot 1-20
sort: -pe def_slot 1-20
unify: -pe def_slot 1-2
rsem: -pe def_slot 1-20
combine: -pe def_slot 1-2
EOS

require 'optparse'
require 'yaml'

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
  opts.on("-m", "--trimmomatic=FILE", "path for trimmomatic") do |f|
    options[:trimmomatic] = f
  end
  opts.on("-o", "--trimmomatic-options=STRING", "main options for trimmomatic") do |f|
    options[:trimmomatic_options] = f
  end


  opts.on("-RPATH", "--reference=PATH", "reference preprared with rsem-prepare-reference") do |f|
    options[:ref_name] = f
  end
  opts.on("-tFILE", "--transcript-to-gene-map=FILE", String, "transcript to gene map") do |f|
    options[:trans2genemap] = f
  end

  opts.on("-lINT", "--index-length=INT", "the length of index data preceeding unique molecular identifier [8]") do |l|
    options[:l] = l
  end
  opts.on("-uINT", "--umi-length=INT", "the length of unique molecular identifier [10]") do |l|
    options[:u] = l
  end
  opts.on("-pINT", "--proc=INT", Integer, "number of processors to use") do |p|
    options[:p] = p
  end
  opts.on("-g FILE", "--grid-conf=FILE", String, "grid configuration") do |f|
    options[:grid] = f
  end
  opts.on("-G", "--submit", "grid configuration") do |v|
    options[:submit] = v
  end

  opts.on("-v", "--[no-]verbose", "Run verbosely") do |v|
    options[:verbose] = v
  end
end.parse!

sample_file = options[:sample_file]

if options[:grid] != nil
  grid_resource=YAML.load_file(options[:grid])
else
  grid_resource=YAML.load(grid_conf_default)
end

if options[:l] != nil
  index_length_opt = "-l #{options[:l]}"
else
  index_length_opt = ""
end

if options[:u] != nil
  umi_length = options[:u]
else
  umi_length = 10
end

indices = Array.new

open(sample_file).each_line do |line|
  indices << line.chomp.split
end

mf=open("Makefile", "w")

mf.puts "SHELL := /bin/bash"
mf.puts "all: genes.count.matrix isoforms.count.matrix"
mf.puts ".PHONY: clean_subdirs"
mf.puts ".PHONY: clean_fq"
mf.puts ".PHONY: clean"
mf.puts ".PHONY: split_fq"

mf.puts "ifdef NSLOTS"
mf.puts '  thread_arg = -p ${NSLOTS}'
mf.puts '  thread_arg_trim = -threads ${NSLOTS}'
mf.puts '  thread_arg_sort = -@ ${NSLOTS}'
mf.puts 'else'
if options[:p] == nil
  mf.puts 'thread_arg = '
  mf.puts 'thread_arg_sort = '
else
  mf.puts "thread_arg = \"-p #{options[:p]}\""
  mf.puts "thread_arg_trim = \"-threads #{options[:p]}\""
  mf.puts "thread_arg_sort = \"-@ #{options[:p]}\""
end
mf.puts "endif"

read_fq_targets = indices.map{|a| "#{a[1]}_read.fq"}.join(" ")
index_fq_targets = indices.map{|a| "#{a[1]}_index.fq"}.join(" ")

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

mf.puts "split_fq: #{read_fq_targets}\n\n"

sortbarcode1_prog = "ruby #{__dir__}/sortbarcode1.rb" # fallback ruby implementation requiring the bioruby library.
if FileTest.executable?("#{__dir__}/sortbarcode1")
  sortbarcode1_prog = "#{__dir__}/sortbarcode1"
elsif c=find_executable('sortbarcode1')
  sortbarcode1_prog = c unless c == nil
end
mf.puts "#{read_fq_targets}: #{read_fq_z} #{index_fq_z} #{sample_file}"
mf.puts "\t#{sortbarcode1_prog} #{index_length_opt} #{sample_file} #{index_fq_dec} #{read_fq_dec}"
mf.puts "clean: clean_fq clean_subdirs"
mf.puts "clean_fq:"
mf.puts "\trm -r #{read_fq_targets}"
mf.puts "\trm -r #{index_fq_targets}"

samples = indices.map{|a| a[1]}.join(" ")
mf.puts "clean_subdirs:"
mf.puts "\trm -rf #{samples}"

#rule for trimming
trimmed_fqs = indices.map{|a| "#{a[1]}/#{a[1]}.trimmed.fq"}.join(" ")
mf.puts "trimmed_fqs = #{trimmed_fqs}"
mf.puts

if options[:trimmomatic] != nil
  trim_opts =  options[:trimmomatic_options] 
  trim_opts = "\"Trimmomatic-0.33/adapters/TruSeq3-PE.fa:2:30:7 LEADING:3 TRAILING:3 SLIDINGWINDOW:4:15 MINLEN:16\"" if trim_opts == nil

  mf.puts "TRIMMOMATIC=#{options[:trimmomatic]}"
  mf.puts "TRIM_OPTS=#{trim_opts}"
  indices.each do |ip|
    sample_name = ip[1]
    mf.puts "#{sample_name}/#{sample_name}.trimmed.fq: #{sample_name}_read.fq"
    mf.puts "\t(mkdir -p #{sample_name}; java -Xmx2g -XX:ParallelGCThreads=1 -jar $(TRIMMOMATIC) SE $(thread_arg_trim) -phred33 $< $@ $(TRIM_OPTS))"
  end
else
  indices.each do |ip|
    sample_name = ip[1]
    mf.puts "#{sample_name}/#{sample_name}.trimmed.fq: #{sample_name}_read.fq"
    mf.puts "\t(mkdir -p #{sample_name}; ln -s ../$< $@)"
  end
end

mf.puts


#rule for mapping
bams = indices.map{|a| "#{a[1]}/#{a[1]}.bam"}.join(" ")
mf.puts "bams = #{bams}"
mf.puts "$(bams) : #{options[:ref_name]}.rev.1.ebwt"
mf.puts

indices.each do |ip|
  sample_name = ip[1]
  mf.puts "#{sample_name}/#{sample_name}.bam: #{sample_name}/#{sample_name}.trimmed.fq"
  mf.puts "\t(mkdir -p #{sample_name}; bowtie -q --phred33-quals -n 2 -e 99999999 -l 25 $(thread_arg) -a -m 200 -S #{options[:ref_name]} $< | samtools view -Sb -o $@ -)"
end
mf.puts

system("mkdir -p jobs")
system("mkdir -p logs")
open("jobs/split_fq", "w") do |jf|
  jf.puts "#!/bin/bash"
  jf.puts "#$ -cwd -S /bin/bash -V"
  jf.puts "#$ -e logs -o logs"
  jf.puts "#$ #{grid_resource["split"]}"
  jf.puts "make split_fq"
end

open("jobs/trim", "w") do |jf|
  jf.puts "#!/bin/bash"
  jf.puts "#$ -cwd -S /bin/bash -V"
  jf.puts "#$ #{grid_resource["trim"]}"
  jf.puts "#$ -e logs -o logs"
  jf.puts "#$ -t 1:#{indices.size}"
  jf.puts "samples=(dummy #{samples})"
  jf.puts "sample=${samples[$SGE_TASK_ID]}"
  jf.puts "make $sample/$sample.trimmed.fq"
end


open("jobs/map","w") do |jf|
  jf.puts "#!/bin/bash"
  jf.puts "#$ -cwd -S /bin/bash -V"
  jf.puts "#$ #{grid_resource["map"]}"
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
  jf.puts "#$ #{grid_resource["sort"]}"
  jf.puts "#$ -e logs -o logs"
  jf.puts "#$ -t 1:#{indices.size}"
  jf.puts "samples=(dummy #{samples})"
  jf.puts "sample=${samples[$SGE_TASK_ID]}"
  jf.puts "make $sample/$sample.readname.bam"
end

unifiedsams = indices.map{|a| "#{a[1]}/#{a[1]}.unified2.sam"}.join(" ")
mf.puts "unifiedsams = #{unifiedsams}"
mf.puts "$(unifiedsams) : %.unified2.sam : %.readname.bam "
mf.puts "\tsamtools view -h -F 4 $< | ruby #{__dir__}/unify2.rb #{umi_length} #{options[:trans2genemap]} > $@"

open("jobs/unify","w") do |jf|
  jf.puts "#!/bin/bash"
  jf.puts "#$ -cwd -S /bin/bash -V"
  jf.puts "#$ #{grid_resource["unify"]}"
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
  jf.puts "#$ #{grid_resource["rsem"]}"
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
  jf.puts "#$ #{grid_resource["combine"]}"
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

#map: -pe def_slot 1-20
#sort: -pe def_slot 1-20
#unify: -pe def_slot 1-2
#rsem: -pe def_slot 1-20
if(options[:submit])
  qsub_response = `qsub jobs/split_fq` 
  if options[:verbose]
    puts "qsub jobs/split_fq" 
    puts qsub_response
  end
  if qsub_response =~ /Your job (\d+)/
    job_id = $1
    stages=["map","sort","unify","rsem"]
    job_id_ad = nil
    (0..3).each do |stage_n|
      next if grid_resource[stages[stage_n]] == grid_resource[stages[stage_n+1]]
      if job_id_ad == nil
        qsub_response = `qsub -hold_jid #{job_id} jobs/#{stages[stage_n]}`
        if options[:verbose]
          puts "qsub -hold_jid #{job_id} jobs/#{stages[stage_n]}"
        end
      else
        qsub_response = `qsub -hold_jid_ad #{job_id_ad} jobs/#{stages[stage_n]}`
        if options[:verbose]
          puts "qsub -hold_jid_ad #{job_id_ad} jobs/#{stages[stage_n]}"
        end
      end
      if options[:verbose]
        puts qsub_response
      end
      if qsub_response =~ /Your job-array (\d+)\./
        job_id_ad = $1
      end
    end
    if options[:verbose]
      puts "qsub -hold_jid #{job_id_ad} jobs/combine"
    end
    qsub_response = `qsub -hold_jid #{job_id_ad} jobs/combine`
    if options[:verbose]
      puts qsub_response
    end
  else
    puts "qsub response parse error"
  end
end
   
