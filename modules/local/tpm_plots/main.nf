process TPM_PLOTS {
    tag "$meta.id"
    container 'community.wave.seqera.io/library/pip_matplotlib_numpy_pandas_pruned:9ec1028395e578b4'

    input:
    tuple val(meta), path(tpm)

    output:
    tuple val(meta), path("*.png"), emit: png

    script:
    def prefix = task.ext.prefix ?: "${meta.id}_tpm_overview_${workflow.profile.replace(',', '_')}"
    """
    plot_tpm.py ${tpm} ${prefix} "${workflow.profile}"
    """
}