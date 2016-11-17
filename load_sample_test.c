#include <stdio.h>
#include "trie.h"
#include "fp_array.h"

int
load_sample(FILE*infile, DNA_trie*trie, fp_array *fp_a);

int
main(int argc, char **argv)
{
  FILE* infile;
  DNA_trie index_hash;
  fp_array fp_a;
  if(argc <2) return 1;
  infile = fopen(argv[1],"r");
  fp_array_init(&fp_a);
  trie_init(&index_hash);
  load_sample(infile, &index_hash, &fp_a);
  return 0;
}
