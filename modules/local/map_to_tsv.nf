/*
    Convert a list of lazyMaps into a tsv for later passing into arborator
*/



process MAP_TO_TSV {
    tag "Aggregating data for TSV"


    input:
    val metadata


    output:
    path(output_file)

    exec:
    output_file = "aggregated_data.tsv"
    if (metadata.size() < 0 ){
        log.error "Metadata fields are empty"
        exit 1
    }
    def delimiter = '\t'
    def output_place = task.workDir.resolve(output_file)
    def headers = metadata[0].keySet()
    output_place.withWriter{ writer ->
        writer.writeLine "${headers.join(delimiter)}"
        metadata.each{ k, v ->
            // using an each loop to write this out, as I do not recall the behaviour of nf-validatoin on missing data fields
            headers.each{ hk, hv ->
                if(v.containsKey(hv)){
                    writer.write("${v[hv]}\t")
                }else{
                    writer.write("\t")
                }
                writer.write("\n")
            }
        }
    }

}
