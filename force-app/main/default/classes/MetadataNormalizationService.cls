public with sharing class MetadataNormalizationService {
    public AiMetadataCopilotModels.MetadataSearchRequest normalizeSearchRequest(String userPrompt) {
        AiMetadataCopilotModels.MetadataSearchRequest request =
            new AiMetadataCopilotModels.MetadataSearchRequest();
        request.userPrompt = userPrompt;

        if (String.isBlank(userPrompt)) {
            request.queryType = 'FieldUsage';
            return request;
        }

        request.queryType = inferQueryType(userPrompt);
        request.queryText = extractMetadataToken(userPrompt, request.queryType);

        MetadataLogger.info('MetadataNormalization', 'Search normalized: type=' + request.queryType + ', text=' + request.queryText);
        return request;
    }

    public AiMetadataCopilotModels.ImpactAnalysisRequest normalizeImpactRequest(String userPrompt) {
        AiMetadataCopilotModels.ImpactAnalysisRequest request =
            new AiMetadataCopilotModels.ImpactAnalysisRequest();
        request.userPrompt = userPrompt;

        if (String.isBlank(userPrompt)) {
            request.queryType = 'FieldUsage';
            return request;
        }

        request.queryType = inferQueryType(userPrompt);
        request.queryText = extractMetadataToken(userPrompt, request.queryType);
        request.metadataKey = request.queryType == 'ObjectUsage'
            ? 'Object:' + request.queryText
            : 'CustomField:' + request.queryText;

        MetadataLogger.info('MetadataNormalization', 'Impact normalized: type=' + request.queryType + ', text=' + request.queryText);
        return request;
    }

    public AiMetadataCopilotModels.SecurityAuditRequest normalizeSecurityRequest(String userPrompt) {
        AiMetadataCopilotModels.SecurityAuditRequest request =
            new AiMetadataCopilotModels.SecurityAuditRequest();
        request.userPrompt = userPrompt;

        String token = extractMetadataToken(userPrompt, 'FieldUsage');

        if (String.isBlank(token)) {
            return request;
        }

        if (token.contains('.')) {
            request.objectApiName = token.substringBefore('.');
            request.fieldApiName = token.substringAfter('.');
            MetadataLogger.info('MetadataNormalization', 'Security normalized: object=' + request.objectApiName + ', field=' + request.fieldApiName);
            return request;
        }

        if (token.endsWith('__c') || token.endsWith('__r')) {
            String resolvedObject = resolveFieldObject(token);
            if (!String.isBlank(resolvedObject)) {
                request.objectApiName = resolvedObject;
                request.fieldApiName = token;
                MetadataLogger.info('MetadataNormalization', 'Security resolved field: object=' + resolvedObject + ', field=' + token);
                return request;
            }
            request.fieldApiName = token;
            MetadataLogger.info('MetadataNormalization', 'Security stored field only: ' + token);
            return request;
        }

        request.objectApiName = token;
        MetadataLogger.info('MetadataNormalization', 'Security normalized: object=' + token);
        return request;
    }

    private static String resolveFieldObject(String fieldApiName) {
        if (!Schema.sObjectType.Metadata_Item__c.isAccessible()) {
            return null;
        }

        List<Metadata_Item__c> items = [
            SELECT Object_API_Name__c
            FROM Metadata_Item__c
            WHERE Field_API_Name__c = :fieldApiName
              AND Metadata_Type__c = 'CustomField'
            LIMIT 1
        ];

        return items.isEmpty() ? null : items[0].Object_API_Name__c;
    }

    private static String inferQueryType(String userPrompt) {
        String normalizedPrompt = wrapInSpaces(userPrompt);

        if (String.isBlank(normalizedPrompt)) {
            return 'FieldUsage';
        }

        String lowerPrompt = normalizedPrompt.toLowerCase();
        if (
            lowerPrompt.contains(' object ') ||
            lowerPrompt.contains('flows update') ||
            lowerPrompt.contains('related to ') ||
            lowerPrompt.contains('careplan')
        ) {
            return 'ObjectUsage';
        }

        return 'FieldUsage';
    }

    private static String extractMetadataToken(String userPrompt, String queryType) {
        if (String.isBlank(userPrompt)) {
            return null;
        }

        String cleanedPrompt = userPrompt
            .replace('?', ' ')
            .replace(',', ' ')
            .replace('"', ' ')
            .replace('\'', ' ')
            .replace(':', ' ')
            .replace('(', ' ')
            .replace(')', ' ')
            .trim();

        List<String> tokens = cleanedPrompt.split('\\s+');

        String token = findExplicitMetadataToken(tokens);
        if (!String.isBlank(token)) {
            return token;
        }

        if (queryType == 'ObjectUsage') {
            token = findLikelyObjectToken(tokens);
            if (!String.isBlank(token)) {
                return token;
            }
        }

        token = findLikelyObjectToken(tokens);
        if (!String.isBlank(token)) {
            return token;
        }

        token = findFallbackToken(tokens);
        return token;
    }

    private static String wrapInSpaces(String inputText) {
        return String.isBlank(inputText) ? null : ' ' + inputText.toLowerCase() + ' ';
    }

    private static String findExplicitMetadataToken(List<String> tokens) {
        for (Integer index = tokens.size() - 1; index >= 0; index--) {
            String token = sanitizeToken(tokens[index]);
            if (token != null && (token.contains('__c') || isQualifiedApiName(token) || token.contains('__mdt'))) {
                return token;
            }
        }
        return null;
    }

    private static String findLikelyObjectToken(List<String> tokens) {
        Set<String> ignoredWords = new Set<String>{
            'where', 'what', 'which', 'show', 'all', 'used', 'uses', 'using',
            'depends', 'depend', 'related', 'update', 'updates', 'breaks',
            'rename', 'delete', 'risk', 'after', 'modifying', 'change',
            'changes', 'test', 'flow', 'flows', 'trigger', 'triggers',
            'class', 'classes', 'field', 'fields', 'object', 'objects',
            'for', 'to', 'if', 'can', 'i', 'we', 'the', 'a', 'an', 'on',
            'of', 'in', 'is', 'it', 'me', 'my', 'your', 'its', 'find',
            'are', 'does', 'how', 'who', 'has', 'have', 'any', 'with',
            'this', 'that', 'from', 'some', 'more', 'also', 'want', 'need'
        };

        for (Integer index = tokens.size() - 1; index >= 0; index--) {
            String token = sanitizeToken(tokens[index]);
            if (token == null || ignoredWords.contains(token.toLowerCase())) {
                continue;
            }
            if (token.length() > 0 && token.length() >= 3) {
                String firstChar = token.substring(0, 1);
                if (firstChar == firstChar.toUpperCase() || token.endsWith('__c')) {
                    return token;
                }
            }
        }

        for (Integer index = 0; index < tokens.size(); index++) {
            String token = sanitizeToken(tokens[index]);
            if (token == null || ignoredWords.contains(token.toLowerCase())) {
                continue;
            }
            if (token.length() > 0 && token.length() >= 3) {
                String firstChar = token.substring(0, 1);
                if (firstChar == firstChar.toUpperCase() || token.endsWith('__c')) {
                    return token;
                }
            }
        }

        return null;
    }

    private static String findFallbackToken(List<String> tokens) {
        for (Integer index = tokens.size() - 1; index >= 0; index--) {
            String token = sanitizeToken(tokens[index]);
            if (!String.isBlank(token) && token.length() >= 3) {
                return token;
            }
        }

        for (Integer index = 0; index < tokens.size(); index++) {
            String token = sanitizeToken(tokens[index]);
            if (!String.isBlank(token) && token.length() >= 3) {
                return token;
            }
        }

        return null;
    }

    private static String sanitizeToken(String token) {
        if (String.isBlank(token)) {
            return null;
        }

        String cleaned = token
            .replace('?', '')
            .replace(',', '')
            .replace('"', '')
            .replace('\'', '')
            .replace(':', '')
            .replace('(', '')
            .replace(')', '');

        cleaned = cleaned.trim();

        if (cleaned.length() == 0) {
            return null;
        }

        if (cleaned.endsWith('.')) {
            cleaned = cleaned.substring(0, cleaned.length() - 1);
        }

        return cleaned;
    }

    private static Boolean isQualifiedApiName(String token) {
        if (String.isBlank(token)) {
            return false;
        }
        Integer dotIndex = token.indexOf('.');
        if (dotIndex <= 0 || dotIndex >= token.length() - 1) {
            return false;
        }
        String before = token.substring(0, dotIndex);
        String after = token.substring(dotIndex + 1);
        return before.isAlphanumeric() && after.isAlphanumeric();
    }
}
