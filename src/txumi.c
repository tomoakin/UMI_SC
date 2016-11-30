#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <ctype.h>
#include <unistd.h>
#include <assert.h>

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

void usage()
{
  fputs("txumi [-l index_length] index.fq read.fq", stderr);
}

int
main(int argc, char**argv)
{
  FILE* filei;
  FILE* filer;

  fq_entry* fqi;
  fq_entry* fqr;
  int optchar;
  int index_length = 8;
  while((optchar = getopt(argc,argv,"l:"))!= -1){
    switch(optchar){
      case 'l':
        index_length = strtol(optarg, NULL, 0);
        break;
    }
  }
  if(argc - optind != 2){
    usage();
    exit(EXIT_FAILURE);
  }
  filei = fopen(argv[optind],"r");
  if(!filei){
    fprintf(stderr, "failed to open file: %s\n", argv[optind+1]);
    perror("");
    exit(1);
  }
  filer = fopen(argv[optind+1],"r");
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
#  p curbarcode
  puts "@#{ie.sequence_string[barcode_length..-1]}#{re.entry_id}\n#{re.sequence_string}\n+\n#{re.quality_string}\n"
*/
    { 
      char umi[100];
      int charindex = 0;
      char barcode[index_length + 1];
      strncpy(barcode, fqi->seq, index_length);
      barcode[index_length] = '\0';
      while(*(fqi->seq + index_length + charindex) != '\n'){
        umi[charindex] = *(fqi->seq + index_length + charindex);
        charindex ++;
        if(charindex >= 99 || *(fqi->seq + index_length + charindex) == '\0'){
           break;
        }
      }
      umi[charindex] = '\0';
      putchar('@');
      fwrite(umi, charindex, 1, stdout);
      fwrite(fqr->entry+1,fqr->entry_size - 1, 1, stdout);
    }
  }
  return EXIT_SUCCESS;
}


