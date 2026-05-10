public with sharing class MetadataSnapshotService {
    public class SnapshotResult {
        @AuraEnabled public String snapshotKey;
        @AuraEnabled public Integer componentCount;
        @AuraEnabled public List<String> messages;

        public SnapshotResult() {
            this.messages = new List<String>();
        }
    }

    public SnapshotResult saveSnapshot(
        String snapshotType,
        String sourceOrgLabel,
        String targetOrgLabel,
        List<MetadataExtractionService.ExtractedMetadataItem> items
    ) {
        SnapshotResult result = new SnapshotResult();
        result.snapshotKey = buildSnapshotKey(snapshotType, sourceOrgLabel, targetOrgLabel);
        result.componentCount = items == null ? 0 : items.size();

        if (!Schema.sObjectType.Metadata_Snapshot__c.isCreateable()) {
            result.messages.add('Snapshot persistence is not available because Metadata Snapshot create access is missing.');
            return result;
        }

        try {
            Metadata_Snapshot__c snapshotRecord = new Metadata_Snapshot__c();
            snapshotRecord.Snapshot_Key__c = result.snapshotKey;
            snapshotRecord.Snapshot_Type__c = snapshotType;
            snapshotRecord.Source_Org_Label__c = sourceOrgLabel;
            snapshotRecord.Target_Org_Label__c = targetOrgLabel;
            snapshotRecord.Status__c = 'Completed';
            snapshotRecord.Started_On__c = System.now();
            snapshotRecord.Completed_On__c = System.now();
            snapshotRecord.Item_Count__c = result.componentCount;
            snapshotRecord.Summary__c = buildSnapshotSummary(snapshotType, result.componentCount);
            Database.upsert(snapshotRecord, Metadata_Snapshot__c.Fields.Snapshot_Key__c, false);

            saveComponentVersions(result.snapshotKey, items);
        } catch (DmlException dmlError) {
            if (!MetadataStorageUtility.isStorageLimitException(dmlError)) {
                throw dmlError;
            }

            result.messages.add(
                'Snapshot persistence was skipped because the org is low on storage. Metadata indexing still continued.'
            );
        }

        return result;
    }

    public Metadata_Snapshot__c getLatestSnapshot(String snapshotType) {
        List<Metadata_Snapshot__c> records = [
            SELECT Id, Snapshot_Key__c, Snapshot_Type__c, Source_Org_Label__c, Target_Org_Label__c,
                   Status__c, Started_On__c, Completed_On__c, Item_Count__c, Summary__c
            FROM Metadata_Snapshot__c
            WHERE Snapshot_Type__c = :snapshotType
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        return records.isEmpty() ? null : records[0];
    }

    public List<Metadata_Component_Version__c> getSnapshotVersions(String snapshotKey) {
        return [
            SELECT Id, Version_Key__c, Snapshot_Key__c, Metadata_Key__c, Metadata_Type__c,
                   Api_Name__c, Checksum__c, Source_Record_Id__c, Definition_Snippet__c
            FROM Metadata_Component_Version__c
            WHERE Snapshot_Key__c = :snapshotKey
        ];
    }

    private void saveComponentVersions(
        String snapshotKey,
        List<MetadataExtractionService.ExtractedMetadataItem> items
    ) {
        if (items == null || items.isEmpty() || !Schema.sObjectType.Metadata_Component_Version__c.isCreateable()) {
            return;
        }

        List<Metadata_Component_Version__c> recordsToUpsert = new List<Metadata_Component_Version__c>();
        for (MetadataExtractionService.ExtractedMetadataItem item : items) {
            if (item == null || String.isBlank(item.metadataKey)) {
                continue;
            }

            Metadata_Component_Version__c versionRecord = new Metadata_Component_Version__c();
            versionRecord.Version_Key__c = snapshotKey + ':' + item.metadataKey;
            versionRecord.Snapshot_Key__c = snapshotKey;
            versionRecord.Metadata_Key__c = item.metadataKey;
            versionRecord.Metadata_Type__c = item.metadataType;
            versionRecord.Api_Name__c = item.apiName;
            versionRecord.Checksum__c = buildChecksum(item);
            versionRecord.Source_Record_Id__c = item.sourceRecordId;
            versionRecord.Definition_Snippet__c = item.definitionSnippet;
            recordsToUpsert.add(versionRecord);
        }

        if (
            recordsToUpsert.isEmpty()
            || !Schema.sObjectType.Metadata_Component_Version__c.isCreateable()
        ) {
            return;
        }

        Database.upsert(recordsToUpsert, Metadata_Component_Version__c.Fields.Version_Key__c, false);
    }

    private static String buildChecksum(MetadataExtractionService.ExtractedMetadataItem item) {
        String rawValue = String.join(new List<String>{
            safeText(item.metadataType),
            safeText(item.apiName),
            safeText(item.status),
            safeText(item.searchText)
        }, '|');

        Blob digest = Crypto.generateDigest('SHA1', Blob.valueOf(rawValue));
        return EncodingUtil.convertToHex(digest);
    }

    private static String buildSnapshotKey(
        String snapshotType,
        String sourceOrgLabel,
        String targetOrgLabel
    ) {
        if (snapshotType == 'MetadataRefresh') {
            return String.join(new List<String>{
                safeText(snapshotType),
                safeText(sourceOrgLabel),
                safeText(targetOrgLabel)
            }, ':');
        }

        return String.join(new List<String>{
            safeText(snapshotType),
            safeText(sourceOrgLabel),
            safeText(targetOrgLabel),
            String.valueOf(System.now().getTime())
        }, ':');
    }

    private static String buildSnapshotSummary(String snapshotType, Integer itemCount) {
        return safeText(snapshotType) + ' snapshot stored ' + String.valueOf(itemCount) + ' metadata item(s).';
    }

    private static String safeText(String inputValue) {
        return String.isBlank(inputValue) ? 'CurrentOrg' : inputValue;
    }
}
