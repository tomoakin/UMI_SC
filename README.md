# UMI_SC
This package is designed to extract count data from unique molecule identifier (UMI) tagged
sequence data.

The bulk read data are first sorted to individual samples based on the index sequence.
At the same time, the UMI sequence is prepended to the read name.
The split read data are mapped to the reference using bowtie with a parameter set standardly
used by RSEM.
The mapped data are sorted to the readname, which sorts the UMI.
For each UMI, the alignment are checked per gene-wise, and a single read is chosen for each UMI/gene combination.


# Usage
First, you generate makefile and other scripts as

    ruby $HOME/UMI_SC/makescripts.rb -i index_umi_read18.fq.gz \
              -r main_read.fq.gz \
              -s index.list \
              -t $HOME/Ppatens/v3.3/Ppatrans2genemap \
              -R $HOME/Ppatens/v3.3/PpatensV3.3 

After having generated Makefile by above command, you may simply
    make all
to do on a single machine.
Alternatively,
    qsub jobs/split_fq
    qsub -hold_jid [jobid shown by the above command] jobs/rsem
    qsub -hold_jid [jobid shown by the above command] jobs/combine
can be used to submit to a grid endgine (SGE/UGE) controled cluster machines. 
Note the second job are run in multiple nodes as an array job.  
The parameters for the job may be edited manually
before submission to the grid engine.

The script generation and submission can be done in one command
    ruby $HOME/UMI_SC/makescripts.rb -i index_umi_read18.fq.gz \
              -r main_read.fq.gz \
              -s index.list \
              -t $HOME/Ppatens/v3.3/Ppatrans2genemap \
              -R $HOME/Ppatens/v3.3/PpatensV3.3 \
              -g grid.cnf \
              --submit -v

# Input data
As input data, this program requires sequence and sample information files. 
* read data fastq files
** read data file containing cDNA sequences 
** index read data file containing 8 nt index and 12 nt unique molecule identifier sequence
* sample information file: tabseparated file of index sequence and sample name. sample name should be consisting of characters that can be used for file names (i.e., no /, no :).

* For reference, a reference created with rsem-prepare-reference and the transcript-to-gene-map
should be specified.


# Installation

## Requirements
This package requries the following programs (tested version)
* ruby (2.3)
* samtools (1.3.1)
* bowtie (1.1.2)
* RSEM (rsem-1.3.0)
If these programs are not installed, you can install with LPM.


