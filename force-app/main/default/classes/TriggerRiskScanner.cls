public with sharing class TriggerRiskScanner {
    public List<AiMetadataCopilotModels.OptimizationFindingRow> scan(
        List<MetadataExtractionService.ExtractedMetadataItem> items
    ) {
        List<AiMetadataCopilotModels.OptimizationFindingRow> findings =
            new List<AiMetadataCopilotModels.OptimizationFindingRow>();

        for (MetadataExtractionService.ExtractedMetadataItem item : items) {
            if (item == null || item.metadataType != 'ApexClass') {
                continue;
            }

            String searchableText = String.isBlank(item.searchText) ? '' : item.searchText.toLowerCase();
            if (
                !searchableText.contains('trigger.new') &&
                !searchableText.contains('trigger.old') &&
                !item.apiName.toLowerCase().contains('trigger')
            ) {
                continue;
            }

            AiMetadataCopilotModels.OptimizationFindingRow finding =
                new AiMetadataCopilotModels.OptimizationFindingRow();
            finding.findingType = 'TriggerRiskCandidate';
            finding.severity = 'High';
            finding.metadataKey = item.metadataKey;
            finding.summary = item.apiName + ' appears to contain trigger-context logic.';
            finding.recommendation = 'Review bulkification, recursion protection, and object dependency coverage before change.';
            findings.add(finding);
        }

        return findings;
    }
}
