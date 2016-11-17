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
  int length;
  int entry_size;
  char *seq;
  char *entry;
} fq_entry;
void free_fqentry(fq_entry* entry)
{
  free(entry->entry);
  free(entry);
}
fq_entry*
get_fqentry(FILE* in, fq_entry*fqe)
{
  char*str;
  int charindex;
  int curchar;
  str = fqe->entry;
  fqe -> length = 0;
  charindex = 0;
  /* first id line */
  while((curchar=fgetc(in))!=EOF){
    str[charindex] = curchar;
    charindex += 1;
    if(curchar == '\n'){
      break;
    }
  }
  if(curchar == EOF) return NULL;
  fqe->seq = str + charindex;
  while((curchar=fgetc(in))!=EOF){
    str[charindex] = curchar;
    charindex += 1;
    if(curchar == '\n'){
      break;
    }
    fqe->length += 1;
  }
  /* second id line */
  while((curchar=fgetc(in))!=EOF){
    str[charindex] = curchar;
    charindex += 1;
    if(curchar == '\n'){
      break;
    }
  }
  /* the qv line */
  while((curchar=fgetc(in))!=EOF){
    str[charindex] = curchar;
    charindex += 1;
    if(curchar == '\n'){
      break;
    }
  }
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
  f_r = fopen("unknown_read.fq", "w");
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
  filer = fopen(argv[optind+2],"r");
  fqi = malloc(sizeof(fq_entry));
  fqr = malloc(sizeof(fq_entry));
  fqi->entry = malloc(bufsize);
  fqr->entry = malloc(bufsize);
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
      char *barcode = strndup(fqi->seq,index_length);
  //    fprintf(stderr, "%s\n", barcode); 
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
  //    fprintf(stderr, "%s\t%d\n", umi,charindex);
      fputc('@', ofp_i);
      fputc('@', ofp_r);
      fwrite(umi, charindex, 1, ofp_i); /* insert umi in the readname */
      fwrite(umi, charindex, 1, ofp_r);
  //    fprintf(stderr, "%s\t%d\n", fqi->entry+1,fqi->entry_size);
  //    fprintf(stderr, "%s\t%d\n", fqr->entry+1,fqr->entry_size);
      fwrite(fqi->entry+1,fqi->entry_size - 1, 1, ofp_i);
      fwrite(fqr->entry+1,fqr->entry_size - 1, 1, ofp_r);
    }
  }
  return EXIT_SUCCESS;
}


