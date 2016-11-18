
all: sortbarcode1
.PHONY: clean
clean:
	make -C src clean
	rm -f sortbarcode1

sortbarcode1: src/sortbarcode1
	install -cs src/sortbarcode1 .

src/sortbarcode1:
	make -C src
