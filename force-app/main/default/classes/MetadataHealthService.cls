public with sharing class MetadataHealthService {
    public class HealthStatus {
        @AuraEnabled public Boolean isHealthy;
        @AuraEnabled public Integer indexedItemCount;
        @AuraEnabled public Integer usageRecordCount;
        @AuraEnabled public Integer snapshotCount;
        @AuraEnabled public String lastRefreshLabel;
        @AuraEnabled public Datetime lastRefreshOn;
        @AuraEnabled public List<String> warnings;
        @AuraEnabled public List<String> recommendations;

        public HealthStatus() {
            this.warnings = new List<String>();
            this.recommendations = new List<String>();
        }
    }

    public static HealthStatus check() {
        HealthStatus status = new HealthStatus();
        status.isHealthy = true;

        status.indexedItemCount = Database.countQuery('SELECT COUNT() FROM Metadata_Item__c');
        status.usageRecordCount = Database.countQuery('SELECT COUNT() FROM Metadata_Usage__c');

        if (status.indexedItemCount == 0) {
            status.isHealthy = false;
            status.warnings.add('No indexed metadata items found. Run Refresh Metadata to populate the index.');
            status.recommendations.add('Navigate to the Admin tab and click Refresh Metadata Core.');
        }

        if (status.usageRecordCount == 0) {
            status.isHealthy = false;
            status.warnings.add('No usage relationship records found. Run Refresh Metadata to analyze dependencies.');
            status.recommendations.add('Usage analysis runs automatically during the refresh cycle.');
        }

        List<Metadata_Snapshot__c> snapshots = [
            SELECT Id, Snapshot_Key__c, Snapshot_Type__c, Source_Org_Label__c, Completed_On__c
            FROM Metadata_Snapshot__c
            ORDER BY Completed_On__c DESC
            LIMIT 1
        ];

        status.snapshotCount = Database.countQuery('SELECT COUNT() FROM Metadata_Snapshot__c');

        if (!snapshots.isEmpty()) {
            status.lastRefreshLabel = snapshots[0].Snapshot_Type__c + ': ' + snapshots[0].Source_Org_Label__c;
            status.lastRefreshOn = snapshots[0].Completed_On__c;
        } else {
            status.warnings.add('No snapshots exist. Run Refresh Metadata to create the first snapshot.');
        }

        if (Schema.sObjectType.Metadata_Usage__c.isAccessible()) {
            status.recommendations.add('Use FieldUsage queries for custom field analysis. Use ObjectUsage for object-level impact.');
        }

        return status;
    }
}
