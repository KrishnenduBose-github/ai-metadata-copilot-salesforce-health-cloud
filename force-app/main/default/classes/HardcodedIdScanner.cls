public with sharing class HardcodedIdScanner {
    public List<AiMetadataCopilotModels.OptimizationFindingRow> scan(
        List<MetadataExtractionService.ExtractedMetadataItem> items
    ) {
        List<AiMetadataCopilotModels.OptimizationFindingRow> findings =
            new List<AiMetadataCopilotModels.OptimizationFindingRow>();

        Pattern hardcodedIdPattern = Pattern.compile('[a-zA-Z0-9]{15,18}');
        for (MetadataExtractionService.ExtractedMetadataItem item : items) {
            if (item == null || item.metadataType != 'ApexClass' || String.isBlank(item.definitionSnippet)) {
                continue;
            }

            Matcher matcher = hardcodedIdPattern.matcher(item.definitionSnippet);
            if (!matcher.find()) {
                continue;
            }

            AiMetadataCopilotModels.OptimizationFindingRow finding =
                new AiMetadataCopilotModels.OptimizationFindingRow();
            finding.findingType = 'HardcodedIdCandidate';
            finding.severity = 'High';
            finding.metadataKey = item.metadataKey;
            finding.summary = item.apiName + ' may contain a hardcoded Salesforce Id.';
            finding.recommendation = 'Replace hardcoded identifiers with Custom Metadata, Custom Settings, or records looked up by developer name.';
            findings.add(finding);
        }

        return findings;
    }
}
