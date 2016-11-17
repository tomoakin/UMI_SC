#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <malloc.h>
#include "trie.h"
#include "fp_array.h"

int
load_sample(FILE*infile, DNA_trie*trie, fp_array *fp_a)
{
  char * linebuf;
  char * retval;
  int record_count=0;
  size_t line_bufsz = 16000;/*large enough*/
  size_t block_bufsz = 16*1024*1024; /* 16 MiB */
  char*filename_i,*filename_r;
  linebuf = malloc(line_bufsz);
  filename_i = malloc(line_bufsz);
  filename_r = malloc(line_bufsz);

  while((retval = fgets(linebuf, line_bufsz, infile))){
    char*index;
    char*sample_name;
    FILE* f_i;
    FILE* f_r;
    char * block_buf_i,*block_buf_r;
    retval = strtok(linebuf, " \t\n");
    index = strdup(retval);
    retval = strtok(NULL, " \t\n");
    sample_name = strdup(retval);
    /*fprintf(stderr, "sample name: %s\n", sample_name);*/
    record_count ++;
    snprintf(filename_i, line_bufsz, "%s_index.fq", sample_name);
    snprintf(filename_r, line_bufsz, "%s_read.fq", sample_name);
    /* may truncate but should succeed */
    f_i = fopen(filename_i, "w");
    if(!f_i){
      fprintf(stderr, "failed to open file: %s\n", filename_i);
      perror("");
      exit(1);
    }
    f_r = fopen(filename_r, "w");
    if(!f_r){
      fprintf(stderr, "failed to open file: %s\n", filename_r);
      perror("");
      exit(1);
    }
    block_buf_i = malloc(block_bufsz);
    block_buf_r = malloc(block_bufsz);
    if(!block_buf_r||!block_buf_i) exit(1);
    setvbuf(f_i, block_buf_i ,_IOFBF, block_bufsz);
    setvbuf(f_r, block_buf_r ,_IOFBF, block_bufsz);
    fp_array_set(fp_a, record_count * 2 - 1, f_i);
    fp_array_set(fp_a, record_count * 2, f_r);
/*
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
 */
    {
      int i;
      int ilen= strlen(index);
      char *mindex = strdup(index);
      for(i=0; i < ilen; i++){
        int j;
        char*DNA_chars="ACGTN";
        for(j=0; j<5; j++){
          mindex[i]=DNA_chars[j];
          trie_store_data(trie, mindex, record_count);
        }
        mindex[i] = index[i];
      }
      free(mindex);
    }
    free(sample_name);
    free(index);
  }
  free(filename_i);
  free(filename_r);
  return record_count;
}
