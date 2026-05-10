@IsTest
public class MetadataCopilotTestDataFactory {
    private static Integer counter = 0;

    public class Scenario {
        public String suffix;
        public String apexKey;
        public String flowKey;
        public String fieldKey;
        public String unusedFieldKey;
        public String objectApiName;
        public String fieldApiName;
        public String sourceSnapshotKey;
        public String targetSnapshotKey;
    }

    public static Scenario createFullScenario() {
        Scenario scenario = new Scenario();
        scenario.suffix = nextSuffix();
        scenario.objectApiName = 'Account';
        scenario.fieldApiName = 'CustomerPriority__c';
        scenario.apexKey = 'ApexClass:CustomerPriorityDemo' + scenario.suffix;
        scenario.flowKey = 'Flow:Account Care Flow ' + scenario.suffix;
        scenario.fieldKey = 'CustomField:Account.CustomerPriority__c';
        scenario.unusedFieldKey = 'CustomField:Account.Unused_Test_Field_' + scenario.suffix + '__c';
        scenario.sourceSnapshotKey = 'EnvironmentCompare:Source:' + scenario.suffix;
        scenario.targetSnapshotKey = 'EnvironmentCompare:Target:' + scenario.suffix;

        insertMetadataItems(scenario);
        insertUsageRecords(scenario);
        insertSnapshots(scenario);
        insertSecurityRecords(scenario);
        insertDeploymentRecords(scenario);
        insertDocumentationRecords(scenario);
        insertOptimizationRecords(scenario);
        return scenario;
    }

    public static List<MetadataExtractionService.ExtractedMetadataItem> createExtractedItems() {
        String suffix = nextSuffix();
        List<MetadataExtractionService.ExtractedMetadataItem> items =
            new List<MetadataExtractionService.ExtractedMetadataItem>();

        items.add(buildExtractedItem(
            'ApexClass',
            'ApexClass:CustomerPriorityDemo' + suffix,
            'CustomerPriorityDemo' + suffix,
            null,
            null,
            'public class CustomerPriorityDemo { String idValue = \'001000000000001AAA\'; }',
            'Account CustomerPriority__c trigger.new 001000000000001AAA'
        ));
        items.add(buildExtractedItem(
            'Flow',
            'Flow:Duplicate Account Care Flow',
            'Duplicate Account Care Flow',
            null,
            null,
            null,
            'Account CustomerPriority__c'
        ));
        items.add(buildExtractedItem(
            'Flow',
            'Flow:Duplicate Account Care Flow Second',
            'Duplicate Account Care Flow',
            null,
            null,
            null,
            'Account CustomerPriority__c'
        ));
        items.add(buildExtractedItem(
            'CustomField',
            'CustomField:Account.CustomerPriority__c',
            'Account.CustomerPriority__c',
            'Account',
            'CustomerPriority__c',
            null,
            'Account CustomerPriority__c'
        ));

        return items;
    }

    public static AiMetadataCopilotModels.MetadataSearchRequest searchRequest(String prompt) {
        AiMetadataCopilotModels.MetadataSearchRequest request =
            new AiMetadataCopilotModels.MetadataSearchRequest();
        request.userPrompt = prompt;
        return request;
    }

    public static AiMetadataCopilotModels.ImpactAnalysisRequest impactRequest(String prompt) {
        AiMetadataCopilotModels.ImpactAnalysisRequest request =
            new AiMetadataCopilotModels.ImpactAnalysisRequest();
        request.userPrompt = prompt;
        return request;
    }

    public static AiMetadataCopilotModels.SecurityAuditRequest securityRequest(String prompt) {
        AiMetadataCopilotModels.SecurityAuditRequest request =
            new AiMetadataCopilotModels.SecurityAuditRequest();
        request.userPrompt = prompt;
        return request;
    }

