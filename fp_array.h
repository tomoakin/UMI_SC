#include <stdio.h>

/* public declarations */

typedef struct _fp_array{
  FILE** base;
  size_t used_slots;
  size_t allocated_slots;
} fp_array;

fp_array* fp_array_init(fp_array*);

int fp_array_set(fp_array*, int, FILE*);

FILE* fp_array_get(fp_array*, int);
