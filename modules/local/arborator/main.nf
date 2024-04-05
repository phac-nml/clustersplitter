/* Main module for arborator

*/


process ARBORATOR {
    tag "Divide and Cluster"
    label 'process_high'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
    'https://depot.galaxyproject.org/singularity/arborator%3A1.0.0--pyhdfd78af_1' :
    'quay.io/biocontainers/arborator:1.0.0--pyhdfd78af_1' }"


    input:
    path merged_profiles // The allelic profiles
    path metadata // Contextual data, also holds the partition column field
    path configuration_file // A file specifying varying thresholds?
    val id_column // Primary key aligning merged profiles and metadata
    val partition_column // Column to split samples on
    val thresholds // String of thresholds e.g. 10,9,8,7,6,5,4,3,2,1

    output:
    path("${prefix}/*/*"), emit: split_groupds
    path("${prefix}/cluster_summary.tsv"), emit: cluster_summary
    path("${prefix}/metadata.excluded.tsv"), emit: metadata_exluded
    path("${prefix}/metadata.included.tsv"), emit: metadata_included
    path("${prefix}/threshold_map.json"), emit: threshold_map
    path("${prefix}/run.json"), emit: run_json
    path "versions.yml", emit: versions


    script:
    prefix = "output_folder"
    """
    arborator --profile $merged_profiles --metadata $metadata \\
    --config $configuration_file --outdir $prefix \\
    --id_col $id_column --partition_col $partition_column \\
    --thresholds $thresholds

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        arborator : \$(echo \$(arborator -V 2>&1) | sed 's/arborator //')
    END_VERSIONS
    """
}
