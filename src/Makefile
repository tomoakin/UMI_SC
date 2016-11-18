all: sortbarcode1

.PHONY: clean
clean:
	rm -f sortbarcode1 load_sample_test
load_sample_test:
	$(CC) -g -O -Wall  load_sample_test.c load_sample.c trie.c fp_array.c -o $@
sortbarcode1:fp_array.c  fp_array.h  load_sample.c sortbarcode1.c trie.c  trie.h
	$(CC) -g -O3 -Wall  sortbarcode1.c load_sample.c trie.c fp_array.c -o $@
