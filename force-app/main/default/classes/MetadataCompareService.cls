public with sharing class MetadataCompareService {
    public List<AiMetadataCopilotModels.DeploymentFindingRow> compareSnapshots(
        String sourceSnapshotKey,
        String targetSnapshotKey
    ) {
        MetadataSnapshotService snapshotService = new MetadataSnapshotService();
        List<Metadata_Component_Version__c> sourceVersions =
            snapshotService.getSnapshotVersions(sourceSnapshotKey);
        List<Metadata_Component_Version__c> targetVersions =
            snapshotService.getSnapshotVersions(targetSnapshotKey);

        Map<String, Metadata_Component_Version__c> sourceByKey =
            buildVersionMap(sourceVersions);
        Map<String, Metadata_Component_Version__c> targetByKey =
            buildVersionMap(targetVersions);

        Set<String> allKeys = new Set<String>();
        allKeys.addAll(sourceByKey.keySet());
        allKeys.addAll(targetByKey.keySet());

        List<AiMetadataCopilotModels.DeploymentFindingRow> findings =
            new List<AiMetadataCopilotModels.DeploymentFindingRow>();

        for (String metadataKey : allKeys) {
            Metadata_Component_Version__c sourceVersion = sourceByKey.get(metadataKey);
            Metadata_Component_Version__c targetVersion = targetByKey.get(metadataKey);

            if (sourceVersion == null) {
                findings.add(buildFinding('MissingInSource', 'Medium', metadataKey, 'Metadata exists only in target snapshot.'));
            } else if (targetVersion == null) {
                findings.add(buildFinding('MissingInTarget', 'High', metadataKey, 'Metadata exists only in source snapshot.'));
            } else if (sourceVersion.Checksum__c != targetVersion.Checksum__c) {
                findings.add(buildFinding('ChangedMetadata', 'Medium', metadataKey, 'Metadata checksum changed between snapshots.'));
            }
        }

        return findings;
    }

    private static Map<String, Metadata_Component_Version__c> buildVersionMap(
        List<Metadata_Component_Version__c> versions
    ) {
        Map<String, Metadata_Component_Version__c> results =
            new Map<String, Metadata_Component_Version__c>();
        for (Metadata_Component_Version__c versionRecord : versions) {
            results.put(versionRecord.Metadata_Key__c, versionRecord);
        }
        return results;
    }

    private static AiMetadataCopilotModels.DeploymentFindingRow buildFinding(
        String findingType,
        String severity,
        String metadataKey,
        String summary
    ) {
        AiMetadataCopilotModels.DeploymentFindingRow finding =
            new AiMetadataCopilotModels.DeploymentFindingRow();
        finding.findingType = findingType;
        finding.severity = severity;
        finding.metadataKey = metadataKey;
        finding.summary = summary;
        finding.recommendation = 'Review dependencies and confirm the target org has the required metadata.';
        return finding;
    }
}
