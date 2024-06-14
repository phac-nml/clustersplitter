/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    PRINT PARAMS SUMMARY
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { paramsSummaryLog; paramsSummaryMap; fromSamplesheet  } from 'plugin/nf-validation'


/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//
include { LOCIDEX_MERGE } from '../modules/local/locidex/merge/main'
include { MAP_TO_TSV } from '../modules/local/map_to_tsv.nf'
include { ARBORATOR } from '../modules/local/arborator/main'
include { ARBOR_VIEW } from '../modules/local/arborview'
include { BUILD_CONFIG } from '../modules/local/buildconfig/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Installed directly from nf-core/modules
//
include { CUSTOM_DUMPSOFTWAREVERSIONS } from '../modules/nf-core/custom/dumpsoftwareversions/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/


workflow CLUSTER_SPLITTER {

    ID_COLUMN = "sample"
    ch_versions = Channel.empty()
    input = Channel.fromSamplesheet("input")

    metadata_headers = Channel.value(
        tuple(
            ID_COLUMN, params.metadata_partition_name,
            params.metadata_1_header, params.metadata_2_header,
            params.metadata_3_header, params.metadata_4_header,
            params.metadata_5_header, params.metadata_6_header,
            params.metadata_7_header, params.metadata_8_header)
        )

    metadata_rows = input.map{
        meta, mlst_files -> tuple(meta.id, meta.metadata_partition,
        meta.metadata_1, meta.metadata_2, meta.metadata_3, meta.metadata_4,
        meta.metadata_5, meta.metadata_6, meta.metadata_7, meta.metadata_8)
    }.toList()

    profiles_merged = LOCIDEX_MERGE(input.map{
        meta, alleles -> alleles
    }.collect())
    ch_versions = ch_versions.mix(profiles_merged.versions)

    merged_metadata = MAP_TO_TSV(metadata_headers, metadata_rows).tsv_path
    arborator_config = BUILD_CONFIG(metadata_headers).config

    arborator_output = ARBORATOR(
        merged_profiles=profiles_merged.combined_profiles,
        metadata=merged_metadata,
        configuration_file=arborator_config,
        id_column=ID_COLUMN,
        partition_col=params.metadata_partition_name,
        thresholds=params.ar_thresholds)

    ch_versions = ch_versions.mix(arborator_output.versions)

    trees = arborator_output.trees.flatten().map {
        tuple(it.getParent().getBaseName(), it)
    }

    metadata_for_trees = arborator_output.metadata.flatten().map{
        tuple(it.getParent().getBaseName(), it)
    }

    trees_meta = trees.join(metadata_for_trees)
    tree_html = file(params.av_html)
    ARBOR_VIEW(trees_meta, tree_html)

    CUSTOM_DUMPSOFTWAREVERSIONS (
        ch_versions.unique().collectFile(name: 'collated_versions.yml')
    )
}


/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
