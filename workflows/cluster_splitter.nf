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

include { IRIDA_NEXT_OUTPUT    } from '../modules/local/iridanextoutput/main'
include { LOCIDEX_MERGE } from '../modules/local/locidex/merge/main'
include { MAP_TO_TSV } from '../modules/local/map_to_tsv.nf'
include { ARBORATOR } from '../modules/local/arborator/main'
include { ARBOR_VIEW } from '../modules/local/arborview'

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



def prepareFilePath(String filep, GString debug_msg){
    // Rerturns null if a file is not valid
    def return_path = null
    if(filep){
        file_in = file(filep) // for some reason using path here does not work, but file does...
        if(file_in.exists()){
            return_path = file_in
            log.debug debug_msg
        }
    }else{
        return_path = []
    }

    return return_path // empty value if file argument is null
}

workflow CLUSTER_SPLITTER {

    /*
    ID column (ID_COLUMN) is set to define the field containing the ID of the samples in Arborator, as the
    metadata is merged within nextflow we are using the 'id' field from our meta map. As this will
    match the header in the prepared metadata file

    Replace ID name (REPLACE_ID_NAME) is set as we will rename the first header of the locidex merged output to match what we
    are creating when we aggreagate the metadata while also keeping in line with nf-core satandards. As we must
    specify and ID column in arborator to merge the two datasets on, however locidex merge outputs a header called 'sample_id'
    that we cannot change

    Partition column (PARTITION_COLUMN) is set to the first metadata field in the defined in nextflow_schema.json.
    as it is a string constant it will be listed here and it is marked as mandatory.
    */
    ID_COLUMN = "id"
    REPLACE_ID_NAME = "sample_id"
    PARTITION_COLUMN = "md_1"



    ch_versions = Channel.empty()

    // Create a new channel of metadata from a sample sheet
    // NB: `input` corresponds to `params.input` and associated sample sheet schema
    input = Channel.fromSamplesheet("input")

    // Merge allele profiles
    replace_vals = Channel.value(tuple(REPLACE_ID_NAME, ID_COLUMN))

    profiles_merged = LOCIDEX_MERGE(input.map{
        meta, alleles -> alleles
    }.collect(), replace_vals)
    ch_versions = ch_versions.mix(profiles_merged.versions)

    merged_metadata = MAP_TO_TSV(input.map {
        meta, alleles -> meta
    }.collect())


    arborator_config = prepareFilePath(params.ar_config, "Selecting ${params.ar_config} for --ar_config")
    if(!arborator_config){
        exit 1, "${params.ar_config} does not exist. Exiting the pipeline now"
    }

    arbys_out = ARBORATOR(
        merged_profiles=profiles_merged.combined_profiles,
        metadata=merged_metadata,
        configuration_file=arborator_config,
        id_column=ID_COLUMN,
        partition_col=PARTITION_COLUMN,
        thresholds=params.ar_thresholds)

    ch_versions = ch_versions.mix(arbys_out.versions)

    trees = arbys_out.trees.flatten().map {
        tuple(it.getParent().getBaseName(), it)
    }

    metadata_for_trees = arbys_out.metadata.flatten().map{
        tuple(it.getParent().getBaseName(), it)
    }

    trees_meta = trees.join(metadata_for_trees)
    tree_html = file(params.av_html)
    ARBOR_VIEW(trees_meta, tree_html)


    //IRIDA_NEXT_OUTPUT (
    //    samples_data=ch_simplified_jsons
    //)
    //ch_versions = ch_versions.mix(IRIDA_NEXT_OUTPUT.out.versions)

    CUSTOM_DUMPSOFTWAREVERSIONS (
        ch_versions.unique().collectFile(name: 'collated_versions.yml')
    )
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    COMPLETION EMAIL AND SUMMARY
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow.onComplete {
    if (params.email || params.email_on_fail) {
        NfcoreTemplate.email(workflow, params, summary_params, projectDir, log)
    }
    NfcoreTemplate.dump_parameters(workflow, params)
    NfcoreTemplate.summary(workflow, params, log)
    if (params.hook_url) {
        NfcoreTemplate.IM_notification(workflow, params, summary_params, projectDir, log)
    }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
