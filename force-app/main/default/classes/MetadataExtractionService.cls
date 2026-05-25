public with sharing class MetadataExtractionService {
    /*
     * This service fetches metadata from the Tooling API and converts it
     * into a simple structure that other classes can index and analyze.
     */

    public class ExtractedMetadataItem {
        @AuraEnabled public String metadataType;
        @AuraEnabled public String metadataKey;
        @AuraEnabled public String apiName;
        @AuraEnabled public String developerName;
        @AuraEnabled public String objectApiName;
        @AuraEnabled public String fieldApiName;
        @AuraEnabled public String sourceRecordId;
        @AuraEnabled public String namespacePrefix;
        @AuraEnabled public String status;
        @AuraEnabled public String definitionSnippet;
        @AuraEnabled public String searchText;
    }

    private MetadataToolingApiClient toolingClient;

    public MetadataExtractionService() {
        this(new MetadataToolingApiClient());
    }

    public MetadataExtractionService(MetadataToolingApiClient toolingClient) {
        this.toolingClient = toolingClient;
    }

    public List<ExtractedMetadataItem> extractAllSupportedMetadata() {
        List<ExtractedMetadataItem> allItems = new List<ExtractedMetadataItem>();
        allItems.addAll(extractApexClasses());
        allItems.addAll(extractFlows());
        allItems.addAll(extractCustomFields());
        return allItems;
    }

    public List<ExtractedMetadataItem> extractApexClasses() {
        String queryText =
            'SELECT Id, Name, NamespacePrefix, Status, Body ' +
            'FROM ApexClass ' +
            'ORDER BY Name';

        MetadataToolingApiClient.ToolingQueryResult result = toolingClient.runQuery(queryText);
        return mapApexClassRecords(result.records);
    }

    public List<ExtractedMetadataItem> extractFlows() {
        String queryText = 'SELECT Id, MasterLabel, Status FROM Flow';
        MetadataToolingApiClient.ToolingQueryResult result = toolingClient.runQuery(queryText);

        List<ExtractedMetadataItem> items = new List<ExtractedMetadataItem>();

        for (Object rawRecord : safeRecords(result.records)) {
            Map<String, Object> summaryRecord = (Map<String, Object>) rawRecord;
            items.add(mapFlowSummaryRecord(summaryRecord));
        }

        return items;
    }

    public List<ExtractedMetadataItem> extractCustomFields() {
        String queryText =
            'SELECT Id, DeveloperName, NamespacePrefix, TableEnumOrId ' +
            'FROM CustomField ' +
            'ORDER BY DeveloperName';

        MetadataToolingApiClient.ToolingQueryResult result = toolingClient.runQuery(queryText);

        List<ExtractedMetadataItem> items = new List<ExtractedMetadataItem>();
        Map<String, String> objectNameByEntityId = buildObjectNameByEntityId(result.records);

        for (Object rawRecord : safeRecords(result.records)) {
            Map<String, Object> summaryRecord = (Map<String, Object>) rawRecord;
            ExtractedMetadataItem item = mapCustomFieldSummaryRecord(summaryRecord, objectNameByEntityId);
            if (item != null) {
                items.add(item);
            }
        }

        return items;
    }

    private List<ExtractedMetadataItem> mapApexClassRecords(List<Object> records) {
        List<ExtractedMetadataItem> items = new List<ExtractedMetadataItem>();

        for (Object rawRecord : safeRecords(records)) {
            Map<String, Object> record = (Map<String, Object>) rawRecord;

            ExtractedMetadataItem item = new ExtractedMetadataItem();
            item.metadataType = 'ApexClass';
            item.sourceRecordId = stringValue(record.get('Id'));
            item.apiName = stringValue(record.get('Name'));
            item.developerName = item.apiName;
            item.namespacePrefix = stringValue(record.get('NamespacePrefix'));
            item.status = defaultIfBlank(stringValue(record.get('Status')), 'Active');
            item.definitionSnippet = trimText(stringValue(record.get('Body')), 3000);
            item.searchText = buildSearchText(new List<String>{
                item.apiName,
                item.developerName,
                item.definitionSnippet
            });
            item.metadataKey = 'ApexClass:' + item.apiName;

            items.add(item);
        }

        return items;
    }

    private ExtractedMetadataItem mapFlowSummaryRecord(Map<String, Object> summaryRecord) {
        ExtractedMetadataItem item = new ExtractedMetadataItem();
        item.metadataType = 'Flow';
        item.sourceRecordId = stringValue(summaryRecord.get('Id'));
        item.apiName = stringValue(summaryRecord.get('MasterLabel'));
        item.developerName = item.apiName;
        item.status = defaultIfBlank(stringValue(summaryRecord.get('Status')), 'Active');
        item.searchText = buildSearchText(new List<String>{
            item.apiName,
            item.developerName,
            stringValue(summaryRecord.get('MasterLabel'))
        });
        item.metadataKey = 'Flow:' + item.apiName;
        return item;
    }

    private ExtractedMetadataItem mapCustomFieldSummaryRecord(
        Map<String, Object> summaryRecord,
        Map<String, String> objectNameByEntityId
    ) {
        String rawObjectReference = stringValue(summaryRecord.get('TableEnumOrId'));
        String objectApiName = objectNameByEntityId.containsKey(rawObjectReference)
            ? objectNameByEntityId.get(rawObjectReference)
            : rawObjectReference;
        if (looksLikeEntityId(objectApiName)) {
            objectApiName = null;
        }
        String fieldApiName = normalizeCustomFieldName(stringValue(summaryRecord.get('DeveloperName')));
        if (String.isBlank(objectApiName) || String.isBlank(fieldApiName)) {
            return null;
        }
        String fullName = buildQualifiedFieldName(objectApiName, fieldApiName);

        ExtractedMetadataItem item = new ExtractedMetadataItem();
        item.metadataType = 'CustomField';
        item.sourceRecordId = stringValue(summaryRecord.get('Id'));
        item.apiName = fullName;
        item.developerName = stringValue(summaryRecord.get('DeveloperName'));
        item.namespacePrefix = stringValue(summaryRecord.get('NamespacePrefix'));
        item.objectApiName = objectApiName;
        item.fieldApiName = fieldApiName;
        item.status = 'Active';
        item.searchText = buildSearchText(new List<String>{
            item.apiName,
            item.developerName,
            item.objectApiName,
            item.fieldApiName
        });
        item.metadataKey = 'CustomField:' + item.apiName;

        return item;
    }

    private Map<String, String> buildObjectNameByEntityId(List<Object> customFieldRecords) {
        Set<String> entityIds = new Set<String>();
        for (Object rawRecord : safeRecords(customFieldRecords)) {
            Map<String, Object> record = (Map<String, Object>) rawRecord;
            String tableReference = stringValue(record.get('TableEnumOrId'));
            if (looksLikeEntityId(tableReference)) {
                entityIds.add(tableReference);
            }
        }

        if (entityIds.isEmpty()) {
            return new Map<String, String>();
        }

        List<String> quotedIds = new List<String>();
        for (String entityId : entityIds) {
            quotedIds.add('\'' + String.escapeSingleQuotes(entityId) + '\'');
        }

        Map<String, String> objectNameByEntityId = new Map<String, String>();
        try {
            MetadataToolingApiClient.ToolingQueryResult result = toolingClient.runQuery(
                'SELECT Id, DeveloperName, NamespacePrefix FROM CustomObject WHERE Id IN ('
                + String.join(quotedIds, ',')
                + ')'
            );

            for (Object rawRecord : safeRecords(result.records)) {
                Map<String, Object> record = (Map<String, Object>) rawRecord;
                String developerName = stringValue(record.get('DeveloperName'));
                String namespacePrefix = stringValue(record.get('NamespacePrefix'));
                String qualifiedName = String.isBlank(namespacePrefix)
                    ? developerName + '__c'
                    : namespacePrefix + '__' + developerName + '__c';
                objectNameByEntityId.put(
                    stringValue(record.get('Id')),
                    qualifiedName
                );
            }
        } catch (Exception ex) {
            MetadataLogger.warn(
                'MetadataExtractionService',
                'Custom field object-name resolution skipped: ' + ex.getMessage()
            );
        }

        return objectNameByEntityId;
    }

    private static Boolean looksLikeEntityId(String value) {
        return !String.isBlank(value) && value.startsWith('01I');
    }

    private static String buildQualifiedFieldName(String objectApiName, String fieldApiName) {
        if (String.isBlank(objectApiName)) {
            return fieldApiName;
        }

        if (String.isBlank(fieldApiName)) {
            return objectApiName;
        }

        return objectApiName + '.' + fieldApiName;
    }

    private static String normalizeCustomFieldName(String developerName) {
        if (String.isBlank(developerName)) {
            return developerName;
        }

        if (developerName.endsWith('__c') || developerName.endsWith('__r')) {
            return developerName;
        }

        return developerName + '__c';
    }

    private static List<Object> safeRecords(List<Object> records) {
        return records == null ? new List<Object>() : records;
    }

    private static String stringValue(Object value) {
        return value == null ? null : String.valueOf(value);
    }

    private static String trimText(String inputText, Integer maxLength) {
        if (String.isBlank(inputText)) {
            return null;
        }

        if (inputText.length() <= maxLength) {
            return inputText;
        }

        return inputText.substring(0, maxLength);
    }

    private static String buildSearchText(List<String> parts) {
        List<String> filteredParts = new List<String>();

        for (String part : parts) {
            if (!String.isBlank(part)) {
                filteredParts.add(part);
            }
        }

        return String.join(filteredParts, ' ');
    }

    private static String defaultIfBlank(String inputText, String defaultValue) {
        return String.isBlank(inputText) ? defaultValue : inputText;
    }

    private static String firstNonBlank(String firstValue, String secondValue) {
        if (!String.isBlank(firstValue)) {
            return firstValue;
        }

        return secondValue;
    }
}
