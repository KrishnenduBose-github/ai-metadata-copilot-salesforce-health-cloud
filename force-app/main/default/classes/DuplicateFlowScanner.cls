public with sharing class DuplicateFlowScanner {
    public List<AiMetadataCopilotModels.OptimizationFindingRow> scan(
        List<MetadataExtractionService.ExtractedMetadataItem> items
    ) {
        Map<String, Integer> countsByApiName = new Map<String, Integer>();

        for (MetadataExtractionService.ExtractedMetadataItem item : items) {
            if (item == null || item.metadataType != 'Flow') {
                continue;
            }

            Integer currentCount = countsByApiName.containsKey(item.apiName)
                ? countsByApiName.get(item.apiName)
                : 0;
            countsByApiName.put(item.apiName, currentCount + 1);
        }

        List<AiMetadataCopilotModels.OptimizationFindingRow> findings =
            new List<AiMetadataCopilotModels.OptimizationFindingRow>();
        for (String apiName : countsByApiName.keySet()) {
            if (countsByApiName.get(apiName) < 2) {
                continue;
            }

            AiMetadataCopilotModels.OptimizationFindingRow finding =
                new AiMetadataCopilotModels.OptimizationFindingRow();
            finding.findingType = 'DuplicateFlowCandidate';
            finding.severity = 'Medium';
            finding.metadataKey = 'Flow:' + apiName;
            finding.summary = apiName + ' appeared multiple times during extraction.';
            finding.recommendation = 'Review flow versions and confirm whether overlapping automations can be consolidated.';
            findings.add(finding);
        }

        return findings;
    }
}
