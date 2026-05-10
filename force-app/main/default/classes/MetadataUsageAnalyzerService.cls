public with sharing class MetadataUsageAnalyzerService {
    /*
     * This service creates simple usage relationships by checking whether
     * extracted metadata text contains field or object API names.
     */

    public class AnalysisResult {
        @AuraEnabled public Integer totalRelationships;
        @AuraEnabled public Integer successCount;
        @AuraEnabled public Integer errorCount;
        @AuraEnabled public List<String> errors;

        public AnalysisResult() {
            this.totalRelationships = 0;
            this.successCount = 0;
            this.errorCount = 0;
            this.errors = new List<String>();
        }
    }

    private MetadataExtractionService extractionService;

    public MetadataUsageAnalyzerService() {
        this(new MetadataExtractionService());
    }

    public MetadataUsageAnalyzerService(MetadataExtractionService extractionService) {
        this.extractionService = extractionService;
    }

    public AnalysisResult analyzeAndStoreUsage() {
        List<MetadataExtractionService.ExtractedMetadataItem> extractedItems =
            extractionService.extractAllSupportedMetadata();

        return analyzeAndStoreUsage(extractedItems);
    }

    public AnalysisResult analyzeAndStoreUsage(
        List<MetadataExtractionService.ExtractedMetadataItem> extractedItems
    ) {
        AnalysisResult result = new AnalysisResult();
        List<Metadata_Usage__c> usagesToUpsert = new List<Metadata_Usage__c>();

        Map<String, Metadata_Item__c> metadataByKey = loadMetadataItemsByKey();
        List<Metadata_Item__c> fieldTargets = loadMetadataItemsByType('CustomField');
        Map<String, Metadata_Item__c> objectTargets = buildObjectTargetMap(fieldTargets);

        for (MetadataExtractionService.ExtractedMetadataItem sourceItem : safeItems(extractedItems)) {
            if (sourceItem == null || String.isBlank(sourceItem.metadataKey)) {
                continue;
            }

            Metadata_Item__c sourceRecord = metadataByKey.get(sourceItem.metadataKey);
            if (sourceRecord == null) {
                result.errorCount++;
                result.errors.add(
                    'Source metadata item was not indexed yet: ' + sourceItem.metadataKey
                );
                continue;
            }

            String searchableText = normalizeText(sourceItem.searchText);
            if (String.isBlank(searchableText)) {
                continue;
            }

            usagesToUpsert.addAll(
                buildFieldUsageRecords(sourceItem, sourceRecord, searchableText, fieldTargets)
            );
            usagesToUpsert.addAll(
                buildObjectUsageRecords(sourceItem, sourceRecord, searchableText, objectTargets)
            );
        }

        result.totalRelationships = usagesToUpsert.size();

        if (usagesToUpsert.isEmpty()) {
            return result;
        }

        if (!Schema.sObjectType.Metadata_Usage__c.isCreateable() || !Schema.sObjectType.Metadata_Usage__c.isUpdateable()) {
            result.errorCount = usagesToUpsert.size();
            result.errors.add('Usage persistence skipped because Metadata Usage object is not writable.');
            return result;
        }

        Database.UpsertResult[] upsertResults = Database.upsert(
            usagesToUpsert,
            Metadata_Usage__c.Fields.Usage_Key__c,
            false
        );

        for (Integer index = 0; index < upsertResults.size(); index++) {
            if (upsertResults[index].isSuccess()) {
                result.successCount++;
            } else {
                result.errorCount++;
                result.errors.add(
                    'Failed to store usage '
                    + usagesToUpsert[index].Usage_Key__c
                    + ': '
                    + joinErrors(upsertResults[index].getErrors())
                );
            }
        }

        if (MetadataStorageUtility.containsStorageLimitError(result.errors)) {
            result.errors.clear();
            result.errors.add(
                'Usage persistence was skipped because the org is low on storage. Metadata indexing still continued.'
            );
            result.errorCount = 1;
        }

        return result;
    }

    private static Map<String, Metadata_Item__c> loadMetadataItemsByKey() {
        Map<String, Metadata_Item__c> results = new Map<String, Metadata_Item__c>();

        if (!Schema.sObjectType.Metadata_Item__c.isAccessible()) {
            return results;
        }

        for (Metadata_Item__c item : [
            SELECT Id, Name, Metadata_Key__c, Metadata_Type__c, Api_Name__c, Object_API_Name__c, Field_API_Name__c
            FROM Metadata_Item__c
            WHERE Metadata_Key__c != null
            LIMIT 5000
        ]) {
            results.put(item.Metadata_Key__c, item);
        }

        return results;
    }

    private static List<Metadata_Item__c> loadMetadataItemsByType(String metadataType) {
        if (!Schema.sObjectType.Metadata_Item__c.isAccessible()) {
            return new List<Metadata_Item__c>();
        }

        return [
            SELECT Id, Name, Metadata_Key__c, Metadata_Type__c, Api_Name__c, Object_API_Name__c, Field_API_Name__c
            FROM Metadata_Item__c
            WHERE Metadata_Type__c = :metadataType
            LIMIT 5000
        ];
    }

    private static Map<String, Metadata_Item__c> buildObjectTargetMap(
        List<Metadata_Item__c> fieldTargets
    ) {
        Map<String, Metadata_Item__c> objectMap = new Map<String, Metadata_Item__c>();

        for (Metadata_Item__c fieldItem : fieldTargets) {
            if (String.isBlank(fieldItem.Object_API_Name__c)) {
                continue;
            }

            if (!objectMap.containsKey(fieldItem.Object_API_Name__c)) {
                objectMap.put(fieldItem.Object_API_Name__c, fieldItem);
            }
        }

        return objectMap;
    }

    private static List<Metadata_Usage__c> buildFieldUsageRecords(
        MetadataExtractionService.ExtractedMetadataItem sourceItem,
        Metadata_Item__c sourceRecord,
        String searchableText,
        List<Metadata_Item__c> fieldTargets
    ) {
        List<Metadata_Usage__c> usageRecords = new List<Metadata_Usage__c>();

        for (Metadata_Item__c targetField : fieldTargets) {
            if (isSameMetadata(sourceRecord, targetField)) {
                continue;
            }

            if (String.isBlank(targetField.Field_API_Name__c)) {
                continue;
            }

            String fullFieldName = targetField.Api_Name__c;
            String fieldName = targetField.Field_API_Name__c;

            if (
                containsToken(searchableText, normalizeText(fullFieldName)) ||
                containsToken(searchableText, normalizeText(fieldName))
            ) {
                usageRecords.add(
                    createUsageRecord(
                        sourceItem,
                        sourceRecord,
                        targetField,
                        'UsesField',
                        firstNonBlank(fullFieldName, fieldName)
                    )
                );
            }
        }

        return usageRecords;
    }

    private static List<Metadata_Usage__c> buildObjectUsageRecords(
        MetadataExtractionService.ExtractedMetadataItem sourceItem,
        Metadata_Item__c sourceRecord,
        String searchableText,
        Map<String, Metadata_Item__c> objectTargets
    ) {
        List<Metadata_Usage__c> usageRecords = new List<Metadata_Usage__c>();

        for (String objectApiName : objectTargets.keySet()) {
            if (String.isBlank(objectApiName)) {
                continue;
            }

            if (!containsToken(searchableText, normalizeText(objectApiName))) {
                continue;
            }

            Metadata_Item__c targetObjectProxy = objectTargets.get(objectApiName);

            usageRecords.add(
                createUsageRecord(
                    sourceItem,
                    sourceRecord,
                    targetObjectProxy,
                    'UsesObject',
                    objectApiName
                )
            );
        }

        return usageRecords;
    }

    private static Metadata_Usage__c createUsageRecord(
        MetadataExtractionService.ExtractedMetadataItem sourceItem,
        Metadata_Item__c sourceRecord,
        Metadata_Item__c targetRecord,
        String usageType,
        String matchText
    ) {
        Metadata_Usage__c usageRecord = new Metadata_Usage__c();
        usageRecord.Usage_Key__c =
            sourceItem.metadataKey
            + '->'
            + usageType
            + ':'
            + safeString(matchText);
        usageRecord.Source_Metadata__c = sourceRecord.Id;
        usageRecord.Target_Metadata__c = targetRecord.Id;
        usageRecord.Source_Key__c = sourceItem.metadataKey;
        usageRecord.Target_Key__c = buildTargetKey(targetRecord, usageType, matchText);
        usageRecord.Usage_Type__c = usageType;
        usageRecord.Source_Type__c = sourceRecord.Metadata_Type__c;
        usageRecord.Target_Type__c = usageType == 'UsesObject' ? 'Object' : targetRecord.Metadata_Type__c;
        usageRecord.Match_Text__c = matchText;
        usageRecord.Context_Snippet__c = 'Matched token: ' + matchText;
        usageRecord.Last_Analyzed_On__c = System.now();
        return usageRecord;
    }

    private static String buildTargetKey(
        Metadata_Item__c targetRecord,
        String usageType,
        String matchText
    ) {
        if (usageType == 'UsesObject') {
            return 'Object:' + safeString(matchText);
        }

        return targetRecord.Metadata_Key__c;
    }

    private static Boolean isSameMetadata(Metadata_Item__c firstItem, Metadata_Item__c secondItem) {
        return firstItem != null && secondItem != null && firstItem.Id == secondItem.Id;
    }

    private static String normalizeText(String inputText) {
        return String.isBlank(inputText) ? null : inputText.toLowerCase();
    }

    private static Boolean containsToken(String sourceText, String tokenText) {
        return !String.isBlank(sourceText) && !String.isBlank(tokenText) && sourceText.contains(tokenText);
    }

    private static String safeString(String inputText) {
        return String.isBlank(inputText) ? 'Unknown' : inputText;
    }

    private static String firstNonBlank(String firstValue, String secondValue) {
        if (!String.isBlank(firstValue)) {
            return firstValue;
        }

        return secondValue;
    }

    private static List<MetadataExtractionService.ExtractedMetadataItem> safeItems(
        List<MetadataExtractionService.ExtractedMetadataItem> items
    ) {
        return items == null ? new List<MetadataExtractionService.ExtractedMetadataItem>() : items;
    }

    private static String joinErrors(Database.Error[] errors) {
        List<String> messages = new List<String>();

        for (Database.Error errorItem : errors) {
            messages.add(errorItem.getMessage());
        }

        return String.join(messages, '; ');
    }
}
