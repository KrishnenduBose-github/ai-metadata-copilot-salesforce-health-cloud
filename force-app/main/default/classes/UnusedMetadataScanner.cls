public with sharing class UnusedMetadataScanner {
    public List<AiMetadataCopilotModels.OptimizationFindingRow> scan() {
        Set<String> usedTargets = new Set<String>();
        for (Metadata_Usage__c usageRecord : [
            SELECT Target_Key__c
            FROM Metadata_Usage__c
            WHERE Target_Key__c != null
        ]) {
            usedTargets.add(usageRecord.Target_Key__c);
        }

        List<AiMetadataCopilotModels.OptimizationFindingRow> findings =
            new List<AiMetadataCopilotModels.OptimizationFindingRow>();

        for (Metadata_Item__c item : [
            SELECT Metadata_Key__c, Api_Name__c, Metadata_Type__c
            FROM Metadata_Item__c
            WHERE Metadata_Type__c = 'CustomField'
        ]) {
            if (usedTargets.contains(item.Metadata_Key__c)) {
                continue;
            }

            AiMetadataCopilotModels.OptimizationFindingRow finding =
                new AiMetadataCopilotModels.OptimizationFindingRow();
            finding.findingType = 'UnusedFieldCandidate';
            finding.severity = 'Medium';
            finding.metadataKey = item.Metadata_Key__c;
            finding.summary = item.Api_Name__c + ' has no detected incoming usage in the current index.';
            finding.recommendation = 'Validate with admins before cleanup because text-based analysis may miss dynamic usage.';
            findings.add(finding);
        }

        return findings;
    }
}
