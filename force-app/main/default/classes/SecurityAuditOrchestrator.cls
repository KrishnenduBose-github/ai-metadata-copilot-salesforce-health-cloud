public with sharing class SecurityAuditOrchestrator {
    private SensitiveDataClassificationService classificationService;
    private FieldAccessAuditService fieldAccessAuditService;
    private PermissionSetExposureService permissionSetExposureService;
    private ProfileExposureService profileExposureService;
    private SharingRiskService sharingRiskService;
    private AiResponseFormatter responseFormatter;

    public SecurityAuditOrchestrator() {
        this.classificationService = new SensitiveDataClassificationService();
        this.fieldAccessAuditService = new FieldAccessAuditService();
        this.permissionSetExposureService = new PermissionSetExposureService();
        this.profileExposureService = new ProfileExposureService();
        this.sharingRiskService = new SharingRiskService();
        this.responseFormatter = new AiResponseFormatter();
    }

    public AiMetadataCopilotModels.SecurityAuditResponse runAudit(
        AiMetadataCopilotModels.SecurityAuditRequest request
    ) {
        List<SensitiveDataClassificationService.SensitiveTarget> targets =
            classificationService.getSensitiveTargets(request.objectApiName, request.fieldApiName);
        List<AiMetadataCopilotModels.SecurityFindingRow> findings =
            new List<AiMetadataCopilotModels.SecurityFindingRow>();

        for (SensitiveDataClassificationService.SensitiveTarget target : targets) {
            if (String.isBlank(target.fieldApiName)) {
                continue;
            }

            List<FieldPermissions> permissions = fieldAccessAuditService.findFieldPermissions(
                target.objectApiName,
                target.fieldApiName
            );
            findings.addAll(
                permissionSetExposureService.buildPermissionSetFindings(
                    permissions,
                    null,
                    target.sensitivityLevel
                )
            );
            findings.addAll(profileExposureService.buildProfileFindings(permissions, target.sensitivityLevel));
            findings.addAll(
                sharingRiskService.buildSharingFindings(
                    target.objectApiName,
                    target.fieldApiName,
                    target.sensitivityLevel,
                    permissions.size()
                )
            );
        }

        String runKey = 'SecurityAudit:' + String.valueOf(System.now().getTime());
        persistAudit(runKey, request, findings);

        AiMetadataCopilotModels.SecurityAuditResponse response =
            new AiMetadataCopilotModels.SecurityAuditResponse();
        response.runKey = runKey;
        response.findings = findings;
        response.score = responseFormatter.toScore(findings.size(), 12, 100);
        response.severity = responseFormatter.severityFromScore(response.score);
        response.summary =
            'Security audit found ' + String.valueOf(findings.size()) + ' grounded finding(s) for the requested scope.';
        response.explanation = findings.isEmpty()
            ? 'No sensitive exposure was detected from the configured Health Cloud baseline and field-permission checks.'
            : 'Findings are grounded in FieldPermissions, permission set ownership, and profile-derived access.';
        response.recommendations = new List<String>{
            'Review least-privilege access for sensitive Health Cloud fields.',
            'Prefer permission sets over broad profile exposure where possible.',
            'Validate that PHI-related fields are only visible to approved personas.'
        };
        return response;
    }

    private void persistAudit(
        String runKey,
        AiMetadataCopilotModels.SecurityAuditRequest request,
        List<AiMetadataCopilotModels.SecurityFindingRow> findings
    ) {
        if (Schema.sObjectType.Security_Audit_Run__c.isCreateable()) {
            Security_Audit_Run__c runRecord = new Security_Audit_Run__c();
            runRecord.Run_Key__c = runKey;
            runRecord.Scope_Type__c = String.isBlank(request.fieldApiName) ? 'Object' : 'Field';
            runRecord.Scope_Value__c = String.isBlank(request.fieldApiName)
                ? request.objectApiName
                : request.objectApiName + '.' + request.fieldApiName;
            runRecord.Severity__c = findings.isEmpty() ? 'Low' : 'High';
            runRecord.Summary__c = 'Stored ' + String.valueOf(findings.size()) + ' security finding(s).';
            runRecord.Started_On__c = System.now();
            runRecord.Completed_On__c = System.now();
            runRecord.Finding_Count__c = findings.size();
            Database.upsert(runRecord, Security_Audit_Run__c.Fields.Run_Key__c, false);
        }

        if (!findings.isEmpty() && Schema.sObjectType.Security_Finding__c.isCreateable()) {
            List<Security_Finding__c> findingRecords = new List<Security_Finding__c>();
            Integer findingIndex = 0;

            for (AiMetadataCopilotModels.SecurityFindingRow finding : findings) {
                Security_Finding__c record = new Security_Finding__c();
                record.Finding_Key__c = runKey + ':' + String.valueOf(findingIndex);
                record.Run_Key__c = runKey;
                record.Finding_Type__c = finding.findingType;
                record.Severity__c = finding.severity;
                record.Object_API_Name__c = finding.objectApiName;
                record.Field_API_Name__c = finding.fieldApiName;
                record.Permission_Artifact__c = finding.permissionArtifact;
                record.Summary__c = finding.summary;
                record.Recommendation__c = finding.recommendation;
                findingRecords.add(record);
                findingIndex++;
            }

            Database.upsert(findingRecords, Security_Finding__c.Fields.Finding_Key__c, false);
        }
    }
}