    public static AiMetadataCopilotModels.DeploymentCompareRequest deploymentRequest() {
        AiMetadataCopilotModels.DeploymentCompareRequest request =
            new AiMetadataCopilotModels.DeploymentCompareRequest();
        request.sourceEnvironment = 'Current Sandbox';
        request.targetEnvironment = 'Target Sandbox';
        request.metadataScope = 'All';
        return request;
    }

    public static AiMetadataCopilotModels.DocumentationRequest documentationRequest(String metadataKey) {
        AiMetadataCopilotModels.DocumentationRequest request =
            new AiMetadataCopilotModels.DocumentationRequest();
        request.metadataKey = metadataKey;
        request.requestType = 'ExplainComponent';
        return request;
    }

    public static AiMetadataCopilotModels.OptimizationScanRequest optimizationRequest() {
        AiMetadataCopilotModels.OptimizationScanRequest request =
            new AiMetadataCopilotModels.OptimizationScanRequest();
        request.scanType = 'Full';
        return request;
    }

    private static void insertMetadataItems(Scenario scenario) {
        List<Metadata_Item__c> items = new List<Metadata_Item__c>{
            new Metadata_Item__c(
                Name = 'CustomerPriorityDemo' + scenario.suffix,
                Metadata_Key__c = scenario.apexKey,
                Metadata_Type__c = 'ApexClass',
                Api_Name__c = 'CustomerPriorityDemo' + scenario.suffix,
                Developer_Name__c = 'CustomerPriorityDemo' + scenario.suffix,
                Status__c = 'Active',
                Search_Text__c = 'Account.CustomerPriority__c Account trigger.new',
                Definition__c = 'public class CustomerPriorityDemo { Account a; }',
                Last_Indexed_On__c = System.now()
            ),
            new Metadata_Item__c(
                Name = 'Account Care Flow ' + scenario.suffix,
                Metadata_Key__c = scenario.flowKey,
                Metadata_Type__c = 'Flow',
                Api_Name__c = 'Account Care Flow ' + scenario.suffix,
                Developer_Name__c = 'Account Care Flow ' + scenario.suffix,
                Status__c = 'Active',
                Search_Text__c = 'Account CustomerPriority__c',
                Last_Indexed_On__c = System.now()
            ),
            new Metadata_Item__c(
                Name = 'Account.CustomerPriority__c',
                Metadata_Key__c = scenario.fieldKey,
                Metadata_Type__c = 'CustomField',
                Api_Name__c = 'Account.CustomerPriority__c',
                Developer_Name__c = 'CustomerPriority',
                Object_API_Name__c = scenario.objectApiName,
                Field_API_Name__c = scenario.fieldApiName,
                Status__c = 'Active',
                Search_Text__c = 'Account CustomerPriority__c',
                Last_Indexed_On__c = System.now()
            ),
            new Metadata_Item__c(
                Name = 'Account.Unused_Test_Field_' + scenario.suffix + '__c',
                Metadata_Key__c = scenario.unusedFieldKey,
                Metadata_Type__c = 'CustomField',
                Api_Name__c = 'Account.Unused_Test_Field_' + scenario.suffix + '__c',
                Developer_Name__c = 'Unused_Test_Field_' + scenario.suffix,
                Object_API_Name__c = scenario.objectApiName,
                Field_API_Name__c = 'Unused_Test_Field_' + scenario.suffix + '__c',
                Status__c = 'Active',
                Search_Text__c = 'Account unused',
                Last_Indexed_On__c = System.now()
            )
        };
        insert items;
    }

