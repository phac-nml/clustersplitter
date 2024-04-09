/*
    Convert a list of lazyMaps into a tsv for later passing into arborator
*/



process MAP_TO_TSV {
    tag "Aggregating data for TSV"
    cache "false"


    input:
    val(metadata) // [[id: stuff], [id: more_stuff]]


    output:
    path output_place

    exec:
    def output_file = "aggregated_data.tsv"
    if (metadata.size() < 0 ){
        log.error "Metadata fields are empty"
        exit 1, "Metadata fields are empty"
    }

    def delimiter = '\t'
    output_place = task.workDir.resolve(output_file)
    headers = metadata[0].keySet()

    output_place.withWriter{ writer ->

        writer.writeLine "${headers.join(delimiter)}"
        metadata.each{ value ->
            writer.writeLine "${value.values().join(delimiter)}"
        }
    }

}
