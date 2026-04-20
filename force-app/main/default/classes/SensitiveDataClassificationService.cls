public with sharing class SensitiveDataClassificationService {
    public class SensitiveTarget {
        public String objectApiName;
        public String fieldApiName;
        public String sensitivityLevel;
        public String complianceNote;
    }

    public List<SensitiveTarget> getSensitiveTargets(String objectApiName, String fieldApiName) {
        List<SensitiveTarget> targets = new List<SensitiveTarget>();

        for (Sensitive_Field_Rule__mdt ruleRecord : [
            SELECT DeveloperName, Object_API_Name__c, Field_API_Name__c, Sensitivity_Level__c, Compliance_Note__c
            FROM Sensitive_Field_Rule__mdt
        ]) {
            if (!matchesScope(ruleRecord.Object_API_Name__c, objectApiName)) {
                continue;
            }

            if (!String.isBlank(fieldApiName) && !matchesScope(ruleRecord.Field_API_Name__c, fieldApiName)) {
                continue;
            }

            SensitiveTarget target = new SensitiveTarget();
            target.objectApiName = ruleRecord.Object_API_Name__c;
            target.fieldApiName = ruleRecord.Field_API_Name__c;
            target.sensitivityLevel = ruleRecord.Sensitivity_Level__c;
            target.complianceNote = ruleRecord.Compliance_Note__c;
            targets.add(target);
        }

        if (!targets.isEmpty()) {
            return targets;
        }

        return buildFallbackTargets(objectApiName, fieldApiName);
    }

    private static List<SensitiveTarget> buildFallbackTargets(String objectApiName, String fieldApiName) {
        List<SensitiveTarget> fallbackTargets = new List<SensitiveTarget>();
        List<String> baselineObjects = new List<String>{
            'Account', 'Contact', 'Case', 'CarePlan__c', 'Member__c', 'Claim__c'
        };

        if (String.isBlank(objectApiName)) {
            for (String baselineObject : baselineObjects) {
                SensitiveTarget target = new SensitiveTarget();
                target.objectApiName = baselineObject;
                target.sensitivityLevel = 'High';
                target.complianceNote = 'Fallback Health Cloud baseline rule';
                fallbackTargets.add(target);
            }
            return fallbackTargets;
        }

        SensitiveTarget target = new SensitiveTarget();
        target.objectApiName = objectApiName;
        target.fieldApiName = fieldApiName;
        target.sensitivityLevel = inferSensitivityLevel(objectApiName, fieldApiName);
        target.complianceNote = 'Fallback Health Cloud baseline rule';
        fallbackTargets.add(target);
        return fallbackTargets;
    }

    private static String inferSensitivityLevel(String objectApiName, String fieldApiName) {
        String combinedValue = (objectApiName + '.' + fieldApiName).toLowerCase();

        if (
            combinedValue.contains('patient') ||
            combinedValue.contains('member') ||
            combinedValue.contains('diagnosis') ||
            combinedValue.contains('claim')
        ) {
            return 'Critical';
        }

        return 'High';
    }

    private static Boolean matchesScope(String candidateValue, String scopeValue) {
        return String.isBlank(scopeValue) || candidateValue == scopeValue;
    }
}