    private static void insertUsageRecords(Scenario scenario) {
        Map<String, Metadata_Item__c> itemsByKey = new Map<String, Metadata_Item__c>();
        for (Metadata_Item__c item : [
            SELECT Id, Metadata_Key__c
            FROM Metadata_Item__c
            WHERE Metadata_Key__c IN :new Set<String>{ scenario.apexKey, scenario.flowKey, scenario.fieldKey }
        ]) {
            itemsByKey.put(item.Metadata_Key__c, item);
        }

        insert new List<Metadata_Usage__c>{
            new Metadata_Usage__c(
                Usage_Key__c = scenario.apexKey + '->UsesField:Account.CustomerPriority__c',
                Source_Metadata__c = itemsByKey.get(scenario.apexKey).Id,
                Target_Metadata__c = itemsByKey.get(scenario.fieldKey).Id,
                Source_Key__c = scenario.apexKey,
                Target_Key__c = scenario.fieldKey,
                Usage_Type__c = 'UsesField',
                Source_Type__c = 'ApexClass',
                Target_Type__c = 'CustomField',
                Match_Text__c = 'Account.CustomerPriority__c',
                Context_Snippet__c = 'Matched token: Account.CustomerPriority__c',
                Last_Analyzed_On__c = System.now()
            ),
            new Metadata_Usage__c(
                Usage_Key__c = scenario.flowKey + '->UsesObject:Account',
                Source_Metadata__c = itemsByKey.get(scenario.flowKey).Id,
                Target_Metadata__c = itemsByKey.get(scenario.fieldKey).Id,
                Source_Key__c = scenario.flowKey,
                Target_Key__c = 'Object:Account',
                Usage_Type__c = 'UsesObject',
                Source_Type__c = 'Flow',
                Target_Type__c = 'Object',
                Match_Text__c = 'Account',
                Context_Snippet__c = 'Matched token: Account',
                Last_Analyzed_On__c = System.now()
            )
        };
    }

    private static void insertSnapshots(Scenario scenario) {
        insert new List<Metadata_Snapshot__c>{
            new Metadata_Snapshot__c(
                Snapshot_Key__c = scenario.sourceSnapshotKey,
                Snapshot_Type__c = 'EnvironmentCompare',
                Source_Org_Label__c = 'Source',
                Target_Org_Label__c = 'Target',
                Status__c = 'Completed',
                Started_On__c = System.now().addMinutes(-10),
                Completed_On__c = System.now().addMinutes(-9),
                Item_Count__c = 2,
                Summary__c = 'Source test snapshot'
            ),
            new Metadata_Snapshot__c(
                Snapshot_Key__c = scenario.targetSnapshotKey,
                Snapshot_Type__c = 'EnvironmentCompare',
                Source_Org_Label__c = 'Source',
                Target_Org_Label__c = 'Target',
                Status__c = 'Completed',
                Started_On__c = System.now().addMinutes(-5),
                Completed_On__c = System.now().addMinutes(-4),
                Item_Count__c = 1,
                Summary__c = 'Target test snapshot'
            )
        };

        insert new List<Metadata_Component_Version__c>{
            new Metadata_Component_Version__c(
                Version_Key__c = scenario.sourceSnapshotKey + ':' + scenario.apexKey,
                Snapshot_Key__c = scenario.sourceSnapshotKey,
                Metadata_Key__c = scenario.apexKey,
                Metadata_Type__c = 'ApexClass',
                Api_Name__c = 'CustomerPriorityDemo' + scenario.suffix,
                Checksum__c = 'source-checksum'
            ),
            new Metadata_Component_Version__c(
                Version_Key__c = scenario.sourceSnapshotKey + ':' + scenario.fieldKey,
                Snapshot_Key__c = scenario.sourceSnapshotKey,
                Metadata_Key__c = scenario.fieldKey,
                Metadata_Type__c = 'CustomField',
                Api_Name__c = 'Account.CustomerPriority__c',
                Checksum__c = 'field-source-checksum'
            ),
            new Metadata_Component_Version__c(
                Version_Key__c = scenario.targetSnapshotKey + ':' + scenario.apexKey,
                Snapshot_Key__c = scenario.targetSnapshotKey,
                Metadata_Key__c = scenario.apexKey,
                Metadata_Type__c = 'ApexClass',
                Api_Name__c = 'CustomerPriorityDemo' + scenario.suffix,
                Checksum__c = 'target-checksum'
            )
        };
    }

