public with sharing class MetadataNormalizationService {
    public AiMetadataCopilotModels.MetadataSearchRequest normalizeSearchRequest(String userPrompt) {
        AiMetadataCopilotModels.MetadataSearchRequest request =
            new AiMetadataCopilotModels.MetadataSearchRequest();
        request.userPrompt = userPrompt;
        request.queryType = inferQueryType(userPrompt);
        request.queryText = extractMetadataToken(userPrompt);
        return request;
    }

    public AiMetadataCopilotModels.ImpactAnalysisRequest normalizeImpactRequest(String userPrompt) {
        AiMetadataCopilotModels.ImpactAnalysisRequest request =
            new AiMetadataCopilotModels.ImpactAnalysisRequest();
        request.userPrompt = userPrompt;
        request.queryType = inferQueryType(userPrompt);
        request.queryText = extractMetadataToken(userPrompt);
        request.metadataKey = request.queryType == 'ObjectUsage'
            ? 'Object:' + request.queryText
            : 'CustomField:' + request.queryText;
        return request;
    }

    public AiMetadataCopilotModels.SecurityAuditRequest normalizeSecurityRequest(String userPrompt) {
        AiMetadataCopilotModels.SecurityAuditRequest request =
            new AiMetadataCopilotModels.SecurityAuditRequest();
        request.userPrompt = userPrompt;
        String token = extractMetadataToken(userPrompt);

        if (!String.isBlank(token) && token.contains('.')) {
            request.objectApiName = token.substringBefore('.');
            request.fieldApiName = token.substringAfter('.');
        } else {
            request.objectApiName = token;
        }

        return request;
    }

    private static String inferQueryType(String userPrompt) {
        String normalizedPrompt = normalizeText(userPrompt);

        if (String.isBlank(normalizedPrompt)) {
            return 'FieldUsage';
        }

        if (
            normalizedPrompt.contains(' object ') ||
            normalizedPrompt.contains('flows update') ||
            normalizedPrompt.contains('related to') ||
            normalizedPrompt.contains('careplan')
        ) {
            return 'ObjectUsage';
        }

        return 'FieldUsage';
    }

    private static String extractMetadataToken(String userPrompt) {
        if (String.isBlank(userPrompt)) {
            return null;
        }

        String cleanedPrompt = userPrompt
            .replace('?', ' ')
            .replace(',', ' ')
            .replace('"', ' ')
            .replace('\'', ' ')
            .trim();

        List<String> tokens = cleanedPrompt.split('\\s+');
        for (Integer index = tokens.size() - 1; index >= 0; index--) {
            String token = tokens[index];
            if (token.contains('__c') || token.contains('.')) {
                return token.trim();
            }
        }

        return tokens.isEmpty() ? null : tokens[tokens.size() - 1];
    }

    private static String normalizeText(String inputText) {
        return String.isBlank(inputText) ? null : ' ' + inputText.toLowerCase() + ' ';
    }
}
