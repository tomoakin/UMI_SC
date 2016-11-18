#include<stdint.h>
/* public declarations */
typedef struct _DNA_trie_node{
  uint32_t node_A;
  uint32_t node_C;
  uint32_t node_G;
  uint32_t node_T;
  uint32_t node_N;
  uint32_t data;
} DNA_trie_node;

typedef struct _DNA_trie{
  DNA_trie_node * base;
  size_t used_nodes;
  size_t allocated_nodes;
} DNA_trie;

DNA_trie* trie_init(DNA_trie* trie);

int trie_store_data(DNA_trie* trie, const char * key, uint32_t data);

uint32_t trie_find_data(DNA_trie * trie, const char * key);