    private static void insertSecurityRecords(Scenario scenario) {
        String runKey = 'SecurityAudit:' + scenario.suffix;
        insert new Security_Audit_Run__c(
            Run_Key__c = runKey,
            Scope_Type__c = 'Field',
            Scope_Value__c = 'Account.CustomerPriority__c',
            Severity__c = 'High',
            Started_On__c = System.now(),
            Completed_On__c = System.now(),
            Finding_Count__c = 1,
            Summary__c = 'Stored 1 security finding.'
        );
        insert new Security_Finding__c(
            Finding_Key__c = runKey + ':0',
            Run_Key__c = runKey,
            Finding_Type__c = 'PermissionSetReadAccess',
            Severity__c = 'High',
            Object_API_Name__c = 'Account',
            Field_API_Name__c = 'CustomerPriority__c',
            Permission_Artifact__c = 'Test Permission Set',
            Summary__c = 'Test Permission Set exposes Account.CustomerPriority__c.',
            Recommendation__c = 'Review least privilege access.'
        );
    }

    private static void insertDeploymentRecords(Scenario scenario) {
        String assessmentKey = 'Deployment:' + scenario.suffix;
        insert new Deployment_Assessment__c(
            Assessment_Key__c = assessmentKey,
            Source_Environment__c = 'Source',
            Target_Environment__c = 'Target',
            Readiness_Score__c = 85,
            Severity__c = 'Medium',
            Summary__c = 'Stored deployment test finding.',
            Rollback_Checklist__c = 'Restore previous metadata.',
            Test_Checklist__c = 'Run Account regression tests.'
        );
        insert new Deployment_Finding__c(
            Finding_Key__c = assessmentKey + ':0',
            Assessment_Key__c = assessmentKey,
            Finding_Type__c = 'ChangedMetadata',
            Severity__c = 'Medium',
            Metadata_Key__c = scenario.apexKey,
            Summary__c = 'Metadata checksum changed between snapshots.',
            Recommendation__c = 'Review dependencies.'
        );
    }

    private static void insertDocumentationRecords(Scenario scenario) {
        insert new Documentation_Request__c(
            Request_Key__c = 'Documentation:' + scenario.suffix,
            Request_Type__c = 'ExplainComponent',
            Metadata_Key__c = scenario.apexKey,
            Technical_Summary__c = 'Test technical summary.',
            Business_Summary__c = 'Test business summary.',
            Status__c = 'Completed'
        );
    }

    private static void insertOptimizationRecords(Scenario scenario) {
        insert new Optimization_Finding__c(
            Finding_Key__c = 'Optimization:' + scenario.suffix,
            Finding_Type__c = 'UnusedFieldCandidate',
            Severity__c = 'Medium',
            Metadata_Key__c = scenario.unusedFieldKey,
            Summary__c = 'Unused field candidate.',
            Recommendation__c = 'Validate before cleanup.',
            Status__c = 'Open'
        );
    }

    private static MetadataExtractionService.ExtractedMetadataItem buildExtractedItem(
        String metadataType,
        String metadataKey,
        String apiName,
        String objectApiName,
        String fieldApiName,
        String definitionSnippet,
        String searchText
    ) {
        MetadataExtractionService.ExtractedMetadataItem item =
            new MetadataExtractionService.ExtractedMetadataItem();
        item.metadataType = metadataType;
        item.metadataKey = metadataKey;
        item.apiName = apiName;
        item.developerName = apiName;
        item.objectApiName = objectApiName;
        item.fieldApiName = fieldApiName;
        item.sourceRecordId = '01p000000000000AAA';
        item.status = 'Active';
        item.definitionSnippet = definitionSnippet;
        item.searchText = searchText;
        return item;
    }

    private static String nextSuffix() {
        counter++;
        return String.valueOf(System.now().getTime()) + '_' + String.valueOf(counter);
    }
}
