public with sharing class MetadataRetentionService {
    public class RetentionResult {
        @AuraEnabled public Boolean cleanupApplied;
        @AuraEnabled public Integer deletedRecords;
        @AuraEnabled public List<String> messages;

        public RetentionResult() {
            this.cleanupApplied = false;
            this.deletedRecords = 0;
            this.messages = new List<String>();
        }
    }

    private static final Integer GENERATED_RECORD_SOFT_LIMIT = 1200;
    private static final Integer GENERATED_RECORD_HARD_LIMIT = 1800;

    public RetentionResult cleanupBeforeRefresh() {
        RetentionResult result = new RetentionResult();
        Integer malformedRecordsDeleted = deleteMalformedCustomFieldIndexes();
        if (malformedRecordsDeleted > 0) {
            result.cleanupApplied = true;
            result.deletedRecords += malformedRecordsDeleted;
            result.messages.add(
                'Storage recovery removed '
                + String.valueOf(malformedRecordsDeleted)
                + ' malformed custom-field index record(s) from older refresh runs.'
            );
        }

        Integer generatedCount = countGeneratedRecords();

        if (generatedCount < GENERATED_RECORD_SOFT_LIMIT) {
            return result;
        }

        result.cleanupApplied = true;
        result.deletedRecords += deleteGeneratedHistory();
        result.messages.add(
            'Storage recovery cleaned '
            + String.valueOf(result.deletedRecords)
            + ' older generated record(s) before refresh. Live metadata index was preserved.'
        );

        if (generatedCount >= GENERATED_RECORD_HARD_LIMIT) {
            Integer usageDeleted = deleteOlderUsageRows();
            result.deletedRecords += usageDeleted;
            if (usageDeleted > 0) {
                result.messages.add(
                    'Storage recovery also removed '
                    + String.valueOf(usageDeleted)
                    + ' stale usage relationship record(s).'
                );
            }
        }

        return result;
    }

    public static Boolean optionalWritesAllowed() {
        return countGeneratedRecords() < GENERATED_RECORD_SOFT_LIMIT;
    }

    public static Boolean storagePressureLikely() {
        return countGeneratedRecords() >= GENERATED_RECORD_SOFT_LIMIT;
    }

    public static Integer countGeneratedRecords() {
        Integer total = 0;
        total += safeCount('Metadata_Component_Version__c');
        total += safeCount('Metadata_Snapshot__c');
        total += safeCount('Optimization_Finding__c');
        total += safeCount('Documentation_Request__c');
        total += safeCount('Deployment_Finding__c');
        total += safeCount('Deployment_Assessment__c');
        total += safeCount('Security_Finding__c');
        total += safeCount('Security_Audit_Run__c');
        total += safeCount('Impact_Assessment__c');
        return total;
    }

    private static Integer deleteGeneratedHistory() {
        Integer deleted = 0;
        deleted += deleteRecords([SELECT Id FROM Metadata_Component_Version__c LIMIT 10000]);
        deleted += deleteRecords([SELECT Id FROM Metadata_Snapshot__c LIMIT 10000]);
        deleted += deleteRecords([SELECT Id FROM Optimization_Finding__c LIMIT 10000]);
        deleted += deleteRecords([SELECT Id FROM Documentation_Request__c LIMIT 10000]);
        deleted += deleteRecords([SELECT Id FROM Deployment_Finding__c LIMIT 10000]);
        deleted += deleteRecords([SELECT Id FROM Deployment_Assessment__c LIMIT 10000]);
        deleted += deleteRecords([SELECT Id FROM Security_Finding__c LIMIT 10000]);
        deleted += deleteRecords([SELECT Id FROM Security_Audit_Run__c LIMIT 10000]);
        deleted += deleteRecords([
            SELECT Id
            FROM Impact_Assessment__c
            WHERE LastModifiedDate < LAST_N_DAYS:1
            LIMIT 10000
        ]);
        return deleted;
    }

    private static Integer deleteOlderUsageRows() {
        return deleteRecords([
            SELECT Id
            FROM Metadata_Usage__c
            WHERE Last_Analyzed_On__c < LAST_N_DAYS:1
            LIMIT 10000
        ]);
    }

    private static Integer deleteMalformedCustomFieldIndexes() {
        List<Metadata_Item__c> malformedItems = new List<Metadata_Item__c>();
        for (Metadata_Item__c item : [
            SELECT Id, Metadata_Key__c
            FROM Metadata_Item__c
            WHERE Metadata_Key__c LIKE 'CustomField:%'
            LIMIT 10000
        ]) {
            String key = item.Metadata_Key__c;
            if (key != null && (key.startsWith('CustomField:01I') || !key.contains('.'))) {
                malformedItems.add(item);
            }
        }

        if (malformedItems.isEmpty()) {
            return 0;
        }

        Set<Id> malformedItemIds = new Map<Id, Metadata_Item__c>(malformedItems).keySet();
        Integer deleted = 0;

        deleted += deleteRecords([
            SELECT Id
            FROM Metadata_Usage__c
            WHERE Source_Metadata__c IN :malformedItemIds
               OR Target_Metadata__c IN :malformedItemIds
            LIMIT 10000
        ]);
        deleted += deleteRecords(malformedItems);
        return deleted;
    }

    private static Integer deleteRecords(List<SObject> records) {
        if (records == null || records.isEmpty()) {
            return 0;
        }

        Integer deleted = 0;
        Database.DeleteResult[] results = Database.delete(records, false);
        for (Database.DeleteResult deleteResult : results) {
            if (deleteResult.isSuccess()) {
                deleted++;
            }
        }
        return deleted;
    }

    private static Integer safeCount(String objectApiName) {
        try {
            return Database.countQuery('SELECT COUNT() FROM ' + objectApiName);
        } catch (Exception ex) {
            MetadataLogger.warn(
                'MetadataRetentionService',
                'Count skipped for ' + objectApiName + ': ' + ex.getMessage()
            );
            return 0;
        }
    }
}
