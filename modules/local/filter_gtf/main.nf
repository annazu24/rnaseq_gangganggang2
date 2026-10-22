process FILTER_GTF {
    container 'nf-core/ubuntu:22.04'

    input:
    tuple val(meta), path(gtf)
    path fai

    output:
    tuple val(meta), path("${meta.id}.filtered.gtf"), emit: gtf

    script:
    """
    cut -f1 ${fai} | sort -u > chroms.txt
    awk 'BEGIN{FS=OFS="\\t"} NR==FNR{c[\$1]; next} /^#/ || (\$1 in c)' chroms.txt ${gtf} \\
        | grep -v 'transcript_id ""' > ${meta.id}.filtered.gtf
    """
}