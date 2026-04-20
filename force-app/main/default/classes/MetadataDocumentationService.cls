public with sharing class MetadataDocumentationService {
    public AiMetadataCopilotModels.DocumentationResponse generate(
        AiMetadataCopilotModels.DocumentationRequest request
    ) {
        List<Metadata_Item__c> items = [
            SELECT Id, Name, Metadata_Key__c, Metadata_Type__c, Api_Name__c, Developer_Name__c,
                   Object_API_Name__c, Field_API_Name__c, Status__c
            FROM Metadata_Item__c
            WHERE Metadata_Key__c = :request.metadataKey
            LIMIT 1
        ];

        Metadata_Item__c item = items.isEmpty() ? null : items[0];
        String technicalSummary = item == null
            ? 'No indexed metadata item was found for ' + request.metadataKey + '.'
            : buildTechnicalSummary(item);
        String businessSummary = item == null
            ? 'No business summary could be generated because the metadata item was not found.'
            : buildBusinessSummary(item);

        Id requestId = persistRequest(request, technicalSummary, businessSummary);

        AiMetadataCopilotModels.DocumentationResponse response =
            new AiMetadataCopilotModels.DocumentationResponse();
        response.requestId = requestId;
        response.summary = 'Generated grounded documentation for ' + request.metadataKey + '.';
        response.technicalSummary = technicalSummary;
        response.businessSummary = businessSummary;
        response.explanation = 'Documentation is grounded in the indexed metadata item record.';
        return response;
    }

    private static String buildTechnicalSummary(Metadata_Item__c item) {
        return item.Metadata_Type__c + ' ' + item.Api_Name__c + ' is currently indexed with status ' + item.Status__c + '.';
    }

    private static String buildBusinessSummary(Metadata_Item__c item) {
        if (item.Metadata_Type__c == 'Flow') {
            return 'This flow participates in business automation for ' + item.Api_Name__c + '.';
        }

        if (item.Metadata_Type__c == 'CustomField') {
            return 'This field supports business data capture on ' + item.Object_API_Name__c + '.';
        }

        return 'This component supports internal Salesforce platform behavior and should be reviewed before change.';
    }

    private static Id persistRequest(
        AiMetadataCopilotModels.DocumentationRequest request,
        String technicalSummary,
        String businessSummary
    ) {
        if (!Schema.sObjectType.Documentation_Request__c.isCreateable()) {
            return null;
        }

        Documentation_Request__c record = new Documentation_Request__c();
        record.Request_Key__c = 'Documentation:' + String.valueOf(System.now().getTime());
        record.Request_Type__c = request.requestType;
        record.Metadata_Key__c = request.metadataKey;
        record.Technical_Summary__c = technicalSummary;
        record.Business_Summary__c = businessSummary;
        record.Status__c = 'Completed';
        insert record;
        return record.Id;
    }
}
