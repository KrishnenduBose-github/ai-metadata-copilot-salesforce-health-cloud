public with sharing class MetadataIndexerService {
    /*
     * This service takes extracted metadata items and stores them in
     * Metadata_Item__c records.
     */

    public class IndexingResult {
        @AuraEnabled public Integer totalItems;
        @AuraEnabled public Integer successCount;
        @AuraEnabled public Integer errorCount;
        @AuraEnabled public List<String> errors;

        public IndexingResult() {
            this.totalItems = 0;
            this.successCount = 0;
            this.errorCount = 0;
            this.errors = new List<String>();
        }
    }

    private MetadataExtractionService extractionService;

    public MetadataIndexerService() {
        this(new MetadataExtractionService());
    }

    public MetadataIndexerService(MetadataExtractionService extractionService) {
        this.extractionService = extractionService;
    }

    public IndexingResult indexAllSupportedMetadata() {
        List<MetadataExtractionService.ExtractedMetadataItem> items =
            extractionService.extractAllSupportedMetadata();

        return indexMetadataItems(items);
    }

    public IndexingResult indexMetadataItems(
        List<MetadataExtractionService.ExtractedMetadataItem> items
    ) {
        IndexingResult result = new IndexingResult();
        List<Metadata_Item__c> recordsToUpsert = new List<Metadata_Item__c>();

        for (MetadataExtractionService.ExtractedMetadataItem item : safeItems(items)) {
            if (item == null || String.isBlank(item.metadataKey)) {
                result.errorCount++;
                result.errors.add('Skipped one metadata item because Metadata Key was blank.');
                continue;
            }

            Metadata_Item__c record = new Metadata_Item__c();
            record.Metadata_Key__c = item.metadataKey;
            record.Name = buildRecordName(item);
            record.Metadata_Type__c = item.metadataType;
            record.Api_Name__c = item.apiName;
            record.Developer_Name__c = item.developerName;
            record.Object_API_Name__c = item.objectApiName;
            record.Field_API_Name__c = item.fieldApiName;
            record.Source_Record_Id__c = item.sourceRecordId;
            record.Namespace_Prefix__c = item.namespacePrefix;
            record.Status__c = defaultStatus(item.status);
            record.Last_Indexed_On__c = System.now();

            recordsToUpsert.add(record);
        }

        result.totalItems = recordsToUpsert.size() + result.errorCount;

        if (recordsToUpsert.isEmpty()) {
            return result;
        }

        Database.UpsertResult[] upsertResults = Database.upsert(
            recordsToUpsert,
            Metadata_Item__c.Fields.Metadata_Key__c,
            false
        );

        for (Integer index = 0; index < upsertResults.size(); index++) {
            Database.UpsertResult upsertResult = upsertResults[index];

            if (upsertResult.isSuccess()) {
                result.successCount++;
                continue;
            }

            result.errorCount++;
            result.errors.add(
                'Failed to index '
                + recordsToUpsert[index].Metadata_Key__c
                + ': '
                + joinErrors(upsertResult.getErrors())
            );
        }

        return result;
    }

    private static List<MetadataExtractionService.ExtractedMetadataItem> safeItems(
        List<MetadataExtractionService.ExtractedMetadataItem> items
    ) {
        return items == null ? new List<MetadataExtractionService.ExtractedMetadataItem>() : items;
    }

    private static String buildRecordName(MetadataExtractionService.ExtractedMetadataItem item) {
        if (!String.isBlank(item.apiName)) {
            return item.apiName;
        }

        return item.metadataKey;
    }

    private static String defaultStatus(String status) {
        return String.isBlank(status) ? 'Active' : status;
    }

    private static String joinErrors(Database.Error[] errors) {
        List<String> messages = new List<String>();

        for (Database.Error errorItem : errors) {
            messages.add(errorItem.getMessage());
        }

        return String.join(messages, '; ');
    }
}
