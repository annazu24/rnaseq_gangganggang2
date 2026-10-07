/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { FASTQC                 } from '../modules/nf-core/fastqc/main'
include { MULTIQC                } from '../modules/nf-core/multiqc/main'
include { paramsSummaryMap       } from 'plugin/nf-schema'
include { paramsSummaryMultiqc   } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText } from '../subworkflows/local/utils_nfcore_rnaseqgangganggang_pipeline'

include { TRIMGALORE             } from '../modules/nf-core/trimgalore/main'
include { STAR_GENOMEGENERATE    } from '../modules/nf-core/star/genomegenerate/main'
include { STAR_ALIGN             } from '../modules/nf-core/star/align/main'
include { SALMON_INDEX           } from '../modules/nf-core/salmon/index/main'
include { SALMON_QUANT           } from '../modules/nf-core/salmon/quant/main'
include { PICARD_MARKDUPLICATES  } from '../modules/nf-core/picard/markduplicates/main' 
include { BBMAP_BBSPLIT          } from '../modules/nf-core/bbmap/bbsplit/main' 
include { SORTMERNA              } from '../modules/nf-core/sortmerna/main'
include { SAMTOOLS_FAIDX         } from '../modules/nf-core/samtools/faidx/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow RNASEQGANGGANGGANG {

    take:
    ch_samplesheet // channel: samplesheet read in from --input
    multiqc_config
    multiqc_logo
    multiqc_methods_description
    outdir

    main:

    def ch_versions = channel.empty()
    def ch_multiqc_files = channel.empty()
    //
    // MODULE: Run FastQC
    //
    FASTQC(ch_samplesheet)
    ch_multiqc_files = ch_multiqc_files.mix(FASTQC.out.zip.map{ _meta, file -> file })

    

    // MODULE: Run Trim Galore
    //
    TRIMGALORE(ch_samplesheet)
    ch_trimmed_out = TRIMGALORE.out.reads
    ch_multiqc_files = ch_multiqc_files.mix(TRIMGALORE.out.json.map{ _meta, file -> file })


    // MODULE: Run BBSplit
    //
    // INPUT
    //
    ch_bbsplit_index = channel.value([])
    //
    //contamination fasta:
    // REad in Csv file and parse into single commands
    ch_bbsplit_contam = params.bbsplit_fasta_list ? 
        channel.value(
            file(params.bbsplit_fasta_list)
                .readLines()
                .findAll { it.trim() }
                .collect { line -> line.split(',') }
                .with { lines ->
                    def names = lines.collect { it[0].trim() }
                    def paths = lines.collect { file(it[1].trim()) }
                    return [ names, paths ]
                }
        ) : 
        channel.value([ [], [] ])

    //ch_bbsplit_contam = channel.value(file(params.bbsplit_fasta_list))

    //primary ref:
    ch_bbsplit_primary_ref = channel.value(file(params.fasta))

    //only build index:
    ch_only_build_index = false

    // test:
    // primary ref mouse chr 19
    //contaminants list
    //ch_bbsplit_primary_ref_mouse19 = channel.value(file(params.fasta))
    //ch_bbsplit_contaminants_test = channel.value(file(params.bbsplit_fasta_list))


    BBMAP_BBSPLIT(ch_trimmed_out, ch_bbsplit_index, ch_bbsplit_primary_ref, ch_bbsplit_contam, ch_only_build_index)
    ch_bbsplit_out = BBMAP_BBSPLIT.out.primary_fastq
    ch_multiqc_files = ch_multiqc_files.mix(BBMAP_BBSPLIT.out.stats.map { _meta, file -> file })



    // MODULE: Run sortmerna
    //
    // INPUT
    //
    //reads, fastas, index
    ch_sortmerna_fastas = channel.value([[id:'rRNA_ref'], files(params.sortmerna_fastas, checkIfExists: true)])
    ch_sortmerna_index = channel.value([[id:'ref'],[]])
    //
    SORTMERNA(ch_bbsplit_out, ch_sortmerna_fastas, ch_sortmerna_index)
    ch_sortmerna_out = SORTMERNA.out.reads
    ch_multiqc_files = ch_multiqc_files.mix(SORTMERNA.out.log.map { _meta, file -> file })


    // MODULE: Run star_genomegenerate
    //
    // INPUT
    //
    // fasta, gtf
    ch_star_fasta = channel.value([[id: 'ref'],file(params.fasta)])
    ch_star_gtf = channel.value([[id: 'ref'],file(params.gtf)])
    //
    STAR_GENOMEGENERATE(ch_star_fasta, ch_star_gtf)
    ch_star_index = STAR_GENOMEGENERATE.out.index



    // MODULE: Run star_align
    //
    // INPUT
    //
    // index, gtf, fasta reference, reads, star_ignorme ->false
    ch_star_ignore_sjdbgtf = channel.value(false)
    ch_star_gtf = channel.value([[id: 'ref'],[file(params.gtf)]])
    ch_star_fasta = channel.value([[id: 'ref'],file(params.fasta)])
    //
    STAR_ALIGN(ch_sortmerna_out, ch_star_index, ch_star_gtf, ch_star_ignore_sjdbgtf)
    //bam transcript for salmon
    //ch_star_out = STAR_ALIGN.out.
    ch_multiqc_files = ch_multiqc_files.mix(STAR_ALIGN.out.log_final.map { _meta, file -> file })

    //bam for pic MarkDups:
    ch_star_bam = STAR_ALIGN.out.bam_sorted
    // bam transcripts for saalmon.
    ch_star_bam_transcript = STAR_ALIGN.out.bam_transcript

