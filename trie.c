#include<malloc.h>
#include<stdlib.h>
#include<stdint.h>
#include "trie.h"

void
trie_expand(DNA_trie* trie)
{
  size_t new_alloc = trie-> allocated_nodes * 3 >> 1;
  DNA_trie_node* retval = realloc(trie->base, new_alloc * sizeof(DNA_trie_node));
  if(!retval) exit(1);
  trie -> allocated_nodes = new_alloc;
}

uint32_t
trie_get_new_node(DNA_trie* trie)
{
  uint32_t new_node = trie-> used_nodes + 1;
  if (new_node >= trie-> allocated_nodes) trie_expand(trie);
  trie->used_nodes = new_node;
  trie->base[new_node].node_A = 0;
  trie->base[new_node].node_C = 0;
  trie->base[new_node].node_G = 0;
  trie->base[new_node].node_T = 0;
  trie->base[new_node].node_N = 0;
  trie->base[new_node].data = 0;
  return new_node;
}

DNA_trie*
trie_init(DNA_trie* trie)
{
  size_t default_size = 10000;
  if(trie == NULL) return NULL;
  trie->base = malloc(default_size * sizeof(DNA_trie_node));
  if(trie->base == NULL){
    return NULL;
  }
  trie->allocated_nodes=default_size;
  trie->used_nodes = 0;
  trie_get_new_node(trie); /*init root node*/
  return trie;
}

int
trie_store_data(DNA_trie* trie, const char * key, uint32_t data)
{
  const char *p = key;
  uint32_t cur_node = 1;
  uint32_t next_node = 0;
  while(*p){
    switch(*p){
      case 'A':
        next_node = trie->base[cur_node].node_A;
        if(next_node == 0){
          next_node = trie_get_new_node(trie);
          trie->base[cur_node].node_A = next_node;
        }
        break;
      case 'C':
        next_node = trie->base[cur_node].node_C;
        if (next_node == 0){
          trie->base[cur_node].node_C = trie_get_new_node(trie);
          next_node = trie->base[cur_node].node_C;
        }
        break;
      case 'G':
        next_node = trie->base[cur_node].node_G;
        if (next_node == 0){
          trie->base[cur_node].node_G = trie_get_new_node(trie);
          next_node = trie->base[cur_node].node_G;
        }
        break;
      case 'T':
        next_node = trie->base[cur_node].node_T;
        if (next_node == 0){
          trie->base[cur_node].node_T = trie_get_new_node(trie);
          next_node = trie->base[cur_node].node_T;
        }
        break;
      case 'N':
        next_node = trie->base[cur_node].node_N;
        if (next_node == 0){
          trie->base[cur_node].node_N = trie_get_new_node(trie);
          next_node = trie->base[cur_node].node_N;
        }
        break;
      default:
        return 0;
        /* Illegal charactor in key*/
    }
    cur_node = next_node;
    p++;
  }
  trie->base[cur_node].data = data;
  return 1;
}

uint32_t
trie_find_data(DNA_trie * trie, const char * key)
{
  const char *p = key;
  uint32_t cur_node = 1;
  uint32_t next_node = 0;
  while(*p){
    switch(*p){
      case 'A':
        next_node = trie->base[cur_node].node_A;
        break;
      case 'C':
        next_node = trie->base[cur_node].node_C;
        break;
      case 'G':
        next_node = trie->base[cur_node].node_G;
        break;
      case 'T':
        next_node = trie->base[cur_node].node_T;
        break;
      case 'N':
        next_node = trie->base[cur_node].node_N;
        break;
      default:
        return 0;
    }
    cur_node = next_node;
    p++;
  }
  return trie->base[cur_node].data;
}
