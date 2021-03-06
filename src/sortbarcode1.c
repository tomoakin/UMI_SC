#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <unistd.h>
#include <assert.h>
#include "trie.h"
#include "fp_array.h"

static const size_t bufsize = 4000;
typedef struct _fqe
{
  int entry_size;
  char *seq;
  char *entry;
} fq_entry;

fq_entry*
get_fqentry(FILE* in, fq_entry*fqe)
{
  char*str;
  int charindex;
  int curchar;
  int ln = 0;
  str = fqe->entry;
  charindex = 0;
  /* first id line */
  while((curchar=fgetc(in))!=EOF){
    str[charindex] = curchar;
    charindex += 1;
    if(curchar == '\n'){
      if (ln == 0) fqe->seq = str + charindex;
      ln ++;
      if (ln ==4)
      break;
    }
  }
  if(curchar == EOF) return NULL;
  fqe->entry_size = charindex;
  str[charindex]='\0';
  return fqe;
}

extern char *optarg;
extern int optind, opterr, optopt;
int load_sample(FILE*infile, DNA_trie*trie, fp_array *fp_a);

void usage()
{
  fputs("sortbarcode1 sample_info index.fq read.fq", stderr);
}
int
main(int argc, char**argv)
{
  FILE* sample_file;
  FILE*filei, *f_i;
  FILE*filer, *f_r;
  
  fq_entry* fqi;
  fq_entry* fqr;
  int optchar;
  int index_length = 8;
  DNA_trie index_hash;
  fp_array fp_a;
  while((optchar = getopt(argc,argv,"l:"))!= -1){
    switch(optchar){
      case 'l':
        index_length = strtol(optarg, NULL, 0);
        break;
    }
  }
  if(argc - optind != 3){
    usage();
    exit(EXIT_FAILURE);
  }
  fp_array_init(&fp_a);
  trie_init(&index_hash);
  sample_file = fopen(argv[optind],"r");
  f_i = fopen("unknown_index.fq", "w");
  if(!f_i){
    fputs("failed to open file: unknown_index.fq", stderr);
    perror("");
    exit(1);
  }
  f_r = fopen("unknown_read.fq", "w");
  if(!f_r){
    fputs("failed to open file: unknown_read.fq\n", stderr);
    perror("");
    exit(1);
  }
  {
    size_t block_bufsz = 16*1024*1024;
    char* block_buf_i = malloc(block_bufsz);
    char* block_buf_r = malloc(block_bufsz);
    if(!block_buf_r||!block_buf_i) exit(1);
    setvbuf(f_i, block_buf_i ,_IOFBF, block_bufsz);
    setvbuf(f_r, block_buf_r ,_IOFBF, block_bufsz);
  }
  load_sample(sample_file, &index_hash, &fp_a);
  filei = fopen(argv[optind+1],"r");
  if(!filei){
    fprintf(stderr, "failed to open file: %s\n", argv[optind+1]);
    perror("");
    exit(1);
  }
  filer = fopen(argv[optind+2],"r");
  if(!filer){
    fprintf(stderr, "failed to open file: %s\n", argv[optind+2]);
    perror("");
    exit(1);
  }
  fqi = malloc(sizeof(fq_entry));
  fqr = malloc(sizeof(fq_entry));
  if(!fqr||!fqi) exit(1);
  fqi->entry = malloc(bufsize);
  fqr->entry = malloc(bufsize);
  if(!fqr->entry||!fqi->entry) exit(1);
  while((fqi = get_fqentry(filei, fqi))){
    fqr = get_fqentry(filer, fqr);

/*
  curbarcode = ie.sequence_string[0,barcode_length].upcase
#  p curbarcode
  sample = "unknown"
  sample = barcode2sample[curbarcode] unless barcode2sample[curbarcode] == nil
  sampleif[sample].puts "@#{ie.sequence_string[barcode_length..-1]}#{ie.entry_id}\n#{ie.sequence_string}\n+\n#{ie.quality_string}\n"
  samplerf[sample].puts "@#{ie.sequence_string[barcode_length..-1]}#{re.entry_id}\n#{re.sequence_string}\n+\n#{re.quality_string}\n"
*/
    { 
      FILE *ofp_i, *ofp_r;
      uint32_t sample_number;
      char umi[100];
      int charindex = 0;
      char barcode[index_length + 1];
      strncpy(barcode, fqi->seq, index_length);
      barcode[index_length] = '\0';
      sample_number = trie_find_data(&index_hash, barcode);
      if(sample_number){
        ofp_i = fp_array_get(&fp_a, sample_number * 2 - 1);
        ofp_r = fp_array_get(&fp_a, sample_number * 2);
      }else{
        ofp_i = f_i;
        ofp_r = f_r;
      }
      while(*(fqi->seq + index_length + charindex) != '\n'){
        umi[charindex] = *(fqi->seq + index_length + charindex);
        charindex ++;
        if(charindex >= 99 || *(fqi->seq + index_length + charindex) == '\0'){
           break;
        }
      }
      umi[charindex] = '\0';
      fputc('@', ofp_i);
      fwrite(umi, charindex, 1, ofp_i); /* insert umi in the readname */
      fwrite(fqi->entry+1,fqi->entry_size - 1, 1, ofp_i);
      fputc('@', ofp_r);
      fwrite(umi, charindex, 1, ofp_r);
      fwrite(fqr->entry+1,fqr->entry_size - 1, 1, ofp_r);
    }
  }
  return EXIT_SUCCESS;
}