/*
Testen

   // MODULE: Run salmon
    //
    //INPUT
    //
    //reads, index, gtf, transcript_fasta
    ch_salmon_index = channel.value([])
    ch_salmon_gtf = channel.value(file(params.gtf))
    ch_salmon_transcript_fasta = channel.value(file(params.transcript_fasta))

    //
    SALMON_QUANT(ch_star_bam_transcript, ch_salmon_index, ch_salmon_gtf, ch_salmon_transcript_fasta)
    ch_salmon_out = SALMON_QUANT.out.results
    ch_multiqc_files = ch_multiqc_files.mix()



    // MODULE: Run SAMTOOLS_FAIDX
    //
    // INPUT
    //
    // fasta, fai, get_size
    ch_samtools_fasta = channel.value([file(params.fasta)])
    ch_samtools_fai = channel.value([])
    ch_samtools_get_sizes = channel.value(false)
    //
    SAMTOOLS_FAIDX(ch_samtools_fasta, ch_samtools_fai, ch_samtools_get_sizes)
    ch_samtools_fa_index = SAMTOOLS_FAIDX.out.fai



    // MODULE: Run picard MarkDuplicates
    //
    // INPUT
    //
    // reads fasta fai
    ch_picard_fasta = channel.value(file(params.fasta))
    //ch_picard_fai = channel.value(file(params.fai))
    ch_picard_fai = ch_samtools_fa_index
    //
    PICARD_MARKDUPLICATES(ch_star_bam, ch_picard_fasta, ch_picard_fai)
    //
    ch_pic_mark_dups_out = PICARD_MARKDUPLICATES.out.bam
    ch_multiqc_files = ch_multiqc_files.mix(PICARD_MARKDUPLICATES.out.metrics.map { _meta, file -> file })



    */

    //
    // Collate and save software versions
    //
    def topic_versions = channel.topic("versions")
        .distinct()
        .branch { entry ->
            versions_file: entry instanceof Path
            versions_tuple: true
        }

    def topic_versions_string = topic_versions.versions_tuple
        .map { process, tool, version ->
            [ process[process.lastIndexOf(':')+1..-1], "  ${tool}: ${version}" ]
        }
        .groupTuple(by:0)
        .map { process, tool_versions ->
            tool_versions.unique().sort()
            "${process}:\n${tool_versions.join('\n')}"
        }

    def ch_collated_versions = softwareVersionsToYAML(ch_versions.mix(topic_versions.versions_file))
        .mix(topic_versions_string)
        .collectFile(
            storeDir: "${outdir}/pipeline_info",
            name: 'nf_core_'  +  'rnaseqgangganggang_software_'  + 'mqc_'  + 'versions.yml',
            sort: true,
            newLine: true
        )

    //
    // MODULE: MultiQC
    //
    ch_multiqc_files = ch_multiqc_files.mix(ch_collated_versions)
    def ch_summary_params = paramsSummaryMap(workflow, parameters_schema: "nextflow_schema.json")
    def ch_workflow_summary = channel.value(paramsSummaryMultiqc(ch_summary_params))
    ch_multiqc_files = ch_multiqc_files.mix(ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    def ch_multiqc_custom_methods_description = multiqc_methods_description
        ? file(multiqc_methods_description, checkIfExists: true)
        : file("${projectDir}/assets/methods_description_template.yml", checkIfExists: true)
    def ch_methods_description = channel.value(methodsDescriptionText(ch_multiqc_custom_methods_description))
    ch_multiqc_files = ch_multiqc_files.mix(ch_methods_description.collectFile(name: 'methods_description_mqc.yaml', sort: true))
    MULTIQC(
        ch_multiqc_files.flatten().collect().map { files ->
            [
                [id: 'rnaseqgangganggang'],
                files,
                multiqc_config
                    ? file(multiqc_config, checkIfExists: true)
                    : file("${projectDir}/assets/multiqc_config.yml", checkIfExists: true),
                multiqc_logo ? file(multiqc_logo, checkIfExists: true) : [],
                [],
                [],
            ]
        }
    )
    emit:multiqc_report = MULTIQC.out.report.map { _meta, report -> [report] }.toList() // channel: /path/to/multiqc_report.html
    versions       = ch_versions                 // channel: [ path(versions.yml) ]
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
