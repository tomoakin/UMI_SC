#include <malloc.h>
#include <stdint.h>
#include <stdio.h>

#include "fp_array.h"

fp_array* 
fp_array_init(fp_array*fp_a)
{
  size_t default_size=100;
  fp_a->used_slots = 0;
  fp_a->base = malloc(sizeof(FILE*)*default_size);
  fp_a->allocated_slots = default_size;
  return fp_a;
}

void
fp_array_expand(fp_array*fp_a, size_t new_size)
{
  fp_a->base = realloc(fp_a->base, sizeof(FILE*)*new_size);
  fp_a->allocated_slots = new_size;
}


int fp_array_set(fp_array* fp_a, int i, FILE* fp)
{
  if(i <= 0) return i;
  if(fp_a->allocated_slots <= i)fp_array_expand(fp_a,i+100);
  fp_a->base[i]=fp;
  return i;
}

FILE* fp_array_get(fp_array* fp_a, int i)
{
  if(i <= 0 || i >= fp_a -> allocated_slots) return NULL;
  return fp_a->base[i];
};

