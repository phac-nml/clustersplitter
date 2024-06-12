/*
    Convert a list of lazyMaps into a tsv for later passing into arborator
*/

process MAP_TO_TSV {
    tag "aggregate_tsv"
    label 'process_single'

    input:
    val metadata_headers
    val metadata_rows

    output:
    path(output_place), emit: tsv_path

    exec:
    def output_file = "aggregated_data.tsv"
    if (metadata_headers.size() <= 0 || metadata_rows.size() <= 0){
        log.error "Metadata fields are empty"
        exit 1, "Metadata fields are empty"
    }

    def delimiter = '\t'
    output_place = task.workDir.resolve(output_file)

    output_place.withWriter{ writer ->

        writer.writeLine "${metadata_headers.join(delimiter)}"

        metadata_rows.each{ row ->
            writer.writeLine "${row.join(delimiter)}"
        }
    }
}
