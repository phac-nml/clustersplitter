import groovy.json.JsonSlurper
import groovy.json.JsonOutput

process BUILD_CONFIG {
    tag "Build Arborator Config"
    label 'process_single'

    input:
    val metadata_headers
    // tuple(ID (header name), metadata_partition_name, metadata_1_header, .. , metadata_8_header)

    output:
    path("config.json"), emit: config

    exec:
    // The lookup JSON:
    def lookup_config_file = new File("$baseDir/assets/config_lookup.json")
    def lookup_config_json = new JsonSlurper().parse(lookup_config_file)

    def GROUPED_METADATA = "grouped_metadata_columns"
    def lookup_config_grouped = lookup_config_json[GROUPED_METADATA]
    def LINELIST = "linelist_columns"
    def lookup_config_linelist = lookup_config_json[LINELIST]

    // The built JSON data:
    def json_data = [:]
    def json_grouped = [:]
    def json_linelist = [:]

    def id = metadata_headers[0]
    def PARTITION_INDEX = 1
    def partition = metadata_headers[PARTITION_INDEX]

    // GENERAL
    OUTLIER_THRESH = "outlier_thresh"
    json_data[OUTLIER_THRESH] = lookup_config_json[OUTLIER_THRESH]

    CLUSTERING_METHOD = "clustering_method"
    json_data[CLUSTERING_METHOD] = lookup_config_json[CLUSTERING_METHOD]

    CLUSTERING_THRESHOLD = "clustering_threshold"
    json_data[CLUSTERING_THRESHOLD] = lookup_config_json[CLUSTERING_THRESHOLD]

    MIN_CLUSTER_MEMBERS = "min_cluster_members"
    json_data[MIN_CLUSTER_MEMBERS] = lookup_config_json[MIN_CLUSTER_MEMBERS]

    PARTITION_COLUMN_NAME = "partition_column_name"
    json_data[PARTITION_COLUMN_NAME] = partition

    ID_COLUMN_NAME = "id_column_name"
    json_data[ID_COLUMN_NAME] = id

    ONLY_REPORT_LABLED_COLUMNS = "only_report_labeled_columns"
    json_data[ONLY_REPORT_LABLED_COLUMNS] = lookup_config_json[ONLY_REPORT_LABLED_COLUMNS]

    SKIP_QA = "skip_qa"
    json_data[SKIP_QA] = lookup_config_json[SKIP_QA]

    // GROUPED METADATA
    for (String header in metadata_headers[PARTITION_INDEX..-1])
    {
        if (lookup_config_grouped.containsKey(header)) {
            json_grouped[header] = lookup_config_grouped[header]
        }
        else
        {
            json_grouped[header] = ["data_type":"None", "label":"$header", "default":"","display":"True"]
        }
    }

    // Add grouped metadata JSON data:
    json_data[GROUPED_METADATA] = json_grouped

    // LINELIST
    // Adding ID first:
    for (String header in ([id] + metadata_headers[PARTITION_INDEX..-1]))
    {
        if (lookup_config_linelist.containsKey(header)) {
            json_linelist[header] = lookup_config_linelist[header]
        }
        else
        {
            json_linelist[header] = ["data_type":"None", "label":"$header", "default":"","display":"True"]
        }
    }

    // Add linelist JSON data:
    json_data[LINELIST] = json_linelist

    task.workDir.resolve("config.json").withWriter { writer ->
        writer.write(JsonOutput.prettyPrint(JsonOutput.toJson(json_data)))
    }
}
