#include<stdio.h>
#include "trie.h"

int trie_store_data(DNA_trie* trie, const char * key, uint32_t data);

uint32_t trie_find_data(DNA_trie * trie, const char * key);

int
main()
{
  DNA_trie t;
  uint32_t d;
  trie_init(&t);
  trie_store_data(&t, "ACGTNA", 3);
  trie_store_data(&t, "ACGTNN", 4);
  trie_store_data(&t, "ACGTNAA", 5);
  d = trie_find_data(&t, "ACGTNA");
  printf("recovered: %u\n", d);
  d = trie_find_data(&t, "ACGT");
  printf("recovered: %u\n", d);
  d = trie_find_data(&t, "ACGTNN");
  printf("recovered: %u\n", d);
  d = trie_find_data(&t, "ACGTNAA");
  printf("recovered: %u\n", d);
}
